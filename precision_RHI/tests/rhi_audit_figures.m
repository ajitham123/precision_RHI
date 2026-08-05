function ok = rhi_audit_figures()
%RHI_AUDIT_FIGURES  Check every figure against the published panels.
%
%   ok = RHI_AUDIT_FIGURES()
%
%   Draws each figure, then reads its axis limits, axis labels, legend entries
%   and line styles back out of the graphics objects and compares them with the
%   properties read off the published figures. Catches the class of mistake that
%   eyeballing a PNG does not: a mode argument left on the wrong value, an axis
%   limit that happens to look right because the data happen to fill it, a
%   legend key attached to the wrong line.
%
%   The colour-pairing check is the important one for Figs 3B and 4A: for every
%   channel k it asserts that the dash-dot "true lambda" line has exactly the
%   same RGB as the solid estimate for that channel, and that both equal row k
%   of RHI_COLORS. That is the reviewer's request ("the dashed lines should be
%   coloured as in Fig 3") expressed as a test rather than as a habit.
%
%   WHAT THIS CANNOT CHECK. Two things are outside its reach and can only be
%   confirmed by running in MATLAB:
%     - the noise realisation. MATLAB's rng(12) and other interpreters' RNGs
%       differ, so individual traces differ sample by sample. Window averages
%       agree (see the table in README.md).
%     - smoothdata. RHI_SMOOTH falls back to an approximate gaussian window
%       when smoothdata is unavailable, so the shape of the lambda transition
%       may differ slightly. Both the drift and the uncertainty are insensitive
%       to it (< 0.005 over smoothing windows 1-128).

% MATLAB's default ColorOrder, which is what the published figures used (the
% reviewer's "the M2 curve is orange, not red" confirms it). HARD-CODED ON
% PURPOSE: reading these from RHI_COLORS would make every colour check
% self-referential, so editing the palette would pass silently.
c = [0      0.4470 0.7410
     0.8500 0.3250 0.0980
     0.9290 0.6940 0.1250
     0.4940 0.1840 0.5560
     0.4660 0.6740 0.1880
     0.3010 0.7450 0.9330
     0.6350 0.0780 0.1840];
tol = 1e-9;
ok  = true;
nch = 0;  nbad = 0;

% --------------------------------------------------------------------------
% expected properties, read off the published panels
% --------------------------------------------------------------------------
spec = {};

spec{end+1} = struct('fcn','fig02_perceptual_switch', 'naxes',1, 'panels',{{ ...
    struct('xlim',[0 32],'ylim',[0 1.8], ...
           'xlab','Time (s)','ylab','Posterior state uncertainty', ...
           'nsolid',2,'solidcols',[1 2],'ndashdot',0,'proxy',0, ...
           'legend',{{'M1: My hand is still my hand','M2: I own the rubber hand'}}) }});

spec{end+1} = struct('fcn','fig03_precision_adaptation', 'naxes',2, 'panels',{{ ...
    struct('xlim',[0 35],'ylim',[-5 5], ...
           'xlab','Time (s)','ylab','y', ...
           'nsolid',1,'solidcols',1,'ndashdot',0,'proxy',0, ...
           'legend',{{'Av'}}), ...
    struct('xlim',[0 35],'ylim',[-2 12], ...
           'xlab','Time (s)','ylab','\lambda estimate', ...
           'nsolid',4,'solidcols',1:4,'ndashdot',4,'proxy',1, ...
           'legend',{{'\lambda^{Av}','\lambda^{Rv}','\lambda^{At}', ...
                      '\lambda^{Py}','real \lambda'}}) }});

