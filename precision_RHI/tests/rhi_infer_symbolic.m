function out = rhi_infer_symbolic(d, p, M, nt_max)
%RHI_INFER_SYMBOLIC  The ORIGINAL Symbolic-Toolbox inference loop, verbatim.
%
%   out = RHI_INFER_SYMBOLIC(d,p,M,nt_max)
%
%   This exists for one purpose: to let RHI_CHECK_VS_ORIGINAL prove that
%   RHI_INFER's closed-form gradients reproduce the symbolic differentiation
%   the published figures were produced with.  It is ~500x slower and is not
%   used by any figure.  REQUIRES the Symbolic Math Toolbox.
%
%   The eval/sprintf pattern below is deliberately kept from the original
%   script rather than tidied, so that what is being compared against is the
%   original computation and not a re-interpretation of it.

if nargin < 4 || isempty(nt_max), nt_max = p.nt; end
if isempty(which('sym'))
    error('rhi_infer_symbolic:noToolbox', ...
          ['Needs the Symbolic Math Toolbox. The closed-form gradients can ', ...
           'still be validated without it by RHI_CHECK_GRADIENTS.']);
end

ny = p.ny;  nu = p.nu;

h = sym('h',[ny 1]);        y       = sym('y',[ny 1]);
u = sym('u',[nu 1]);        prior_u = sym('prior_u',[nu 1]);
Pi_u = sym('Pi_u',[nu nu]); Pi_h    = sym('Pi_h',[ny ny]);

Pi = diag(exp(h));
F  = -.5*transpose(y - M*u)*Pi*(y - M*u) + .5*log(det(Pi)) + ...
     -.5*transpose(h - p.eta_lambda)*p.P_lambda*(h - p.eta_lambda) + ...
     -.5*transpose(u - prior_u)*p.P_u*(u - prior_u) + ...
     -.5*( log(det(Pi_u)) + log(det(Pi_h)) );

dFdh = sym(zeros(ny,1));  dFdhh = sym(zeros(ny,ny));
for i = 1:ny
    dFdh(i,1) = diff(F, h(i));
    for j = 1:ny,  dFdhh(i,j) = diff(dFdh(i,1), h(j));  end
end
dFdu = sym(zeros(nu,1));  dFduu = sym(zeros(nu,nu));
for i = 1:nu
    dFdu(i,1) = diff(F, u(i));
    for j = 1:nu,  dFduu(i,j) = diff(dFdu(i,1), u(j));  end
end

lambda = zeros(ny,nt_max);  lambda(:,1) = p.eta_lambda;
x      = zeros(nu,nt_max);
sigma  = zeros(nu,nt_max);  sigma(:,1)  = sqrt(diag(inv(p.P_u)));
Fv     = zeros(1,nt_max);
Pi_h_n = p.P_lambda;                        % the original sets Pi^lambda = P^lambda

for i = 2:nt_max
    for k = 1:ny
        eval(sprintf('%s=lambda(k,i-1);', char(h(k))));   %#ok<*NASGU>
        eval(sprintf('%s=d.y(k,i);',      char(y(k))));
        for kk = 1:ny
            eval(sprintf('%s=Pi_h_n(k,kk);', char(Pi_h(k,kk))));
        end
    end

    PiX        = -eval(dFduu);
    sigma(:,i) = sqrt(diag(pinv(PiX)));

    for k = 1:nu
        eval(sprintf('%s=x(k,i-1);',    char(u(k))));
        eval(sprintf('%s=p.eta_u(k);',  char(prior_u(k))));
        for kk = 1:nu
            eval(sprintf('%s=PiX(k,kk);', char(Pi_u(k,kk))));
        end
    end

    Fv(i)       = eval(F);
    lambda(:,i) = lambda(:,i-1) + ...
        (expm(p.k_lambda*eval(dFdhh)*p.dt) - eye(ny))*pinv(eval(dFdhh))*eval(dFdh);
    x(:,i)      = x(:,i-1) + ...
        (expm(diag(p.k_u)*eval(dFduu)*p.dt) - eye(nu))*pinv(eval(dFduu))*eval(dFdu);
end

out.x = x;  out.lambda = lambda;  out.sigma = sigma;
out.F = Fv; out.U = sum(sigma,1); out.M = M;
end
