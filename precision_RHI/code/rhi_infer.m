function out = rhi_infer(d, p, M)
%RHI_INFER  Joint state estimation and online precision learning (Algorithm 1).
%
%   out = RHI_INFER(d,p,M) runs the agent for the data d = RHI_GENERATE_DATA(p)
%   under a single internal model M (use RHI_MODELS to build M1, M2 or the
%   alpha-mixture).  Everything is gradient descent on the free energy of
%   Eq (7); the gradients below are the closed form of that expression, so no
%   Symbolic Math Toolbox is needed (run RHI_CHECK_GRADIENTS to verify them
%   against the symbolic version used in the original script).
%
%   Sign convention: F here is the *negative* free energy, so the updates are
%   ascent steps and the posterior state precision is Pi^X = -d2F/dX2.
%
%   Fields of out:
%     x       (nu x nt) state estimates                          (Eq 8)
%     lambda  (ny x nt) learned log noise precision              (Eq 9)
%     sigma   (nu x nt) marginal posterior state uncertainty     (Eq 10)
%     PiX     (nu x nu x nt) posterior state precision
%     U       (1 x nt)  trace(sqrt(Sigma^X)) - the model selection criterion
%                       of Eq (5); U(1) is the prior value (= nu) and is not
%                       plotted.
%     F       (1 x nt)  negative free energy (diagnostic only)

ny = p.ny;  nu = p.nu;  nt = p.nt;

lambda = zeros(ny, nt);   lambda(:,1) = p.eta_lambda;
x      = zeros(nu, nt);                     % state estimates start at zero
sigma  = zeros(nu, nt);   sigma(:,1)  = sqrt(diag(inv(p.P_u)));
PiX    = zeros(nu, nu, nt);  PiX(:,:,1) = p.P_u;
F      = zeros(1, nt);

K        = diag(p.k_u);
I_ny     = eye(ny);
I_nu     = eye(nu);
logdetPl = log(det(p.P_lambda));

for i = 2:nt
    y  = d.y(:,i);
    l  = lambda(:,i-1);          % lambda and x from the previous time step
    xp = x(:,i-1);               % (the original script updates both from i-1)
    Pz = diag(exp(l));           % noise precision, Eq (6)
    e  = y - M*xp;               % sensory prediction error

    % ---- posterior precision / uncertainty of the states (Eq 10) ---------
    dFdxx      = -(M.'*Pz*M + p.P_u);
    PiX(:,:,i) = -dFdxx;
    sigma(:,i) = sqrt(diag(pinv(PiX(:,:,i))));

    % ---- free energy (Eq 7); diagnostic, not used by the updates ---------
    F(i) = -0.5*(e.'*Pz*e) + 0.5*sum(l) ...
           -0.5*((l - p.eta_lambda).'*p.P_lambda*(l - p.eta_lambda)) ...
           -0.5*((xp - p.eta_u).'*p.P_u*(xp - p.eta_u)) ...
           -0.5*(log(det(PiX(:,:,i))) + logdetPl);

    % ---- online precision learning (Eq 9) -------------------------------
    dFdl        = 0.5 - 0.5*(e.^2).*exp(l) - p.P_lambda*(l - p.eta_lambda);
    dFdll       = -diag(0.5*(e.^2).*exp(l)) - p.P_lambda;
    lambda(:,i) = l + (expm(p.k_lambda*dFdll*p.dt) - I_ny)*pinv(dFdll)*dFdl;

    % ---- state estimation (Eq 8) ----------------------------------------
    dFdx   = M.'*Pz*e - p.P_u*(xp - p.eta_u);
    x(:,i) = xp + (expm(K*dFdxx*p.dt) - I_nu)*pinv(dFdxx)*dFdx;
end

out.t      = d.t;
out.M      = M;
out.x      = x;
out.lambda = lambda;
out.sigma  = sigma;
out.PiX    = PiX;
out.F      = F;
out.U      = sum(sigma, 1);      % Eq (5): trace of sqrt of the covariance
end