spec{end+1} = struct('fcn','fig04_breaking_precision', 'naxes',2, 'panels',{{ ...
    struct('xlim',[0 35],'ylim',[-2 12], ...
           'xlab','Time (s)','ylab','\lambda estimate', ...
           'nsolid',4,'solidcols',1:4,'ndashdot',4,'proxy',1, ...
           'legend',{{'\lambda^{Av}','\lambda^{Rv}','\lambda^{At}', ...
                      '\lambda^{Py}','real \lambda'}}), ...
    struct('xlim',[0 32],'ylim',[0 0.6], ...
           'xlab','Time (s)','ylab','Posterior state uncertainty', ...
           'nsolid',2,'solidcols',[1 2],'ndashdot',0,'proxy',0, ...
           'legend',{{'M1: My hand is still my hand','M2: I own the rubber hand'}}) }});

pan5 = struct('xlim',[-5 5],'ylim',[], ...
              'xlab','Ry','ylab','Mean posterior state uncertainty', ...
              'nsolid',2,'solidcols',[1 2],'ndashdot',0,'proxy',0, ...
              'legend',{{'M_1','M_2','Ay'}});
spec{end+1} = struct('fcn','fig05_illusion_vs_distance','naxes',2, ...
                     'panels',{{pan5, pan5}});

lab6 = {'Ea','Er','Et','Sy'};
p6   = {};
for col = 1:2
    for row = 1:4
        p6{end+1} = struct('xlim',[0 35],'ylim',[], ...
            'xlab', merge(row==4,'time (s)',''), 'ylab', lab6{row}, ...
            'nsolid',2,'solidcols',[2 1],'ndashdot',0,'proxy',0,'legend',{{}});
    end
end
p6{1}.legend  = {'\sigma','est','real'};
p6{5}.legend  = {'\sigma','est','real'};
spec{end+1} = struct('fcn','fig06_drift_by_model',    'naxes',8,'panels',{p6});
spec{end+1} = struct('fcn','fig07_drift_by_distance', 'naxes',8,'panels',{p6});

spec{end+1} = struct('fcn','fig08_drift_by_susceptibility','naxes',1,'panels',{{ ...
    struct('xlim',[-1.6 1.6],'ylim',[-0.4 0.4], ...
           'xlab','Rubber hand location (Ry)','ylab','Proprioceptive drift', ...
           'nsolid',5,'solidcols',1:5,'ndashdot',0,'proxy',0, ...
           'legend',{{'\alpha = -10','\alpha = -1','\alpha = 0', ...
                      '\alpha = 1','\alpha = 10'}}) }});

% the palette itself is part of what is being checked
[nch,nbad,ok] = chk(nch,nbad,ok,'rhi_colors matches MATLAB default ColorOrder', ...
    isequal(size(rhi_colors()),size(c)) && max(max(abs(rhi_colors()-c)))<1e-6, ...
    'palette has been edited');

