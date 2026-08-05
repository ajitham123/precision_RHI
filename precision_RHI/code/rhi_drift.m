function [val, tr] = rhi_drift(res, p)
%RHI_DRIFT  Proprioceptive drift: estimated hand position minus the true one.
%
%   [val,tr] = RHI_DRIFT(res,p)
%     tr   full time course, Sy-hat - Sy  (Sec 2.4.3: the agent cannot report
%          this itself, because it has no access to the true Sy)
%     val  tr summarised over p.drift_window using p.drift_stat
%
%   The summary is defined inconsistently in the paper, so it is a parameter
%   here rather than a hard-coded choice. Three places disagree:
%     - Appendix 5.1 : "the average of Sy between the 17th and the 30th second"
%     - Fig 8 caption: "the maximum value of the proprioceptive drift"
%     - the original script: mean over 16.9-29.9 s
%   The choice matters, because the drift is not flat across that window: for
%   Ry = 1.6, alpha = -10 it is ~0.06 at 16-18 s, ~0.68 at 20-28 s and ~0.00 by
%   30-32 s, the strokes having stopped at t = 28. Consequently
%     mean over 16.9-29.9 s -> 0.48
%     mean over 15-32 s     -> 0.37   (this is the published value)
%     maximum               -> ~0.9
%   p.drift_window therefore defaults to [15 32]. The shape, ordering and
%   alpha-dependence of the Fig 8 curves are unaffected by the choice; only the
%   absolute scale changes. See docs/PAPER_CORRESPONDENCE.md.
%
%   See also RHI_INFER, FIG08_DRIFT_BY_SUSCEPTIBILITY.

if ~isfield(p,'drift_stat'), p.drift_stat = 'mean'; end

tr  = res.x(4,:) - p.Sy;
idx = rhi_window(p, p.drift_window);
switch lower(p.drift_stat)
    case 'mean', val = mean(tr(idx));
    case 'max',  val = max(tr(idx));
    otherwise,   error('rhi_drift:stat','drift_stat must be mean or max.');
end
end
