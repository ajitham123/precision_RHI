function h = fig07_drift_by_distance(p, Rys)
%FIG07_DRIFT_BY_DISTANCE  Paper Fig 7: drift amplitude grows with hand distance.
%
%   Both panels are the illusory model M2; only the rubber hand position
%   differs -- near (Ry = 0.3) and far (Ry = 1.2).  The Sy panel shows the
%   drift is larger in the far condition, though the rate of increase saturates
%   (see FIG08_DRIFT_BY_SUSCEPTIBILITY for the full Ry sweep).
%
%   Ry enters the generative process as well as the internal model, so the data
%   are regenerated for each condition.

if nargin < 1 || isempty(p),   p   = rhi_default_params(); end
if nargin < 2 || isempty(Rys), Rys = [0.3 1.2]; end

h = figure('Name','Fig7 drift vs inter-hand distance','Position',[60 60 1120 760]);
cols = {[subplot(4,2,1) subplot(4,2,3) subplot(4,2,5) subplot(4,2,7)], ...
        [subplot(4,2,2) subplot(4,2,4) subplot(4,2,6) subplot(4,2,8)]};
tags = {'(A)  Near','(B)  Far'};

fprintf('  proprioceptive drift under M2 (%s over %g-%g s)\n', ...
        p.drift_stat, p.drift_window);
for q = 1:2
    r      = p;  r.Ry = Rys(q);
    d      = rhi_generate_data(r);
    [~,M2] = rhi_models(r);
    res    = rhi_infer(d, r, M2);
    rhi_plot_states(cols{q}, res, d, r, true);
    title(cols{q}(1), sprintf('%s (Ry = %.1f)      Illusion', tags{q}, r.Ry));
    fprintf('    Ry = %.1f : %+.4f\n', r.Ry, rhi_drift(res, r));
end
end
