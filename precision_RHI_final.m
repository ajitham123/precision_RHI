function api = precision_RHI(varargin)
%PRECISION_RHI  Rubber-hand illusion as online precision adaptation.
%
%   precision_RHI          reproduce every figure of the paper
%   precision_RHI(2,5,8)   reproduce only the requested figures
%
% Everything below the first function is local to this file. To drive a
% single condition yourself, ask for handles to the internals:
%
%   f = precision_RHI('api');
%   p = f.default_params();  p.Ry = 2;  p.brain = 'M2';
%   s = f.simulate(p);       plot(s.t, s.Xh(4,:))
%
% Reproduces Figs. 2-11 of Novicky, Anil Meera, Zeldenrust & Lanillos,
% "Online precision adaptation to model body-ownership illusion dynamics
% under Bayesian inference".
%
% -------------------------------------------------------------------------
% THE MODEL IN SHORT
%
%   states   X = [Ea Er Et Sy]'   experimenter's touch position on the real
%                                 hand and on the rubber hand, tactile
%                                 force, perceived hand position
%   signals  Y = [Av Rv At Py]'   seen real hand, seen rubber hand, felt
%                                 touch, proprioception
%
% The world generates  Y = M*X + z  with  z ~ N(0, diag(exp(-lambda_true))).
% Covering the real hand is modelled by dropping lambda_true for Av from 9
% to -1: the visual channel of the real hand becomes very noisy (Sec. 2.4.1).
%
% The agent holds two hypotheses about how Y is generated (Eqs. 3 and 4):
%   M1  "my hand is my real hand"    -- identical to the world's M
%   M2  "my hand is the rubber hand" -- the tactile and proprioceptive rows
%                                       are driven by Er instead of Ea
%
% Under each hypothesis the agent runs three coupled computations, all of
% them gradient steps on the same free energy F (Eq. 7):
%   (a) state estimation   X       (Eq. 8)  -> produces the proprioceptive drift
%   (b) precision learning lambda  (Eq. 9)  -> the "attention" / noise estimate
%   (c) posterior uncertainty on X (Eq. 10) -> the model-selection criterion
%
% The hypothesis with the lower posterior state uncertainty is the one that
% is experienced (Eq. 5). While the hand is visible that is M1; once Av goes
% noisy, precision learning down-weights Av, M1 loses its grip on the hand
% position, and M2 takes over -- the illusion.
%
% Figs. 9-11 ask how much of this depends on the particular numbers in
% default_params: each free parameter is scaled or biased away from its
% published value, with M1 and M2 held fixed, and the switch is re-detected.
% -------------------------------------------------------------------------

% Hand back the internals if asked, so a single run can be scripted.
if nargin == 1 && ischar(varargin{1})
    if strcmpi(varargin{1}, 'api')
        api = struct('default_params',   @default_params, ...
                     'simulate',         @simulate, ...
                     'hypotheses',       @hypotheses, ...
                     'switch_metrics',   @switch_metrics, ...
                     'perturb',          @perturb, ...
                     'sensitivity_spec', @sensitivity_spec);
        return
    end
    error('precision_RHI: unknown option ''%s''. Use figure numbers or ''api''.', ...
          varargin{1});
end

figs = [2 3 4 5 6 7 8 9 10 11];
if nargin > 0
    figs = cell2mat(varargin);
end

for f = reshape(figs, 1, [])
    if ~ismember(f, 2:11)
        warning('precision_RHI: there is no figure %d (valid: 2-11)', f);
        continue
    end
    fprintf('Figure %d ...\n', f);
    switch f
        case 2,  fig2_perceptual_switch();
        case 3,  fig3_precision_adaptation();
        case 4,  fig4_broken_precision();
        case 5,  fig5_switch_vs_distance();
        case 6,  fig6_drift_in_M1_and_M2();
        case 7,  fig7_drift_vs_distance();
        case 8,  fig8_drift_vs_alpha_and_distance();
        case 9,  fig9_sensitivity_sweep();
        case 10, fig10_sensitivity_joint();
        case 11, fig11_sensitivity_examples();
    end
    drawnow;
end
end


% =========================================================================
%  MODEL
% =========================================================================

function p = default_params()
%DEFAULT_PARAMS  Every number the simulation needs (Appendix 5.1 of the paper).
p.T   = 32;                        % duration of one trial (s)
p.dt  = 0.1;                       % integration step (s)

p.Ay  = 0;                         % position of the real hand
p.Ry  = 0.8;                       % position of the rubber hand

p.brain = 'M2';                    % hypothesis used by the agent:
                                   %   'M1'  non-illusory
                                   %   'M2'  illusory
                                   %   'mix' sigmoid blend of both (Eq. 2)
p.alpha = -10;                     % only for 'mix': +10 -> M1, -10 -> M2

p.lam_visible = [ 9;  7;  8; 10];  % true log-precision of [Av Rv At Py]
p.lam_covered = [-1;  7;  8;  4];  % ... after the real hand is covered

p.eta_lam = [10; 10; 10; 10];      % prior mean on lambda
p.P_lam   = exp(-4) * [1;1;1;1];   % prior precision on lambda (diagonal).
                                   % Raising P_lam(1) freezes the Av
                                   % precision -> no illusion (Fig. 4).
p.k_lam   = 4;                     % learning rate for lambda
p.k_state = [4 4 4 4];             % learning rate per state

p.P_X     = 1;                     % prior precision on the states, as a
                                   % multiple of the identity. 1 is the value
                                   % used throughout the paper; it is a
                                   % parameter of the model rather than a
                                   % constant, so Fig. 9 sweeps it too.

p.seed = 12;                       % fixed noise realisation

