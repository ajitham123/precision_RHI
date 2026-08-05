function rhi_plot_states(axs, res, d, p, showlegend)
%RHI_PLOT_STATES  One column of Fig 6 / Fig 7: Ea, Er, Et, Sy.
%
%   RHI_PLOT_STATES(axs,res,d,p,showlegend) fills the four axes in AXS (top to
%   bottom) with the true cause (blue), the agent's estimate (orange) and a
%   +/-1 standard deviation band from Eq (10).  The bottom panel also carries
%   the Ry guide line, because the gap between the blue and orange traces there
%   *is* the proprioceptive drift.

if nargin < 5 || isempty(showlegend), showlegend = true; end

c   = rhi_colors();
k   = 1:p.nt-1;                  % the original script plotted samples 1:320
tt  = p.t(k);
lab = {'Ea','Er','Et','Sy'};

for j = 1:p.nu
    axes(axs(j)); cla; hold on;
    m  = res.x(j,k);  sd = res.sigma(j,k);
    hB = fill([tt fliplr(tt)], [m+sd fliplr(m-sd)], 0.8*[1 1 1], ...
              'EdgeColor', 0.8*[1 1 1]);
    hE = plot(tt, m,        'Color', c(2,:), 'LineWidth', 1);
    hR = plot(tt, d.x(j,k), 'Color', c(1,:), 'LineWidth', 1);
    ylabel(lab{j}); xlim([0 35]);
    set(gca,'FontSize',12); box on;

    if j == 1 && showlegend
        legend([hB hE hR], {'\sigma','est','real'}, 'Location','northeast');
    end
    rhi_vline(p.t_stroke_start); rhi_vline(p.t_hand_covered);
    if j == p.nu
        rhi_hline(p.Ry);
        yl = get(gca,'YLim');
        text(33.6, p.Ry, 'Ry', 'FontSize', 11, 'HorizontalAlignment','right', ...
             'VerticalAlignment','bottom');
        set(gca,'YLim',yl);
        xlabel('time (s)');
    end
end
end
