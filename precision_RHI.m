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
% Reproduces Figs. 2-8 of Novicky, Anil Meera, Zeldenrust & Lanillos,
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
% -------------------------------------------------------------------------

% Hand back the internals if asked, so a single run can be scripted.
if nargin == 1 && ischar(varargin{1})
    if strcmpi(varargin{1}, 'api')
        api = struct('default_params', @default_params, ...
                     'simulate',       @simulate, ...
                     'hypotheses',     @hypotheses);
        return
    end
    error('precision_RHI: unknown option ''%s''. Use figure numbers or ''api''.', ...
          varargin{1});
end

figs = [2 3 4 5 6 7 8];
if nargin > 0
    figs = cell2mat(varargin);
end

for f = reshape(figs, 1, [])
    if ~ismember(f, 2:8)
        warning('precision_RHI: there is no figure %d (valid: 2-8)', f);
        continue
    end
    fprintf('Figure %d ...\n', f);
    switch f
        case 2, fig2_perceptual_switch();
        case 3, fig3_precision_adaptation();
        case 4, fig4_broken_precision();
        case 5, fig5_switch_vs_distance();
        case 6, fig6_drift_in_M1_and_M2();
        case 7, fig7_drift_vs_distance();
        case 8, fig8_drift_vs_alpha_and_distance();
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
P_X   = eye(n);                           % prior precision on the states
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

function idx = tsel(t, t0, t1)
%TSEL  Indices of t inside [t0, t1], robust to floating-point time steps.
idx = find(t >= t0 - 1e-9 & t <= t1 + 1e-9);
end

function v = pick(cond, a, b)
if cond, v = a; else, v = b; end
end