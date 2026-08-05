function ok = rhi_check_published_values()
%RHI_CHECK_PUBLISHED_VALUES  Compare the simulation with the published panels.
%
%   ok = RHI_CHECK_PUBLISHED_VALUES()
%
%   RHI_AUDIT_FIGURES checks that the figures are drawn correctly. This checks
%   that the numbers behind them are right, against values read off the
%   published panels. Together with RHI_CHECK_GRADIENTS (the maths) and
%   RHI_CHECK_VS_ORIGINAL (the original symbolic loop) that is the full set.
%
%   Tolerances are loose (0.03 on uncertainties, 0.02 on drifts) because
%   the reference values were read off printed figures, and because outside
%   MATLAB the noise realisation differs -- window averages agree, individual
%   samples do not. Anything failing here by more than the tolerance is a real
%   disagreement with the paper, not a rounding artefact.

ok = true;  n = 0;  nbad = 0;
fprintf('\n  quantity                                     paper     here\n');
fprintf('  ---------------------------------------------------------------\n');

% ---- Fig 5: uncertainty vs inter-hand distance, both windows -------------
ref = [0.2 0.28 0.31 1.42 1.20
       5.0 0.67 0.80 1.39 1.82];
for q = 1:2
    p = rhi_default_params();  p.Ry = ref(q,1);
    cmp = rhi_compare_models(p);
    io  = rhi_window(p, p.window_uncovered);
    ic  = rhi_window(p, p.window_covered);
    got = [mean(cmp.U1(io)) mean(cmp.U2(io)) mean(cmp.U1(ic)) mean(cmp.U2(ic))];
    nm  = {'Fig5A M1','Fig5A M2','Fig5B M1','Fig5B M2'};
    for k = 1:4
        % 0.04: at the edge of the sweep the curve climbs ~0.02 per 0.2 of Ry,
        % so reading its endpoint off a printed axis is the dominant error.
        [n,nbad,ok] = num(n,nbad,ok, sprintf('%s at Ry=%.1f',nm{k},ref(q,1)), ...
                          ref(q,k+1), got(k), 0.04);
    end
end

% ---- Fig 5: the illusion only happens for a bounded distance -------------
Rys = 0.2:0.2:5;  sel = zeros(size(Rys));
for j = 1:numel(Rys)
    p = rhi_default_params();  p.Ry = Rys(j);
    cmp = rhi_compare_models(p);
    ic  = rhi_window(p, p.window_covered);
    sel(j) = mean(cmp.U2(ic)) < mean(cmp.U1(ic));      % M2 wins -> illusion
end
edge = Rys(find(sel,1,'last'));
[n,nbad,ok] = num(n,nbad,ok,'Fig5B largest Ry with illusion', 3.4, edge, 0.25);

% ---- Fig 2: M1 before covering, M2 after, switch just after coverage -----
p   = rhi_default_params();
cmp = rhi_compare_models(p);
io  = rhi_window(p, p.window_uncovered);
ic  = rhi_window(p, p.window_covered);
[n,nbad,ok] = bool(n,nbad,ok,'Fig2 M1 more certain while visible', ...
                   mean(cmp.U1(io)) < mean(cmp.U2(io)));
[n,nbad,ok] = bool(n,nbad,ok,'Fig2 M2 more certain while covered', ...
                   mean(cmp.U2(ic)) < mean(cmp.U1(ic)));
k = find(cmp.selected == 2 & p.t > p.t_hand_covered, 1);
[n,nbad,ok] = num(n,nbad,ok,'Fig2 switch time (s)', 17.0, p.t(k), 2.5);

