function ok = rhi_check_vs_original(nsteps, tol)
%RHI_CHECK_VS_ORIGINAL  Prove RHI_INFER == the original symbolic loop.
%
%   ok = RHI_CHECK_VS_ORIGINAL(nsteps,tol)   default 40 steps, tol 1e-9
%
%   Runs RHI_INFER and RHI_INFER_SYMBOLIC on identical data and compares the
%   state estimates, the learned lambda, the posterior uncertainty and the free
%   energy step by step.  Checks the normal prior and the broken-Av prior of
%   Fig 4, and both M1 and M2.
%
%   REQUIRES the Symbolic Math Toolbox; run it once after checking out the code
%   and then forget about it.  RHI_CHECK_GRADIENTS is the toolbox-free check.

if nargin < 1 || isempty(nsteps), nsteps = 40;   end
if nargin < 2 || isempty(tol),    tol    = 1e-9; end

configs = { 'M1, learning on',  1, diag(exp([-4 -4 -4 -4]))
            'M2, learning on',  2, diag(exp([-4 -4 -4 -4]))
            'M1, Av broken',    1, diag(exp([10 -4 -4 -4]))
            'M2, Av broken',    2, diag(exp([10 -4 -4 -4])) };

fprintf('\n  comparing %d steps, tolerance %.0e\n', nsteps, tol);
fprintf('  config              max|dX|   max|dlam|  max|dsigma|  max|dF|\n');
fprintf('  ----------------------------------------------------------------\n');
worst = 0;
for q = 1:size(configs,1)
    p = rhi_default_params();
    p.P_lambda = configs{q,3};
    d          = rhi_generate_data(p);
    Ms         = cell(1,2);  [Ms{1}, Ms{2}] = rhi_models(p);
    M          = Ms{configs{q,2}};

    a = rhi_infer(d, p, M);
    b = rhi_infer_symbolic(d, p, M, nsteps);

    k = 1:nsteps;
    e = [max(max(abs(a.x(:,k)      - b.x(:,k)))), ...
         max(max(abs(a.lambda(:,k) - b.lambda(:,k)))), ...
         max(max(abs(a.sigma(:,k)  - b.sigma(:,k)))), ...
         max(abs(a.F(k)            - b.F(k)))];
    worst = max(worst, max(e));
    fprintf('  %-18s %9.2e %9.2e %11.2e %9.2e\n', configs{q,1}, e);
end
ok = worst < tol;
fprintf('  ----------------------------------------------------------------\n');
if ok, verdict = 'PASS'; else, verdict = 'FAIL'; end
fprintf('  worst absolute difference %.2e  ->  %s\n\n', worst, verdict);
if ~ok
    error('rhi_check_vs_original:fail','Mismatch %.2e > %g.', worst, tol);
end
end
