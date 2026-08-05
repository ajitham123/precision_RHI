function h = fig05_illusion_vs_distance(p, Rys)
%FIG05_ILLUSION_VS_DISTANCE  Paper Fig 5: the switch depends on hand distance.
%
%   For every rubber hand position Ry the two hypotheses are run on the same
%   data and their posterior state uncertainty is averaged over a window while
%   the hand is visible (A) and while it is covered (B).  The bar underneath
%   marks the selected model.  With the hand covered, M2 wins only for
%   |Ry| < ~3.4: if the rubber hand is too far away the illusion cannot occur.
%
%   Runtime is ~50 simulations per panel (a few seconds).

if nargin < 1 || isempty(p),   p   = rhi_default_params(); end
if nargin < 2 || isempty(Rys), Rys = -5:0.2:5; end
Rys(Rys == p.Ay) = [];             % Ry = Ay would put the fake hand on the real one

U = zeros(2, numel(Rys), 2);       % (model, Ry, window)
for j = 1:numel(Rys)
    q = p; q.Ry = Rys(j);
    cmp = rhi_compare_models(q);
    for w = 1:2
        if w == 1, idx = rhi_window(q, q.window_uncovered);
        else,      idx = rhi_window(q, q.window_covered);   end
        U(1,j,w) = mean(cmp.U1(idx));
        U(2,j,w) = mean(cmp.U2(idx));
    end
end

c    = rhi_colors();
ttl  = {'Before hand covering','After hand covering'};
h    = figure('Name','Fig5 illusion vs inter-hand distance','Position',[80 80 1100 430]);
for w = 1:2
    subplot(1,2,w); hold on;
    plot(Rys, U(1,:,w), 'Color', c(1,:), 'LineWidth', 1.8);
    plot(Rys, U(2,:,w), 'Color', c(2,:), 'LineWidth', 1.8);
    xlabel('Ry'); ylabel('Mean posterior state uncertainty');
    title(ttl{w}); xlim([min(Rys) max(Rys)]);
    yl = get(gca,'YLim');  yl(1) = yl(1) - 0.10*diff(yl);
    set(gca,'YLim',yl);
    plot([p.Ay p.Ay], yl, 'k--', 'LineWidth', 1);
    legend({'M_1','M_2','Ay'},'Location','north');

    % ---- selected-model bar along the bottom ----------------------------
    sel = 1 + (U(2,:,w) < U(1,:,w));
    dR  = mean(diff(Rys))/2;
    hb  = 0.045*diff(yl);
    for j = 1:numel(Rys)
        fill(Rys(j) + [-dR dR dR -dR], yl(1) + [0 0 hb hb], c(sel(j),:), ...
             'EdgeColor','none','HandleVisibility','off');
    end
    set(gca,'FontSize',13); box on;

    % ---- report the boundary -------------------------------------------
    b = Rys(sel == 2);
    if isempty(b)
        fprintf('  %-21s : M1 selected for every Ry\n', ttl{w});
    else
        fprintf('  %-21s : M2 selected for %.1f <= Ry <= %.1f\n', ttl{w}, min(b), max(b));
    end
end
end
