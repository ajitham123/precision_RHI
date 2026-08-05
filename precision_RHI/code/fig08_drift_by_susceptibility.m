function h = fig08_drift_by_susceptibility(p, alphas, Rys)
%FIG08_DRIFT_BY_SUSCEPTIBILITY  Paper Fig 8: drift vs distance and vs alpha.
%
%   Sweeps the rubber hand position Ry and the susceptibility alpha of Eq (2).
%   Each curve is one simulated participant: alpha = -10 is maximally
%   susceptible (essentially M2), alpha = +10 is resistant (essentially M1) and
%   shows almost no drift.  The dashed verticals mark the near and far
%   conditions of Fig 7.
%
%   Runtime is numel(alphas)*numel(Rys) simulations (~85, a few seconds).
%
%   At Ry = Ay the two models coincide (both reduce to Py = Sy), so the drift
%   is identically zero; the original script special-cased this with a sign()
%   factor and the same value is reproduced here.

if nargin < 1 || isempty(p),      p      = rhi_default_params(); end
if nargin < 2 || isempty(alphas), alphas = [-10 -1 0 1 10];      end
if nargin < 3 || isempty(Rys),    Rys    = -1.6:0.2:1.6;         end

D = zeros(numel(alphas), numel(Rys));
for a = 1:numel(alphas)
    for j = 1:numel(Rys)
        if Rys(j) == p.Ay, D(a,j) = 0; continue; end
        q = p;  q.alpha = alphas(a);  q.Ry = Rys(j);
        d = rhi_generate_data(q);
        [~,~,SM] = rhi_models(q);                 % alpha-weighted model, Eq (2)
        res = rhi_infer(d, q, SM);
        D(a,j) = rhi_drift(res, q);
    end
end

c = rhi_colors();
h = figure('Name','Fig8 drift vs distance and susceptibility','Position',[80 80 900 560]);
hold on;
if exist('gobjects','file') || exist('gobjects','builtin')
    hL = gobjects(numel(alphas),1);          % MATLAB: graphics array
else
    hL = zeros(numel(alphas),1);             % Octave: handles are doubles
end
lab = cell(numel(alphas),1);
for a = 1:numel(alphas)
    hL(a)  = plot(Rys, D(a,:), 'Color', c(a,:), 'LineWidth', 1.8);
    lab{a} = sprintf('\\alpha = %g', alphas(a));
end
xlabel('Rubber hand location (Ry)'); ylabel('Proprioceptive drift');
xlim([min(Rys) max(Rys)]); ylim([-0.4 0.4]);
rhi_hline(0, [min(Rys) max(Rys)], 0.3*[1 1 1], 0.8, '-');
yl = get(gca,'YLim');   % now fixed at [-0.4 0.4]
cond = {'Near', 'Far'};  xc = [0.3 1.2];
for q = 1:2
    x = xc(q);
    plot([x x], yl, 'k--', 'LineWidth', 1.2, 'HandleVisibility','off');
    text(x+0.03, yl(1)+0.30*diff(yl), cond{q}, 'Rotation', 90, 'FontSize', 11);
end
set(gca,'YLim',yl);
legend(hL, lab, 'Location','northwest');
set(gca,'FontSize',14); box on;

fprintf('  drift at Ry = %.1f (%s over %g-%g s) :', ...
        max(Rys), p.drift_stat, p.drift_window);
fprintf('  alpha=%g -> %+.3f', [alphas; D(:,end)']); fprintf('\n');
end
