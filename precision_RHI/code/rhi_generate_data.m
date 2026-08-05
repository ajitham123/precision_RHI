function d = rhi_generate_data(p)
%RHI_GENERATE_DATA  Environment / generative process of the RHI experiment.
%
%   d = RHI_GENERATE_DATA(p) produces the sensory measurements the agent
%   receives,  Y = M*X + z  (Eq 1), where
%       X  are the experimenter's actions and the true hand position,
%          delivered as discrete gaussian strokes (p.strokes),
%       M  is the true mapping, equal to M1 (Eq 3),
%       z  is zero-mean noise whose precision follows p.lambda_visible before
%          the hand is covered and p.lambda_covered afterwards, with a smooth
%          transition around p.t_noise_switch.
%
%   Covering the hand is modelled as a large increase of the noise on the
%   visual channel Av (and on Py), not as a missing signal - see Sec 4.3
%   ("uncertain signals versus no signals") of the paper.
%
%   Fields of d:  t, nt, M, x (true states), lambda (true log-precision),
%                 Pz (true precision), z (noise), y (observations).

d.t  = p.t;
d.nt = p.nt;
d.M  = rhi_models(p);                    % first output = M1 = Eq (3)

% ---------- true causes x(t) ---------------------------------------------
d.x = zeros(p.nu, p.nt);
for k = 1:size(p.strokes,1)
    tc = p.strokes(k,1);
    a  = p.strokes(k,2:1+p.nu).';
    d.x = d.x + a*exp(-p.stroke_width*(p.t - tc).^2);
end
d.x(4,:) = d.x(4,:) + p.Sy;              % constant true hand position

% ---------- true noise precision: smoothed step --------------------------
n1       = round(p.t_noise_switch/p.dt);
lam_raw  = [repmat(p.lambda_visible, 1, n1), ...
            repmat(p.lambda_covered, 1, p.nt - n1)];
d.lambda = rhi_smooth(lam_raw, p.smooth_window);
d.Pz     = exp(d.lambda);

% ---------- observations -------------------------------------------------
rhi_seed(p.noise_seed);
white = randn(p.ny, p.nt);               % fixed realisation of the noise
d.z = zeros(p.ny, p.nt);
d.y = zeros(p.ny, p.nt);
for i = 2:p.nt
    d.z(:,i) = white(:,i)./sqrt(d.Pz(:,i));
    d.y(:,i) = d.M*d.x(:,i) + d.z(:,i);
end
end
