function rhi_savefig(h, name, folder)
%RHI_SAVEFIG  Save a figure as PNG next to the code (used by RUN_ALL_FIGURES).
if nargin < 3 || isempty(folder), folder = 'figures_out'; end
if ~exist(folder,'dir'), mkdir(folder); end
set(h, 'PaperPositionMode','auto');
print(h, '-dpng', '-r150', fullfile(folder, [name '.png']));
end
