function h = fig03_precision_adaptation(p)
%FIG03_PRECISION_ADAPTATION  Paper Fig 3: online precision learning (attention).
%
%   (A) the visual signal of the real hand, Av, which becomes very noisy once
%       the hand is covered (covering = added noise, not a missing signal);
%   (B) the learned log-precision lambda of all four channels tracking their
%       true values, including the abrupt change at coverage.
%
%   The lambda trajectories are practically identical under M1 and M2 (they
%   differ in the second decimal), so this panel does not depend on which
%   hypothesis the agent holds; M1 is used here.

if nargin < 1 || isempty(p), p = rhi_default_params(); end

d   = rhi_generate_data(p);
M1  = rhi_models(p);
res = rhi_infer(d, p, M1);
k   = 2:p.nt;
c   = rhi_colors();

h = figure('Name','Fig3 precision adaptation','Position',[80 80 1060 400]);

subplot(1,2,1); hold on;
plot(p.t(k), d.y(1,k), 'Color', c(1,:), 'LineWidth', 1);
xlabel('Time (s)'); ylabel('y'); xlim([0 35]); ylim([-5 5]);
legend('Av','Location','northwest');
rhi_vline(p.t_stroke_start); rhi_vline(p.t_hand_covered);
title('(A) visual signal of the real hand');
set(gca,'FontSize',14); box on;

subplot(1,2,2);
rhi_plot_lambda(res, d, p, 'match');
rhi_vline(p.t_stroke_start); rhi_vline(p.t_hand_covered);
title('(B) noise estimation');

fprintf('  final lambda estimate : '); fprintf('%6.2f', res.lambda(:,end)); fprintf('\n');
fprintf('  true  lambda          : '); fprintf('%6.2f', d.lambda(:,end));   fprintf('\n');
end
