function rhi_hline(y, xl, col, lw, sty)
%RHI_HLINE  Horizontal guide line that stays out of the legend.
if nargin < 2 || isempty(xl),  xl  = get(gca,'XLim'); end
if nargin < 3 || isempty(col), col = 0.5*[1 1 1];     end
if nargin < 4 || isempty(lw),  lw  = 1.2;             end
if nargin < 5 || isempty(sty), sty = '--';            end
plot(xl, [y y], sty, 'Color', col, 'LineWidth', lw, 'HandleVisibility','off');
end
