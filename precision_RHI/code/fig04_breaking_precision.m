function h = fig04_breaking_precision(p)
%FIG04_BREAKING_PRECISION  Paper Fig 4: no precision adaptation -> no illusion.
%
%   The agent is made over-confident about the visual channel Av by raising
%   only the first entry of the prior precision on lambda to e^10.  lambda^Av
%   then stays near its prior (~10) instead of tracking the true value (-1),
%   the uncertainty of M1 never overtakes that of M2, and the perceptual
%   switch of Fig 2 does not happen.  This is the face validation that online
%   precision adaptation is necessary for the illusion.

if nargin < 1 || isempty(p), p = rhi_default_params(); end
p.P_lambda = diag(exp([10 -4 -4 -4]));      % <- the only change vs Fig 2/3

cmp = rhi_compare_models(p);
k   = 2:p.nt;
c   = rhi_colors();

h = figure('Name','Fig4 breaking precision adaptation','Position',[80 80 1060 400]);

subplot(1,2,1);
rhi_plot_lambda(cmp.m1, cmp.data, p, 'match');   % same call as Fig 3B
rhi_vline(p.t_stroke_start); rhi_vline(p.t_hand_covered);
title('(A) lambda^{Av} no longer tracks the noise');

subplot(1,2,2); hold on;
plot(p.t(k), cmp.U1(k), 'Color', c(1,:), 'LineWidth', 1.6);
plot(p.t(k), cmp.U2(k), 'Color', c(2,:), 'LineWidth', 1.6);
xlabel('Time (s)'); ylabel('Posterior state uncertainty');
xlim([0 p.T]); ylim([0 0.6]);
rhi_vline(p.t_hand_covered, 0.5*[1 1 1], 1.2);
legend({'M1: My hand is still my hand','M2: I own the rubber hand'}, ...
       'Location','northwest');
title('(B) the models never switch');
set(gca,'FontSize',14); box on;

ic = rhi_window(p, p.window_covered);
fprintf('  mean lambda^{Av} while covered : %.2f (true %.2f)\n', ...
        mean(cmp.m1.lambda(1,ic)), mean(cmp.data.lambda(1,ic)));
fprintf('  hand covered: U(M1) = %.3f < U(M2) = %.3f  -> M2 never selected: %d\n', ...
        mean(cmp.U1(ic)), mean(cmp.U2(ic)), ~any(cmp.selected(ic) == 2));
end
