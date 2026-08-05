function hh = rhi_plot_lambda(res, d, p, mode)
%RHI_PLOT_LAMBDA  Learned lambda (solid) against the true lambda (dash-dot).
%
%   RHI_PLOT_LAMBDA(res,d,p,mode) draws into the current axes.  Shared by
%   Fig 3B and Fig 4A so the colour convention cannot drift between them --
%   which is exactly what reviewer comment "Fig 4: the dashed lines (for the
%   real lambda) should be coloured as in Fig 3" was about.
%
%   MODE controls the true-lambda lines and the legend key:
%     'match'  (default) per-channel colours, and the "real lambda" key is a
%              black dash-dot proxy line, so the key reads as "dash-dot means
%              ground truth" rather than belonging to one channel.
%     'key-Av' per-channel colours, but the key is the Av line itself, so the
%              swatch comes out blue.  This is what the current figures do.
%     'black'  all true-lambda lines black -- the pre-revision Fig 4 look.
%
%   Why the proxy is needed: with four solid and four dash-dot lines, a legend
%   given five labels attaches the fifth to the fifth line drawn, i.e. the Av
%   dash-dot line.  The proxy costs a legend slot, plots no data and leaves the
%   axis limits untouched.

if nargin < 4 || isempty(mode), mode = 'match'; end

c   = rhi_colors();
k   = 2:p.nt;                     % t = 0 holds the priors, not plotted
lab = {'\lambda^{Av}','\lambda^{Rv}','\lambda^{At}','\lambda^{Py}'};

hold on;
if exist('gobjects','file') || exist('gobjects','builtin')
    hEst = gobjects(p.ny,1);          % MATLAB: graphics array
else
    hEst = zeros(p.ny,1);             % Octave: handles are doubles
end
for j = 1:p.ny                    % colour set explicitly, never via ColorOrderIndex
    hEst(j) = plot(p.t(k), res.lambda(j,k), '-', 'Color', c(j,:), 'LineWidth', 1.5);
end

if exist('gobjects','file') || exist('gobjects','builtin')
    hTrue = gobjects(p.ny,1);          % MATLAB: graphics array
else
    hTrue = zeros(p.ny,1);             % Octave: handles are doubles
end
for j = 1:p.ny
    if strcmpi(mode,'black'), col = [0 0 0]; else, col = c(j,:); end
    hTrue(j) = plot(p.t(k), d.lambda(j,k), '-.', 'Color', col, ...
                    'LineWidth', 1.2, 'HandleVisibility', 'off');
end

switch lower(mode)
    case {'match','black'}
        hKey = plot(NaN, NaN, '-.', 'Color', [0 0 0], 'LineWidth', 1.2);
    case 'key-av'
        hKey = hTrue(1);  set(hKey, 'HandleVisibility', 'on');
    otherwise
        error('rhi_plot_lambda:mode','mode must be match, key-Av or black.');
end

legend([hEst; hKey], [lab {'real \lambda'}], 'Location', 'southwest');
xlabel('Time (s)'); ylabel('\lambda estimate');
xlim([0 35]); ylim([-2 12]);
set(gca,'FontSize',14); box on;
hh = struct('est',hEst,'true',hTrue,'key',hKey);
end
