function out = run_all_figures(save_png)
%RUN_ALL_FIGURES  Reproduce every figure of the paper, one call per figure.
%
%   run_all_figures        draw all figures
%   run_all_figures(true)  also write PNGs into ./figures_out
%
%   Figure 1 is a schematic and has no code.  Of Figure 2 only the posterior
%   state uncertainty panel is produced here; the photographs, arrows and panel
%   numbers of the published version were composited separately, as were the
%   brush/hand icons and the "Stroking starts" labels on Figs 3, 6 and 7.
%
%   Each figure is an independent function taking an optional parameter struct,
%   so any panel can be regenerated on its own, e.g.
%       p = rhi_default_params();  p.Ry = 1.2;  fig06_drift_by_model(p);
%
%   See also RUN_ALL_CHECKS, which verifies the gradients, the numbers and the
%   figures themselves.

if nargin < 1 || isempty(save_png), save_png = false; end

figs = { 'fig02_perceptual_switch',        @fig02_perceptual_switch
         'fig03_precision_adaptation',     @fig03_precision_adaptation
         'fig04_breaking_precision',       @fig04_breaking_precision
         'fig05_illusion_vs_distance',     @fig05_illusion_vs_distance
         'fig06_drift_by_model',           @fig06_drift_by_model
         'fig07_drift_by_distance',        @fig07_drift_by_distance
         'fig08_drift_by_susceptibility',  @fig08_drift_by_susceptibility };

out = struct();
total = tic;
for q = 1:size(figs,1)
    name = figs{q,1};
    fprintf('=== %s ===\n', name);
    t0 = tic;
    h  = figs{q,2}();
    out.(name) = h;
    if save_png, rhi_savefig(h, name); end
    fprintf('    %.1f s\n\n', toc(t0));
end
fprintf('all figures in %.1f s\n', toc(total));
if save_png
    fprintf('PNGs written to %s\n', fullfile(pwd,'figures_out'));
end
end
