function p = rhi_default_params()
%RHI_DEFAULT_PARAMS  All parameters of the precision-based RHI model.
%
%   p = RHI_DEFAULT_PARAMS() returns a struct holding every number used by
%   the simulations in Novicky, Anil Meera, Zeldenrust & Lanillos,
%   "Online precision adaptation to model body-ownership illusion dynamics
%   under Bayesian inference".  Values follow Appendix 5.1 of the paper.
%
%   Figure scripts copy this struct and override single fields, e.g.
%       p = rhi_default_params();  p.Ry = 1.2;  p.alpha = -10;
%
%   See also RHI_MODELS, RHI_GENERATE_DATA, RHI_INFER.

% ---------- time base -----------------------------------------------------
p.T  = 32;                        % simulation length            [s]
p.dt = 0.1;                       % sampling time                [s]
p.t  = 0:p.dt:p.T;                % time vector
p.nt = numel(p.t);                % number of samples (321)
p.ny = 4;                         % observations  Y = [Av Rv At Py]
p.nu = 4;                         % states        X = [Ea Er Et Sy]

% ---------- geometry ------------------------------------------------------
p.Ay = 0;                         % real hand position
p.Ry = 0.8;                       % rubber hand position
p.Sy = p.Ay;                      % true hand position in the environment

% ---------- generative process: true noise precision ----------------------
p.lambda_visible = [ 9; 7; 8; 10];   % lambda = log(precision), hand visible
p.lambda_covered = [-1; 7; 8;  4];   % hand covered (Av and Py get noisy)
p.t_noise_switch = p.dt*floor(p.nt/2);  % 16.0 s  (raw step, then smoothed)
p.smooth_window  = floor(p.nt/5);       % 64 samples = 6.4 s gaussian window
p.noise_seed     = 12;                  % rng seed for the white noise

% ---------- stimulation: gaussian strokes ---------------------------------
% columns: [t_centre  amplitude on Ea, Er, Et, Sy]
p.strokes = [  4   0.5  1  1  0        % hand visible, both hands stroked
               6   0.5  1  1  0
               8   0.5  1  1  0
              10   0.5  1  1  0
              20   0    1  1  0        % hand covered, both hands stroked
              22   0    1  1  0
              24   0    1  1  0
              26   0    1  1  0
              28   0    1  0  0 ];     % hand covered, real hand not touched
p.stroke_width = 5;                  % stroke = exp(-stroke_width*(t-tc)^2)

% ---------- agent: priors and learning rates ------------------------------
p.eta_lambda = [10; 10; 10; 10];          % prior mean on lambda
p.P_lambda   = diag(exp([-4 -4 -4 -4]));  % prior precision on lambda
p.eta_u      = zeros(p.nu,1);             % prior mean on the states
p.P_u        = eye(p.nu);                 % prior precision on the states
p.k_lambda   = 4;                         % learning rate, precision (Eq 9)
p.k_u        = [4 4 4 4];                 % learning rate, states    (Eq 8)

% ---------- illusion susceptibility (Eq 2) --------------------------------
p.alpha = 10;              % +10 -> pure M1 (no illusion), -10 -> pure M2

% ---------- evaluation windows --------------------------------------------
p.drift_window     = [15.0 32.0];  % whole covered half. THIS is what reproduces
                                   % the published Fig 8; the delivered script
                                   % used [16.9 29.9] (samples 170:300) and the
                                   % Appendix says 17-30 s, both of which come
                                   % out ~1.3x too large. See RHI_DRIFT.
p.drift_stat       = 'mean';       % 'mean' or 'max' -- see RHI_DRIFT, the paper
                                   % is inconsistent about which one Fig 8 shows,
                                   % and [16.9 29.9] does not reproduce the
                                   % published magnitudes ([15 32] does)
p.window_uncovered = [ 4.0 11.0];  % Fig 5A
p.window_covered   = [20.0 30.0];  % Fig 5B

% ---------- annotation only (no effect on the simulation) -----------------
p.t_stroke_start = 3;              % "Stroking starts" guide line   [s]
p.t_hand_covered = 15;             % "Hand covered starts" guide line [s]
end