% --------------------------------------------------------------------------
for q = 1:numel(spec)
    S = spec{q};
    fprintf('\n%s\n', S.fcn);
    hf  = feval(S.fcn);
    axs = sorted_axes(hf);

    [nch,nbad,ok] = chk(nch,nbad,ok,'axes count', ...
                        numel(axs)==S.naxes, sprintf('%d (want %d)',numel(axs),S.naxes));

    for a = 1:min(numel(axs), numel(S.panels))
        E  = S.panels{a};
        ax = axs(a);
        pre = sprintf('  panel %d', a);

        if ~isempty(E.xlim)
            [nch,nbad,ok] = chk(nch,nbad,ok,[pre ' xlim'], ...
                max(abs(get(ax,'XLim')-E.xlim))<tol, mat2str(get(ax,'XLim')));
        end
        if ~isempty(E.ylim)
            [nch,nbad,ok] = chk(nch,nbad,ok,[pre ' ylim'], ...
                max(abs(get(ax,'YLim')-E.ylim))<tol, mat2str(get(ax,'YLim')));
            % and it must be set, not merely coincide with the auto range:
            % auto limits follow the data, so under MATLAB's RNG they could land
            % somewhere else and the figure would silently stop matching.
            [nch,nbad,ok] = chk(nch,nbad,ok,[pre ' ylim is explicit'], ...
                strcmp(get(ax,'YLimMode'),'manual'), get(ax,'YLimMode'));
        end
        if ~isempty(E.xlim)
            [nch,nbad,ok] = chk(nch,nbad,ok,[pre ' xlim is explicit'], ...
                strcmp(get(ax,'XLimMode'),'manual'), get(ax,'XLimMode'));
        end
        [nch,nbad,ok] = chk(nch,nbad,ok,[pre ' xlabel'], ...
            streq(get(get(ax,'XLabel'),'String'),E.xlab), ...
            ['"' char(get(get(ax,'XLabel'),'String')) '" want "' char(E.xlab) '"']);
        [nch,nbad,ok] = chk(nch,nbad,ok,[pre ' ylabel'], ...
            streq(get(get(ax,'YLabel'),'String'),E.ylab), ...
            ['"' char(get(get(ax,'YLabel'),'String')) '" want "' char(E.ylab) '"']);

        L = classify_lines(ax);
        [nch,nbad,ok] = chk(nch,nbad,ok,[pre ' n solid'], ...
            numel(L.solid)==E.nsolid, sprintf('%d (want %d)',numel(L.solid),E.nsolid));
        [nch,nbad,ok] = chk(nch,nbad,ok,[pre ' n dash-dot'], ...
            numel(L.dashdot)==E.ndashdot, sprintf('%d (want %d)',numel(L.dashdot),E.ndashdot));
        [nch,nbad,ok] = chk(nch,nbad,ok,[pre ' n legend-proxy'], ...
            numel(L.proxy)==E.proxy, sprintf('%d (want %d)',numel(L.proxy),E.proxy));

        % solid line colours
        if numel(L.solid)==E.nsolid && ~isempty(E.solidcols)
            good = true;  detail = '';
            for k = 1:numel(L.solid)
                if max(abs(L.solid{k} - c(E.solidcols(k),:))) > 1e-6
                    good = false;
                    detail = sprintf('line %d is %s, want row %d', ...
                                     k, mat2str(L.solid{k},3), E.solidcols(k));
                end
            end
            [nch,nbad,ok] = chk(nch,nbad,ok,[pre ' solid colours'], good, detail);
        end

        % THE colour-pairing check: dash-dot k must equal solid k must equal row k
        if E.ndashdot > 0 && numel(L.dashdot)==E.ndashdot && numel(L.solid)==E.nsolid
            good = true;  detail = '';
            for k = 1:E.ndashdot
                if max(abs(L.dashdot{k} - L.solid{k})) > 1e-6
                    good = false;
                    detail = sprintf('channel %d dash-dot %s vs solid %s', ...
                        k, mat2str(L.dashdot{k},3), mat2str(L.solid{k},3));
                elseif max(abs(L.dashdot{k} - c(k,:))) > 1e-6
                    good = false;
                    detail = sprintf('channel %d is %s, want row %d', ...
                        k, mat2str(L.dashdot{k},3), k);
                end
            end
            [nch,nbad,ok] = chk(nch,nbad,ok, ...
                [pre ' dash-dot colour == solid colour == rhi_colors'], good, detail);

            % and the "real lambda" key must not belong to a channel
            if numel(L.proxy)==1
                isblack = max(abs(L.proxy{1})) < 1e-6;
                [nch,nbad,ok] = chk(nch,nbad,ok,[pre ' "real lambda" key is black'], ...
                                    isblack, mat2str(L.proxy{1},3));
            end
        end

        if ~isempty(E.legend)
            got = legend_strings(hf, ax);
            same = numel(got)==numel(E.legend) && ...
                   all(cellfun(@(a_,b_) streq(a_,b_), got(:)', E.legend(:)'));
            [nch,nbad,ok] = chk(nch,nbad,ok,[pre ' legend'], same, strjoin(got,' | '));
        end
    end
    close(hf);
end