p.drift_window = [];               % window over which the drift is averaged.
                                   % [] means "from hand covering to the end
                                   % of the trial", which is what reproduces
                                   % the published Fig. 8. Set to [17 30] for
                                   % the window stated in the Fig. 8 caption;
                                   % that gives ~20% larger amplitudes.
p.t_stroke_on  = 3;                % annotation only: stroking starts
p.t_covered    = 15;               % annotation only: hand is covered
end


function [M1, M2] = hypotheses(p)
%HYPOTHESES  The two competing generative models, Eqs. 3 and 4.
%
% Columns are the states [Ea Er Et Sy], rows the signals [Av Rv At Py]:
%   Av  seen position of the real hand
%   Rv  seen position of the rubber hand
%   At  felt touch      -- M1 gets it from the real hand, M2 from the rubber one
%   Py  proprioception  --                    "
% Only the last two rows differ, and that difference is the whole illusion:
% in M2 the rubber hand explains both the touch and the felt hand position.
d = p.Ay - p.Ry;                   % signed inter-hand distance

%          Ea      Er      Et    Sy
M1 = [    0.8,      0,    0.2,    0 ;
            0,      1,      0,    0 ;
         -0.3,      0,    0.7,    0 ;
            d,      0,      0,    1 ];

M2 = [    0.8,      0,    0.2,    0 ;
            0,      1,      0,    0 ;
            0,   -0.3,    0.7,    0 ;
            0,      d,      0,    1 ];
end


function s = simulate(p)
%SIMULATE  One trial: generate the data, then run the agent on it.
t  = 0:p.dt:p.T;
nt = numel(t);
n  = 4;

[M1, M2] = hypotheses(p);
switch upper(p.brain)
    case 'M1',  Mb = M1;
    case 'M2',  Mb = M2;
    case 'MIX', w = 1/(1 + exp(-p.alpha));  Mb = w*M1 + (1-w)*M2;   % Eq. 2
    otherwise,  error('p.brain must be ''M1'', ''M2'' or ''mix''.');
end

% ---- world -------------------------------------------------------------
X        = true_causes(t, p);             % the strokes actually delivered
lam_true = true_lambda(nt, p);            % true log-precision over time
rng(p.seed);
Z        = randn(n, nt) ./ sqrt(exp(lam_true));
Y        = M1*X + Z;                      % the world always works like M1
Y(:,1)   = 0;                             % first sample is only an initialiser

% ---- agent -------------------------------------------------------------
P_lam = diag(p.P_lam);                    % prior precision on lambda
if isfield(p, 'P_X')                      % prior precision on the states
    P_X = p.P_X * eye(n);                 %   (p.P_X = 1 -> eye(n), as published)
else
    P_X = eye(n);
end
K_lam = p.k_lam * eye(n);
K_X   = diag(p.k_state);
I     = eye(n);