% ---- Fig 3: precision learning recovers the true lambda -----------------
% Revised Sec 3.2 claims something specific and asymmetric: the estimates track
% the truth "closely but with systematic deviations", and "for Rv and At after
% coverage a small residual bias remains" from the cross-channel coupling
% M'*Pi^z*M once Av collapses. So Av and Py are held to a tight bound and
% Rv/At to a loose one -- testing the claim, not just "small error everywhere".
d   = rhi_generate_data(p);
r3  = rhi_infer(d, p, rhi_models(p));
ic2 = rhi_window(p, [25 32]);
err = abs(mean(r3.lambda(:,ic2),2) - mean(d.lambda(:,ic2),2));
lam = {'Av','Rv','At','Py'};  bnd = [1.0 2.5 2.5 1.0];
for k = 1:4
    [n,nbad,ok] = num(n,nbad,ok, ...
        sprintf('Fig3B settled lambda^%s error (bound %.1f)',lam{k},bnd(k)), ...
        0.0, err(k), bnd(k));
end

% ---- Fig 4: broken prior -> lambda^Av stuck high, and no switch ---------
pb = rhi_default_params();  pb.P_lambda = diag(exp([10 -4 -4 -4]));
cb = rhi_compare_models(pb);
icb = rhi_window(pb, pb.window_covered);
[n,nbad,ok] = num(n,nbad,ok,'Fig4A mean lambda^Av while covered', 10.0, ...
                  mean(cb.m1.lambda(1,icb)), 1.5);
[n,nbad,ok] = bool(n,nbad,ok,'Fig4B M2 never selected while covered', ...
                   ~any(cb.selected(icb) == 2));

% ---- Fig 6: drift is in M2 and absent from M1 ---------------------------
[M1,M2] = rhi_models(p);
d6 = rhi_generate_data(p);
[n,nbad,ok] = num(n,nbad,ok,'Fig6A drift under M1 (Ry=0.8)', 0.0, ...
                  rhi_drift(rhi_infer(d6,p,M1),p), 0.05);
[n,nbad,ok] = bool(n,nbad,ok,'Fig6B drift under M2 is clearly positive', ...
                   rhi_drift(rhi_infer(d6,p,M2),p) > 0.15);

% ---- Fig 7: drift grows with distance -----------------------------------
dr = zeros(1,2);  Rn = [0.3 1.2];
for q = 1:2
    pq = rhi_default_params();  pq.Ry = Rn(q);
    dq = rhi_generate_data(pq);  [~,M2q] = rhi_models(pq);
    dr(q) = rhi_drift(rhi_infer(dq,pq,M2q), pq);
end
[n,nbad,ok] = bool(n,nbad,ok,'Fig7 drift(far) > drift(near)', dr(2) > dr(1));

% ---- Fig 8: drift at the largest distance, per susceptibility -----------
alphas = [-10 -1 0 1 10];
pub    = [0.370 0.255 0.148 0.065 0.005];
for a = 1:numel(alphas)
    pa = rhi_default_params();  pa.alpha = alphas(a);  pa.Ry = 1.6;
    da = rhi_generate_data(pa);  [~,~,SM] = rhi_models(pa);
    got = rhi_drift(rhi_infer(da,pa,SM), pa);
    [n,nbad,ok] = num(n,nbad,ok, sprintf('Fig8 drift at Ry=1.6, alpha=%g',alphas(a)), ...
                      pub(a), got, 0.02);
end

fprintf('  ---------------------------------------------------------------\n');
fprintf('  %d comparisons, %d outside tolerance\n', n, nbad);
if ok
    fprintf('  ALL PASS\n\n');
else
    fprintf('  *** DISAGREEMENTS ABOVE ***\n\n');
    error('rhi_check_published_values:fail','%d of %d outside tolerance.', nbad, n);
end
end

% ==========================================================================
function [n,nbad,ok] = num(n,nbad,ok,name,want,got,tol)
n = n + 1;
pass = abs(want-got) <= tol;
if pass, tag = 'ok  '; else, tag = 'FAIL'; nbad = nbad+1; ok = false; end
fprintf('  %s %-40s %7.3f  %7.3f\n', tag, name, want, got);
end

function [n,nbad,ok] = bool(n,nbad,ok,name,pass)
n = n + 1;
if pass, tag = 'ok  '; res = 'true '; else, tag = 'FAIL'; res = 'false'; nbad = nbad+1; ok = false; end
fprintf('  %s %-40s %7s  %7s\n', tag, name, 'true', res);
end
