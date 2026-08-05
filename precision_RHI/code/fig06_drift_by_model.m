function h = fig06_drift_by_model(p)
%FIG06_DRIFT_BY_MODEL  Paper Fig 6: the drift lives in M2, not in M1.
%
%   The same sensory data are explained twice, once under M1 and once under M2,
%   with the model FROZEN (no uncertainty-based selection).  That isolates the
%   drift computation from the selection process: Ea, Er and Et are recovered
%   under both hypotheses, but only under M2 does the estimated hand position
%   Sy pull away from its true value towards Ry.  Drift is therefore a
%   structural property of M2 that runs in parallel with model selection --
%   the dissociation the paper argues for.
%
%   See also FIG02_PERCEPTUAL_SWITCH (which model is actually selected) and
%   FIG07_DRIFT_BY_DISTANCE (how the drift grows with Ry).

if nargin < 1 || isempty(p), p = rhi_default_params(); end

d        = rhi_generate_data(p);
[M1, M2] = rhi_models(p);
r1       = rhi_infer(d, p, M1);
r2       = rhi_infer(d, p, M2);

h = figure('Name','Fig6 drift by model','Position',[60 60 1120 760]);
axL = [subplot(4,2,1) subplot(4,2,3) subplot(4,2,5) subplot(4,2,7)];
axR = [subplot(4,2,2) subplot(4,2,4) subplot(4,2,6) subplot(4,2,8)];
rhi_plot_states(axL, r1, d, p, true);
rhi_plot_states(axR, r2, d, p, true);
title(axL(1), '(A)  y = M_1x + z');
title(axR(1), '(B)  y = M_2x + z      Illusion');

fprintf('  proprioceptive drift (%s over %g-%g s), Ry = %.2f\n', ...
        p.drift_stat, p.drift_window, p.Ry);
fprintf('    under M1 : %+.4f   (no drift expected)\n', rhi_drift(r1,p));
fprintf('    under M2 : %+.4f   (drift towards Ry)\n',  rhi_drift(r2,p));
end