fprintf('\n  %d checks, %d failed\n', nch, nbad);
if ok
    fprintf('  ALL PASS\n\n');
else
    fprintf('  *** FAILURES ABOVE ***\n\n');
    error('rhi_audit_figures:fail','%d of %d checks failed.', nbad, nch);
end
end

% ==========================================================================
function [nch,nbad,ok] = chk(nch,nbad,ok,name,pass,detail)
nch = nch + 1;
if pass
    fprintf('    ok   %s\n', name);
else
    nbad = nbad + 1;  ok = false;
    fprintf('    FAIL %s  -> %s\n', name, detail);
end
end

function axs = sorted_axes(hf)
%SORTED_AXES  Non-legend axes, ordered top-to-bottom then left-to-right.
a = findall(hf,'type','axes');
keep = true(numel(a),1);
for k = 1:numel(a)
    if strcmp(get(a(k),'Tag'),'legend'), keep(k) = false; end
end
a = a(keep);
pos = zeros(numel(a),2);
for k = 1:numel(a)
    pp = get(a(k),'Position');  pos(k,:) = [pp(1) pp(2)];
end
% column-major like subplot(4,2,...): left column top-to-bottom, then right
[~,i] = sortrows([round(pos(:,1)*20) -pos(:,2)], [1 2]);
axs = a(i);
end

function L = classify_lines(ax)
%CLASSIFY_LINES  Split an axes' lines into estimates, truth, keys and guides.
ln = findall(ax,'Type','line');   % findall, not findobj: the true-lambda
                                 % and guide lines have HandleVisibility off
ln = ln(end:-1:1);                       % findobj is reverse creation order
L = struct('solid',{{}},'dashdot',{{}},'dashed',{{}},'proxy',{{}});
for k = 1:numel(ln)
    x  = get(ln(k),'XData');
    st = get(ln(k),'LineStyle');
    hv = get(ln(k),'HandleVisibility');
    cc = get(ln(k),'Color');
    if all(isnan(x))
        L.proxy{end+1} = cc;                              % legend-only proxy
    elseif strcmp(st,'-.')
        L.dashdot{end+1} = cc;                            % true lambda
    elseif strcmp(st,'-') && strcmp(hv,'on')
        L.solid{end+1} = cc;                              % data
    else
        L.dashed{end+1} = cc;                             % guide lines
    end
end
end

function s = legend_strings(hf, ax)
%LEGEND_STRINGS  The legend entries of AX, portable across interpreters.
s = {};
lg = findall(hf,'Type','legend');                 % MATLAB
if isempty(lg), lg = findall(hf,'Tag','legend');  end   % Octave
for k = 1:numel(lg)
    owner = [];
    if isprop_safe(lg(k),'Axes'),        owner = get(lg(k),'Axes');
    elseif isprop_safe(lg(k),'UserData') 
        u = get(lg(k),'UserData');
        if isstruct(u) && isfield(u,'handle'), owner = u.handle; end
    end
    near = isempty(owner) && overlaps(lg(k), ax);
    if (~isempty(owner) && any(owner == ax)) || near
        try, s = cellstr(get(lg(k),'String')); catch, s = {}; end
        return
    end
end
end

function t = isprop_safe(h,name)
try, get(h,name); t = true; catch, t = false; end
end

function t = overlaps(lg, ax)
%OVERLAPS  True if the legend box sits inside the axes box (Octave fallback).
a = get(ax,'Position');  l = get(lg,'Position');
t = l(1) >= a(1)-0.02 && l(1) <= a(1)+a(3)+0.02 && ...
    l(2) >= a(2)-0.02 && l(2) <= a(2)+a(4)+0.02;
end

function t = streq(a, b)
%STREQ  String compare that treats 0x0 and 1x0 empties as equal.
if isempty(a), a = ''; end
if isempty(b), b = ''; end
t = strcmp(char(a), char(b));
end

function s = merge(c,a,b)
if c, s = a; else, s = b; end
end
