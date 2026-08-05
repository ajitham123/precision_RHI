function h = fig02_perceptual_switch(p)
%FIG02_PERCEPTUAL_SWITCH  Paper Fig 2 (posterior state uncertainty panel).
%
%   The two hypotheses are run on identical sensory data.  While the hand is
%   visible, M1 ("my hand is my real hand") is slightly more certain.  Once
%   the hand is covered the noise on Av grows, precision learning follows it,
%   and the posterior uncertainty of M1 overtakes that of M2: by the criterion
%   of Eq (5) the agent now believes it owns the rubber hand - the illusion.
%
%   The proprioceptive drift that accompanies this is the Sy panel of Fig 6B
%   (same simulation, same Ry) - see FIG06_DRIFT_BY_MODEL.

if nargin < 1 || isempty(p), p = rhi_default_params(); end

cmp = rhi_compare_models(p);
k   = 2:p.nt;                      % t = 0 holds the prior, not plotted
c   = rhi_colors();

h = figure('Name','Fig2 perceptual switch','Position',[80 80 760 430]);
hold on;
plot(p.t(k), cmp.U1(k), 'Color', c(1,:), 'LineWidth', 1.6);
plot(p.t(k), cmp.U2(k), 'Color', c(2,:), 'LineWidth', 1.6);
xlabel('Time (s)'); ylabel('Posterior state uncertainty');
xlim([0 p.T]); ylim([0 1.8]);
rhi_vline(p.t_hand_covered, 0.5*[1 1 1], 1.2);
text(p.t_hand_covered+0.2, 0.92*max(cmp.U1(k)), 'Hand covered', 'FontSize', 11);
legend({'M1: My hand is still my hand','M2: I own the rubber hand'}, ...
       'Location','northwest');
title(sprintf('Ry = %.2f', p.Ry));
set(gca,'FontSize',14); box on;

% ---- report the switch --------------------------------------------------
ic = rhi_window(p, p.window_covered);
iu = rhi_window(p, p.window_uncovered);
fprintf('  hand visible : U(M1) = %.3f, U(M2) = %.3f  -> M%d selected\n', ...
        mean(cmp.U1(iu)), mean(cmp.U2(iu)), 1 + (mean(cmp.U2(iu)) < mean(cmp.U1(iu))));
fprintf('  hand covered : U(M1) = %.3f, U(M2) = %.3f  -> M%d selected\n', ...
        mean(cmp.U1(ic)), mean(cmp.U2(ic)), 1 + (mean(cmp.U2(ic)) < mean(cmp.U1(ic))));
sw = find(cmp.selected(rhi_window(p,[p.t_hand_covered p.T])) == 2, 1);
if ~isempty(sw)
    fprintf('  first M1 -> M2 switch after covering: t = %.1f s\n', ...
            p.t_hand_covered + (sw-1)*p.dt);
end
end