lam = zeros(n, nt);  lam(:,1) = p.eta_lam;    % learned log-precisions
Xh  = zeros(n, nt);                           % state estimates
sd  = zeros(n, nt);                           % posterior std of the states
F   = zeros(1, nt);                           % free energy (for inspection)
sd(:,1) = sqrt(diag(pinv(Mb'*diag(exp(lam(:,1)))*Mb + P_X)));

for i = 2:nt
    l  = lam(:,i-1);
    x  = Xh(:,i-1);
    e  = Y(:,i) - Mb*x;                   % prediction error on the signals
    Pz = diag(exp(l));                    % currently believed sensory precision

    % posterior precision / uncertainty on the states, Eq. 10
    Pi_X    = Mb' * Pz * Mb + P_X;        % = -d2F/dX2
    sd(:,i) = sqrt(diag(pinv(Pi_X)));

    F(i) = -0.5*(e'*Pz*e) + 0.5*sum(l) ...
           -0.5*(l - p.eta_lam)'*P_lam*(l - p.eta_lam) ...
           -0.5*(x'*P_X*x) ...
           -0.5*(log(det(Pi_X)) + log(det(P_lam)));

    % ---- learn the sensory log-precisions, Eq. 9 ----
    % The gradients below are the closed forms of dF/dlambda and
    % d2F/dlambda2 for F above, with Pi_X and P_lam treated as constants
    % (as in the original symbolic implementation).
    q = 0.5 * exp(l) .* e.^2;
    g = 0.5 - q - P_lam*(l - p.eta_lam);
    H = -diag(q) - P_lam;
    lam(:,i) = l + (expm(K_lam*H*p.dt) - I) * pinv(H) * g;

    % ---- estimate the states, Eq. 8 ----
    g = Mb'*Pz*e - P_X*x;
    H = -Pi_X;
    Xh(:,i) = x + (expm(K_X*H*p.dt) - I) * pinv(H) * g;
end

% ---- what the figures need ---------------------------------------------
s.t = t;  s.X = X;  s.Y = Y;  s.Xh = Xh;  s.sd = sd;
s.lam = lam;  s.lam_true = lam_true;  s.F = F;  s.p = p;

% Model-selection criterion, Eq. 5: trace of the square root of the
% posterior covariance = sum of the four posterior standard deviations.
s.U = sum(sd, 1);

% Proprioceptive drift: perceived hand position averaged over the strokes
% delivered while the hand is covered. An empty p.drift_window means the
% whole covered period, i.e. from the moment the noise steps up (index
% floor(nt/2), the same index true_lambda uses) to the end of the trial.
if isempty(p.drift_window)
    win = [(floor(nt/2) - 1)*p.dt, p.T];
else
    win = p.drift_window;
end
s.drift = mean(Xh(4, tsel(t, win(1), win(2))));
end


function X = true_causes(t, p)
%TRUE_CAUSES  The strokes: Gaussian bumps on [Ea; Er; Et; Sy].
%   Four strokes while the hand is visible, five more while it is covered.
%   Once the hand is covered Ea drops to 0 (there is nothing to see), and
%   the last stroke touches the rubber hand only (Et = 0).
%
%          [Ea; Er; Et; Sy] amplitude,   stroke times (s)
bumps = { [0.5; 1; 1; 0],                [4 6 8 10]     ;   % hand visible
          [0.0; 1; 1; 0],                [20 22 24 26]  ;   % covered, touched
          [0.0; 1; 0; 0],                [28]           };  % covered, not touched

X = zeros(4, numel(t));
for b = 1:size(bumps,1)
    for c = bumps{b,2}
        X = X + bumps{b,1} .* exp(-5*(t - c).^2);
    end
end
X(4,:) = X(4,:) + p.Ay;                   % perceived position starts at Ay
end


function lam = true_lambda(nt, p)
%TRUE_LAMBDA  Log-precision of the sensory noise: a smoothed step at T/2.
%   The Gaussian smoothing makes the hand covering gradual rather than
%   instantaneous, which is why the switch in Fig. 2 takes a second or two.
half = floor(nt/2);
lam  = [repmat(p.lam_visible, 1, half), repmat(p.lam_covered, 1, nt-half)];
lam  = smoothdata(lam', 'gaussian', floor(nt/5))';
end


% =========================================================================
%  FIGURES
% =========================================================================

function fig2_perceptual_switch()
%FIG. 2  The illusion: after the hand is covered M2 becomes the more certain
%        model, and the perceived hand position drifts towards Ry.
p = default_params();
p.brain = 'M1';  s1 = simulate(p);
p.brain = 'M2';  s2 = simulate(p);
c = palette();

figure(2); clf;
subplot(4,1,1:3); hold on;
plot(s1.t, s1.U, 'color', c(1,:), 'linewidth', 1.5);
plot(s2.t, s2.U, 'color', c(2,:), 'linewidth', 1.5);
vline(p.t_covered);
legend({'M_1: my hand is still my hand', 'M_2: I own the rubber hand'}, ...
       'location', 'northwest');
ylabel('Posterior state uncertainty');
title('Fig. 2   Body-ownership perceptual switch');
set(gca, 'fontsize', 12); box off;

subplot(4,1,4); hold on;
plot(s2.t, s2.X(4,:),  'color', c(1,:), 'linewidth', 1);   % real Sy
plot(s2.t, s2.Xh(4,:), 'color', c(2,:), 'linewidth', 1);   % estimate under M2
hline(p.Ry); hline(p.Ay); vline(p.t_covered);
text(0.3, p.Ry, 'Ry'); text(0.3, p.Ay, 'Ay');
ylabel('Sy'); xlabel('Time (s)');
set(gca, 'fontsize', 12); box off;
end


function fig3_precision_adaptation()
%FIG. 3  Precision learning tracks the true noise level in real time.
p = default_params();
s = simulate(p);
c = palette();

figure(3); clf;
subplot(1,2,1); hold on;
plot(s.t, s.Y(1,:), 'color', c(1,:), 'linewidth', 1);
vline(p.t_stroke_on); vline(p.t_covered);
legend({'Av'}, 'location', 'northwest');
xlabel('Time (s)'); ylabel('y');
title('(A)   visual signal of the real hand'); set(gca, 'fontsize', 12);

subplot(1,2,2); hold on;
plot_lambda(s, c);
title('(B)   learned vs. true log-precision');
end


function fig4_broken_precision()
%FIG. 4  Freeze the precision of Av with a strong prior and the illusion
%        disappears: M1 stays the more certain model throughout.
p = default_params();
p.P_lam(1) = exp(10);              % the agent refuses to believe Av is noisy

s = simulate(p);
p.brain = 'M1';  s1 = simulate(p);
p.brain = 'M2';  s2 = simulate(p);
c = palette();

figure(4); clf;
subplot(1,2,1); hold on;
plot_lambda(s, c);
title('(A)   \lambda^{Av} no longer tracks the truth');

subplot(1,2,2); hold on;
plot(s1.t, s1.U, 'color', c(1,:), 'linewidth', 1.5);
plot(s2.t, s2.U, 'color', c(2,:), 'linewidth', 1.5);
vline(p.t_covered);
legend({'M_1: my hand is still my hand', 'M_2: I own the rubber hand'}, ...
       'location', 'northwest');
xlabel('Time (s)'); ylabel('Posterior state uncertainty');
title('(B)   no switch, hence no illusion'); set(gca, 'fontsize', 12); box off;
end


function fig5_switch_vs_distance()
%FIG. 5  The switch only happens for moderate inter-hand distances: put the
%        rubber hand far enough away and M1 wins again, so no illusion.
p  = default_params();
Ry = -5:0.2:5;
Ry(Ry == 0) = [];                  % Ry = 0 would put the two hands on top of each other

win = [4 11; 20 30];               % averaging windows: before / after covering
U   = zeros(2, numel(Ry), 2);      % [hypothesis] x [Ry] x [window]
for j = 1:numel(Ry)
    p.Ry = Ry(j);
    for m = 1:2
        p.brain = sprintf('M%d', m);
        s = simulate(p);
        for k = 1:2
            U(m,j,k) = mean(s.U(tsel(s.t, win(k,1), win(k,2))));
        end
    end
end

ttl = {'(A)   before hand covering', '(B)   after hand covering'};
c   = palette();
figure(5); clf;
for k = 1:2
    subplot(1,2,k); hold on;
    plot(Ry, U(1,:,k), 'color', c(1,:), 'linewidth', 1.5);
    plot(Ry, U(2,:,k), 'color', c(2,:), 'linewidth', 1.5);
    vline(0);

    % strip along the bottom showing which hypothesis is selected
    yl  = ylim;  yb = yl(1) - 0.07*diff(yl);
    sel = U(2,:,k) < U(1,:,k);
    selection_bar(Ry(~sel), yb, c(1,:));  selection_bar(Ry(sel), yb, c(2,:));
    ylim([yb - 0.03*diff(yl), yl(2)]);

    legend({'M_1','M_2','M_1 selected','M_2 selected'}, 'location', 'north');
    xlabel('Ry'); ylabel('Mean posterior state uncertainty');
    title(sprintf('%s  (%g-%g s)', ttl{k}, win(k,1), win(k,2)));
    set(gca, 'fontsize', 12); box off;
end
end


function fig6_drift_in_M1_and_M2()
%FIG. 6  Drift is a structural property of M2: freeze either hypothesis and
%        only M2 mislocalises the hand.
p = default_params();
figure(6); clf;
p.brain = 'M1';  plot_states(simulate(p), 1, '(A)   y = M_1 x + z');
p.brain = 'M2';  plot_states(simulate(p), 2, '(B)   y = M_2 x + z   (illusion)');
end


function fig7_drift_vs_distance()
%FIG. 7  Under M2, a farther rubber hand produces a larger drift.
p = default_params();
figure(7); clf;
p.Ry = 0.3;  plot_states(simulate(p), 1, '(A)   near, Ry = 0.3');
p.Ry = 1.2;  plot_states(simulate(p), 2, '(B)   far,  Ry = 1.2');
end


function fig8_drift_vs_alpha_and_distance()
%FIG. 8  Drift as a function of inter-hand distance and of the agent's
%        susceptibility alpha (Eq. 2). alpha = -10 is maximally illusory,
%        alpha = +10 is immune to the illusion.
p = default_params();
p.brain = 'mix';
alphas  = [-10 -1 0 1 10];
Ry      = -1.6:0.2:1.6;

% Baseline. With the rubber hand on top of the real one (Ry = Ay) the model
% has no conflict to resolve: row 4 of both M1 and M2 becomes [0 0 0 1], so
% Sy is estimated from Py alone and nothing pulls it anywhere. Whatever
% drift is measured there is therefore pure nuisance -- the sample mean of
% the proprioceptive noise over the averaging window. Because the noise
% realisation is fixed by p.seed it is the same constant for every alpha and
% every Ry, so subtracting it is exact. This is also what a real RHI
% experiment does when it takes a pre-induction position measurement.
p.Ry = p.Ay;
baseline = simulate(p).drift;

drift = zeros(numel(alphas), numel(Ry));
for a = 1:numel(alphas)
    p.alpha = alphas(a);
    for j = 1:numel(Ry)
        p.Ry = Ry(j);
        s = simulate(p);
        drift(a,j) = s.drift - baseline;
    end
end

figure(8); clf; hold on;
plot(Ry, drift', 'linewidth', 1.5);
hline(0); vline(0.3); vline(1.2);            % the near / far cases of Fig. 7
text(0.33, 0.9*min(drift(:)), 'near');
text(1.23, 0.9*min(drift(:)), 'far');
legend(arrayfun(@(a) sprintf('\\alpha = %d', a), alphas, ...
       'UniformOutput', false), 'location', 'northwest');
xlabel('Rubber hand location (Ry)'); ylabel('Proprioceptive drift');
title('Fig. 8   Drift vs. inter-hand distance and susceptibility');
set(gca, 'fontsize', 12); box off;
end


% =========================================================================
%  PARAMETER SENSITIVITY
% =========================================================================

function spec = sensitivity_spec()
%SENSITIVITY_SPEC  The free parameters perturbed in Figs. 9-11.
%
% One row per parameter: its name, how a perturbation is applied to it, the
% grid Fig. 9 sweeps it over, and an axis label.
%
% Gains and precisions are strictly positive, so they are perturbed
% multiplicatively ('mul', where 1 is the published value). The lambdas are
% already log-precisions, so for those the natural perturbation is a bias
% ('add', where 0 is the published value).
%
% The mapping matrices M1 and M2 (Eqs. 3 and 4) are deliberately NOT on this
% list. The claim being tested is that one fixed pair of hypotheses produces
% the ownership switch across a wide range of the free parameters, so the
% mapping is held exactly as published throughout.
%
% Where a parameter has a breakdown point the grid is made wide enough to
% contain it, which for four of the six means a logarithmic sweep over many
% orders of magnitude rather than a couple of octaves.
%
% k_x and P_x need such a sweep for a specific reason. In the published
% regime the state update has already saturated: K_x*H*dt has eigenvalues of
% order -1e3, so expm(K_x*H*p.dt) in simulate underflows to zero and the
% update is exactly the Newton step -- k_x cannot influence it at all.
% Likewise P_x = 1 is added to an M'*Pz*M whose entries are of order 1e3, so
% it is negligible unless raised by orders of magnitude. Sweeping either over
% two octaves would produce a flat line for an uninteresting reason.
%
% Columns 4-7 are for plotting rather than for the sweep itself. Fig. 9 draws
% each parameter against its own value, so it needs the value the paper uses
% (column 5) to turn a perturbation into an absolute one, and explicit tick
% positions in those same absolute units (column 4) -- several of the grids
% span eight or more decades, and letting MATLAB label every decade puts the
% tick labels on top of each other in a subplot this size.
%
%        name          kind   sweep grid      ticks (absolute)  paper value  symbol                     description
spec = { 'k_lam',      'mul', 2.^(-2:0.5:2),  [1 2 4 8 16],     4,           'k_\lambda',                'precision learning rate'
         'k_state',    'mul', 10.^(-5:2),     10.^(-4:2:2),     4,           'k_x',                      'state learning rate'
         'P_X',        'mul', 10.^(-2:8),     10.^(-2:2:8),     1,           'P_x',                      'prior precision on the states'
         'eta_lam',    'add', -4:4,           6:2:14,           10,          '\eta_\lambda',             'prior mean on \lambda'
         'P_lam_Av',   'mul', 10.^(-2:8),     10.^(-3:1:1),     exp(-4),     'P_\lambda^{Av}',           'prior precision on \lambda^{Av}'
         'lam_cov_Av', 'add', -4:2:12,        -4:2:6,           -1,          '\lambda^{Av}_{covered}',   'visual precision when covered' };
end


function p = perturb(p, name, v)
%PERTURB  Apply one perturbation from SENSITIVITY_SPEC to a parameter set.
%   'mul' parameters are scaled by v, 'add' parameters are offset by v.
switch name
    case 'k_lam',      p.k_lam          = p.k_lam          * v;
    case 'k_state',    p.k_state        = p.k_state        * v;
    case 'P_X',        p.P_X            = p.P_X            * v;
    case 'P_lam_Av',   p.P_lam(1)       = p.P_lam(1)       * v;
    case 'eta_lam',    p.eta_lam        = p.eta_lam        + v;
    case 'lam_cov_Av', p.lam_covered(1) = p.lam_covered(1) + v;
    otherwise, error('perturb: unknown parameter ''%s''.', name);
end
end


function m = switch_metrics(p)
%SWITCH_METRICS  Detect the ownership switch in one trial.
%
% Runs the same trial under both hypotheses and compares the model-selection
% criterion U (Eq. 5) sample by sample:
%
%   d = U(M_1) - U(M_2) > 0   <=>   M_2 is the experienced hypothesis
%
% A switch is counted only when BOTH halves hold: M_1 is experienced
% throughout the visible period, and M_2 then takes over for at least
% MIN_HOLD seconds. M_2 winning on its own is not an illusion -- it is a
% model that was illusory from the start -- so both conditions are needed.
% The persistence requirement also discards the single-sample transient the
% estimator produces at t = 0, before any data has arrived.
MIN_HOLD = 1.0;                    % s of sustained M2 dominance required
WIN_PRE  = [4 12.5];               % hand visible, strokes running
%
% WIN_PRE has to end just before the covering starts to take effect, and no
% earlier. true_lambda smooths the step at t_step with a Gaussian of window
% nt/5 = 6.4 s, i.e. s.d. 1.28 s, so the believed precision of Av begins to
% fall around t_step - 2.5 s.d. = 12.7 s. Ending the window earlier than that
% leaves a gap in which a crossing counts as a switch without the covering
% having had anything to do with it: at P_x >= 1e3 x published the two
% hypotheses cross at ~11.4 s, which a window ending at 11 s would score as
% an illusion. Requiring M1 to lead all the way to 12.5 s scores it, correctly,
% as an agent that was already illusory before its hand was covered.

q = p;  q.brain = 'M1';  s1 = simulate(q);
q.brain = 'M2';          s2 = simulate(q);

t  = s1.t;
nt = numel(t);
d  = s1.U - s2.U;

% The covering step: the sample at which true_lambda switches over to
% lam_covered, written the same way as the drift window in simulate. The step
% is smoothed over nt/5 samples, so the believed precision of Av starts to
% fall a couple of seconds before this and the switch can slightly precede it.
m.t_step = (floor(nt/2) - 1) * p.dt;

m.pre_M1 = all(d(tsel(t, WIN_PRE(1), WIN_PRE(2))) < 0);

% First run of at least MIN_HOLD seconds of M2 dominance that starts after
% the visible period.
np    = max(2, round(MIN_HOLD / p.dt));
k0    = find(t > WIN_PRE(2), 1);
run   = 0;
first = NaN;
for i = 1:nt
    if d(i) > 0, run = run + 1; else, run = 0; end
    if run >= np && i - np + 1 >= k0 && isnan(first)
        first = i - np + 1;
    end
end

m.occurred = m.pre_M1 && ~isnan(first);
if m.occurred
    % Linear interpolation of the zero crossing of d, so that the switch time
    % is not quantised to the integration step. Without this, parameters whose
    % influence is smaller than dt produce a staircase.
    m.t_switch = t(first);
    if first > 1 && d(first-1) <= 0 && d(first) > d(first-1)
        m.t_switch = t(first-1) + p.dt * (0 - d(first-1)) / (d(first) - d(first-1));
    end
else
    m.t_switch = NaN;
end
m.latency = m.t_switch - m.t_step;                 % relative to the covering
m.margin  = mean(d(tsel(t, m.t_step, p.T)));       % how decisively M2 wins

m.t = t;  m.U1 = s1.U;  m.U2 = s2.U;  m.d = d;
end


function fig9_sensitivity_sweep()
%FIG. 9  Parameter sensitivity: when the switch happens as a parameter varies.
%
% One panel per parameter, four parameters, and one trial per point. Each
% x-axis is the parameter's own value -- not a multiple of anything -- and the
% dashed vertical line marks the value used for the paper simulations
% (Appendix 5.1):
%
%   k_lambda = 4     eta_lambda = 10     P_lambda^Av = exp(-4) = 0.0183
%   lambda^Av_covered = -1     (against lambda^Av = 9 while the hand is visible)
%
% A point is plotted only where the switch actually occurs, so a gap in a
% curve is a range over which the illusion does not arise at all; the console
% summary names the value at which it stops and which half of the definition
% fails there. M1 and M2 (Eqs. 3 and 4) are unchanged in every panel -- only
% these four numbers move.
%
% k_x and P_x are left out because they do nothing near their paper values:
% expm(K_X*H*p.dt) in simulate has already underflowed to zero, so the state
% update is exactly the Newton step and its gain cannot matter, and P_x = 1 is
% added to an M'*Pz*M whose entries are of order 1e3. Fig. 10 still perturbs
% them along with the rest.
PANELS = {'k_lam', 'eta_lam', 'P_lam_Av', 'lam_cov_Av'};

% The axes are placed by hand rather than by subplot. The x-labels carry
% superscripts and subscripts and the titles are full phrases, and at the
% spacing subplot(2,2,...) uses the top row's label runs into the bottom row's
% title. AX_Y leaves roughly twice that gap between the two rows.
% The margins are set by what sits outside the axes: the y-label on the left,
% the titles above (centred, so a long one overflows to the right of its
% column), and the x-labels below, whose subscripts hang lower than the tick
% labels do.
AX_W = 0.355;  AX_H = 0.285;
AX_X = [0.115, 0.585];             % left edges:    columns 1 and 2
AX_Y = [0.615, 0.105];             % bottom edges:  top row, then bottom row

spec = sensitivity_spec();
pd   = default_params();
c    = palette();

figure(9); clf;
set(gcf, 'position', [80 80 920 760]);
fprintf('  Fig. 9  switch occurs over:\n');
for i = 1:numel(PANELS)
    k    = find(strcmp(spec(:,1), PANELS{i}), 1);
    name = spec{k,1};  kind = spec{k,2};  gv  = spec{k,3};
    tks  = spec{k,4};  nom  = spec{k,5};  sym = spec{k,6};  desc = spec{k,7};

    % The parameter's own value at each point of the sweep: the multiplicative
    % parameters scale their paper value, the log-precisions are offset from it.
    if strcmp(kind, 'mul'), av = nom * gv; else, av = nom + gv; end

    ts  = nan(1, numel(gv));
    occ = false(1, numel(gv));
    pre = false(1, numel(gv));
    for j = 1:numel(gv)
        m = switch_metrics(perturb(default_params(), name, gv(j)));
        occ(j) = m.occurred;
        pre(j) = m.pre_M1;
        if m.occurred, ts(j) = m.t_switch; end   % NaN elsewhere breaks the line
    end
    [lo, hi] = robust_range(av, double(occ), nom);

    axes('position', [AX_X(mod(i-1,2) + 1), AX_Y(ceil(i/2)), AX_W, AX_H]);
    hold on;

    plot(av, ts, 'o-', 'color', c(2,:), 'linewidth', 1.5, ...
         'markersize', 5, 'markerfacecolor', c(2,:));

    % Show one grid step past the outermost value that still switches. The
    % sweeps deliberately run well beyond the switch to find its limits, and
    % plotting all of that would leave most of the axis blank -- P_lambda^Av is
    % swept over ten decades and switches over the first four of them.
    on = find(occ);
    if isempty(on)
        xlim([min(av) max(av)]);
    else
        xlim([av(max(1, min(on)-1)), av(min(numel(av), max(on)+1))]);
    end
    if strcmp(kind, 'mul')
        set(gca, 'xscale', 'log', 'xtick', tks, 'xticklabel', tick_labels(tks));
    else
        set(gca, 'xtick', tks);
    end
    hline(pd.t_covered);  vline(nom);

    xlabel(sym);
    if mod(i, 2) == 1, ylabel('Switch time (s)'); end   % left column only
    title(sprintf('(%c)   %s', 'A' + i - 1, desc));
    set(gca, 'fontsize', 11); box off;

    fprintf('    %-12s %-24s (paper %-9g) %s\n', name, range_str(lo, hi), nom, ...
            fail_str(av, double(occ), double(pre), lo, hi));
end
end


function fig10_sensitivity_joint()
%FIG. 10  Parameter sensitivity with every parameter perturbed at once.
%
% Fig. 9 moves one parameter at a time, which cannot rule out that the switch
% needs the rest of them held at their published values. Here all six are
% drawn independently at random -- log-uniform over [1/MUL, MUL] for the
% multiplicative ones, uniform over [-ADD, +ADD] for the additive ones, each
% with its own noise realisation -- and the switch is re-detected. The
% ranges are inside the single-parameter ranges of Fig. 9, so the question
% is specifically whether the switch survives all six moving together.
%
% Panel B is the margin after covering, not a second test of the switch: it
% comes out positive for every parameter set, including the few that are not
% counted as switching. Those fail the other half of the definition -- M2 was
% already ahead before the hand was covered -- which panel A counts and panel
% B cannot show.
NSAMP = 300;                       % random parameter sets
MUL   = 2;                         % multiplicative parameters: x0.5 .. x2
ADD   = 2;                         % additive (log-precision) ones: -2 .. +2

spec = sensitivity_spec();
nm   = size(spec,1);

% Draw every random number up front: simulate() calls rng(p.seed), which
% would otherwise reset the stream in the middle of the loop.
rng(99);
Uu    = rand(NSAMP, nm);
seeds = randi(1000, NSAMP, 1);

occ = false(NSAMP,1);  ts = nan(NSAMP,1);  mg = nan(NSAMP,1);
for i = 1:NSAMP
    p = default_params();  p.seed = seeds(i);
    for k = 1:nm
        if strcmp(spec{k,2}, 'mul')
            v = MUL^(2*Uu(i,k) - 1);          % log-uniform in [1/MUL, MUL]
        else
            v = ADD*(2*Uu(i,k) - 1);          % uniform in [-ADD, +ADD]
        end
        p = perturb(p, spec{k,1}, v);
    end
    m = switch_metrics(p);
    occ(i) = m.occurred;
    mg(i)  = m.margin;
    if m.occurred, ts(i) = m.t_switch; end
    if mod(i, 100) == 0, fprintf('    %d/%d parameter sets\n', i, NSAMP); end
end

ref = switch_metrics(default_params());       % the published trial, for reference
pct = 100 * mean(occ);
fprintf('  Fig. 10  switch in %d/%d joint perturbations (%.1f%%)\n', ...
        sum(occ), NSAMP, pct);
fprintf('           switch time %.2f +/- %.2f s  (published %.2f s)\n', ...
        mean(ts(occ)), std(ts(occ)), ref.t_switch);

c = palette();
figure(10); clf;
set(gcf, 'position', [80 80 1100 460]);   % wide enough for the panel titles

subplot(1,2,1); hold on;
hist_bar(ts(occ), 20, c(2,:));
vline(ref.t_switch);
xlabel('Switch time (s)'); ylabel('Parameter sets');
title(sprintf('(A)   switch in %.1f%% of %d\njoint perturbations', pct, NSAMP));
set(gca, 'fontsize', 10); box off;

subplot(1,2,2); hold on;
hist_bar(mg, 20, c(2,:));
vline(0);
xlabel('U(M_1) - U(M_2) after covering'); ylabel('Parameter sets');
title(sprintf('(B)   margin by which M_2 wins\nonce the hand is covered'));
set(gca, 'fontsize', 10); box off;
end


function fig11_sensitivity_examples()
%FIG. 11  Four parameters, four switches: the appendix version of Fig. 9.
%
% One column per parameter, each with that one parameter moved well away from
% its published value and M1 and M2 exactly as published.
%
%   top row     the two hypotheses' posterior state uncertainty, as in Fig. 2,
%               with the published trial underlaid in grey
%   bottom row  their difference, d = U(M_1) - U(M_2). This row is what makes
%               the switch legible: the two curves of the top row are only
%               ~0.05 apart before covering but ~0.5 apart after it, so on a
%               common axis the crossing itself is invisible. d > 0 means M_2
%               is the experienced hypothesis, so the switch is the point
%               where d crosses zero.
%
%         name          value  label
cases = { 'k_lam',      0.5,   'k_\lambda \times 0.5'
          'k_state',    0.25,  'k_x \times 0.25'
          'eta_lam',    4,     '\eta_\lambda + 4'
          'lam_cov_Av', 4,     '\lambda^{Av}_{covered} + 4' };
nc = size(cases,1);

pd  = default_params();
ref = switch_metrics(pd);
c   = palette();

figure(11); clf;
set(gcf, 'position', [80 80 1400 620]);   % four columns of axes
for i = 1:nc
    m = switch_metrics(perturb(default_params(), cases{i,1}, cases{i,2}));
    if m.occurred
        ttl = sprintf('(%c)   %s\nswitch at %.2f s', 'A'+i-1, cases{i,3}, m.t_switch);
    else
        ttl = sprintf('(%c)   %s\nno switch', 'A'+i-1, cases{i,3});
    end

    % ---- top row: the two hypotheses --------------------------------------
    subplot(2, nc, i); hold on;
    ps = get(gca, 'position');     % headroom for the two-line title
    set(gca, 'position', [ps(1), ps(2), ps(3), 0.86*ps(4)]);
    h0 = plot(ref.t, ref.U1, ':', 'color', [0.6 0.6 0.6], 'linewidth', 1);
    plot(ref.t, ref.U2, ':', 'color', [0.6 0.6 0.6], 'linewidth', 1, ...
         'handlevisibility', 'off');
    h1 = plot(m.t, m.U1, 'color', c(1,:), 'linewidth', 1.2);
    h2 = plot(m.t, m.U2, 'color', c(2,:), 'linewidth', 1.2);
    vline(pd.t_covered);
    xlim([0 pd.T]);
    % No tick labels on the top row: the bottom row carries the time axis, and
    % in four columns the labels of the two rows would otherwise run together.
    set(gca, 'xtick', 0:10:30, 'xticklabel', []);
    title(ttl); set(gca, 'fontsize', 10); box off;
    if i == 1
        % Shortened from "posterior state uncertainty": at a quarter of the
        % width and half the height of the figure, the full wording is taller
        % than the axes it belongs to.
        ylabel('Posterior uncertainty');
        legend([h1 h2 h0], {'M_1', 'M_2', 'published'}, ...
               'location', 'northwest', 'fontsize', 8);
    end

    % ---- bottom row: which hypothesis is experienced -----------------------
    subplot(2, nc, nc + i); hold on;
    plot(ref.t, ref.d, ':', 'color', [0.6 0.6 0.6], 'linewidth', 1);
    plot(m.t, m.d, 'color', c(4,:), 'linewidth', 1.2);
    hline(0); vline(pd.t_covered);
    if m.occurred
        plot(m.t_switch, 0, 'kv', 'markerfacecolor', 'k', 'markersize', 6);
    end
    xlim([0 pd.T]);
    set(gca, 'xtick', 0:10:30);
    xlabel('Time (s)'); set(gca, 'fontsize', 10); box off;
    if i == 1, ylabel('U(M_1) - U(M_2)'); end
end
end


% =========================================================================
%  PLOTTING HELPERS
% =========================================================================

function plot_lambda(s, c)
%PLOT_LAMBDA  Learned log-precisions (solid) against the true ones (dashed).
for i = 1:4
    plot(s.t, s.lam(i,:), '-', 'color', c(i,:), 'linewidth', 1.5);
end
for i = 1:4
    plot(s.t, s.lam_true(i,:), '-.', 'color', c(i,:), 'linewidth', 1.2, ...
         'handlevisibility', pick(i == 1, 'on', 'off'));
end
vline(s.p.t_stroke_on); vline(s.p.t_covered);
legend({'\lambda^{Av}','\lambda^{Rv}','\lambda^{At}','\lambda^{Py}','real \lambda'}, ...
       'location', 'southwest');
xlabel('Time (s)'); ylabel('\lambda estimate');
set(gca, 'fontsize', 12); box off;
end


function plot_states(s, col, ttl)
%PLOT_STATES  Four stacked panels of estimated vs. true states, +/- 1 sigma.
lbl = {'Ea','Er','Et','Sy'};
c   = palette();
for i = 1:4
    subplot(4, 2, 2*(i-1) + col); hold on;
    m = s.Xh(i,:);  sd = s.sd(i,:);
    fill([s.t fliplr(s.t)], [m+sd fliplr(m-sd)], [1 1 1]*0.8, ...
         'edgecolor', [1 1 1]*0.8);
    plot(s.t, m,        'color', c(2,:), 'linewidth', 1);
    plot(s.t, s.X(i,:), 'color', c(1,:), 'linewidth', 1);
    vline(s.p.t_stroke_on); vline(s.p.t_covered);
    ylabel(lbl{i}); xlim([0 s.p.T]); box off; set(gca, 'fontsize', 11);
    if i == 1
        title(ttl);
        legend({'\sigma','est','real'}, 'location', 'northeast');
    end
    if i == 4
        hline(s.p.Ry); text(0.9*s.p.T, s.p.Ry, 'Ry'); xlabel('time (s)');
    end
end
end


function c = palette()
% MATLAB default colour order: blue, orange, yellow, purple.
c = [0,      0.4470, 0.7410 ;
     0.8500, 0.3250, 0.0980 ;
     0.9290, 0.6940, 0.1250 ;
     0.4940, 0.1840, 0.5560 ];
end

function vline(x)
yl = ylim;
plot([x x], yl, '--', 'color', [0.5 0.5 0.5], 'handlevisibility', 'off');
ylim(yl);
end

function hline(y)
xl = xlim;
plot(xl, [y y], '--', 'color', [0.5 0.5 0.5], 'handlevisibility', 'off');
xlim(xl);
end

function selection_bar(x, y, col)
%SELECTION_BAR  Row of markers marking which hypothesis wins (bottom bar of Fig. 5).
plot(x, y*ones(1, numel(x)), 's', 'markersize', 4, 'markerfacecolor', col, ...
     'markeredgecolor', col);
end

function hist_bar(x, nb, col)
%HIST_BAR  Histogram of x in nb bins. The counting is done by hand so that
%          the file keeps to the same MATLAB baseline as the rest of it.
x = x(~isnan(x));
if isempty(x), return, end
lo = min(x);  hi = max(x);
if hi == lo, hi = lo + 1; end
e = linspace(lo, hi, nb+1);
n = zeros(1, nb);
for b = 1:nb
    n(b) = sum(x >= e(b) & x < e(b+1));
end
n(nb) = n(nb) + sum(x == e(end));
bar(0.5*(e(1:end-1) + e(2:end)), n, 1, 'facecolor', col, 'edgecolor', 'w');
end


function lbl = tick_labels(tks)
%TICK_LABELS  Compact labels for a logarithmic sweep axis (Fig. 9): powers of
%   ten as exponents once they would otherwise be long, the rest as plain
%   numbers, so that 0.25 does not come out as 2.5\times10^{-1}.
lbl = cell(1, numel(tks));
for i = 1:numel(tks)
    e = log10(tks(i));
    if abs(e - round(e)) < 1e-9 && abs(e) >= 2
        lbl{i} = sprintf('10^{%d}', round(e));
    else
        lbl{i} = sprintf('%g', tks(i));
    end
end
end


function [lo, hi] = robust_range(gv, frac, nom)
%ROBUST_RANGE  Widest contiguous stretch of grid values that contains the
%              published one and over which every realisation switched.
lo = NaN;  hi = NaN;
i0 = find(abs(gv - nom) < 1e-12, 1);
if isempty(i0) || frac(i0) < 1, return, end
a = i0;  while a > 1           && frac(a-1) == 1, a = a - 1; end
b = i0;  while b < numel(frac) && frac(b+1) == 1, b = b + 1; end
lo = gv(a);  hi = gv(b);
end


function s = fail_str(gv, frac, fpre, lo, hi)
%FAIL_STR  How the switch first breaks down on either side of the robust
%          range of Fig. 9.
%   Two failures are possible and they mean different things: the switch can
%   go missing, or M2 can already be ahead while the hand is still visible --
%   in which case the agent is illusory from the start rather than switching.
s = '';
if isnan(lo), return, end

i = find(gv < lo & frac < 1);                  % nearest failure below
if ~isempty(i)
    s = sprintf('breaks at %g (%s)', gv(i(end)), fail_mode(fpre(i(end))));
end
j = find(gv > hi & frac < 1, 1);               % nearest failure above
if ~isempty(j)
    if ~isempty(s), s = [s '; ']; end
    s = [s sprintf('breaks at %g (%s)', gv(j), fail_mode(fpre(j)))];
end
if isempty(s), s = 'no failure in the swept range'; end
end


function s = fail_mode(fp)
%FAIL_MODE  Name the failure: illusory from the start, or never illusory.
if fp < 1
    s = 'M2 already ahead before covering';
else
    s = 'switch absent';
end
end


function s = range_str(lo, hi)
%RANGE_STR  Format a range of parameter values for the summary of Fig. 9.
if isnan(lo)
    s = 'no switch at the paper value';
else
    s = sprintf('%g to %g', lo, hi);
end
end


function idx = tsel(t, t0, t1)
%TSEL  Indices of t inside [t0, t1], robust to floating-point time steps.
idx = find(t >= t0 - 1e-9 & t <= t1 + 1e-9);
end

function v = pick(cond, a, b)
if cond, v = a; else, v = b; end
end