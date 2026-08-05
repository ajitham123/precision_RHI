function rhi_vline(x, col, lw, sty)
%RHI_VLINE  Vertical guide line that stays out of the legend.
%   Used instead of XLINE so the code also runs on older MATLAB and on Octave.
if nargin < 2 || isempty(col), col = 0.5*[1 1 1]; end
if nargin < 3 || isempty(lw),  lw  = 1.2;         end
if nargin < 4 || isempty(sty), sty = '--';        end
yl = get(gca,'YLim');
plot([x x], yl, sty, 'Color', col, 'LineWidth', lw, 'HandleVisibility','off');
set(gca,'YLim',yl);
end
