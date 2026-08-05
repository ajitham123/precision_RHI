function ok = rhi_check_gradients(tol)
%RHI_CHECK_GRADIENTS  Finite-difference check of the gradients in RHI_INFER.
%
%   ok = RHI_CHECK_GRADIENTS()  prints a table and errors if anything is off.
%
%   RHI_INFER writes dF/dlambda, d2F/dlambda2, dF/dX and d2F/dX2 out in closed
%   form where the original script obtained them with the Symbolic Toolbox.
%   This validates them against central differences of F itself, so it needs no
%   toolbox and runs anywhere.  RHI_CHECK_VS_ORIGINAL is the complementary
%   end-to-end check against the actual symbolic loop.
%
%   The trace term -0.5*(log det Pi^X + log det Pi^lambda) of Eq (7) is left out
%   of F below: the original code substitutes those two matrices numerically
%   AFTER differentiating, so symbolically they are constants and contribute
%   nothing to any gradient.

if nargin < 1 || isempty(tol), tol = 1e-6; end

p  = rhi_default_params();
M  = rhi_models(p);
ny = p.ny;  nu = p.nu;

F = @(l,x,y) -0.5*(y - M*x).'*diag(exp(l))*(y - M*x) + 0.5*sum(l) ...
             -0.5*((l - p.eta_lambda).'*p.P_lambda*(l - p.eta_lambda)) ...
             -0.5*((x - p.eta_u).'*p.P_u*(x - p.eta_u));

rhi_seed(7);
cases = {'random',            randn(ny,1),                  randn(nu,1),     randn(ny,1)
         'realistic visible', p.lambda_visible+0.3*randn(ny,1), 0.5*randn(nu,1), randn(ny,1)
         'realistic covered', p.lambda_covered+0.3*randn(ny,1), 0.5*randn(nu,1), 3*randn(ny,1)};

fprintf('\n  case                 dF/dlam   d2F/dlam2   dF/dX     d2F/dX2\n');
fprintf('  ------------------------------------------------------------\n');
worst = 0;
for q = 1:size(cases,1)
    l = cases{q,2};  x = cases{q,3};  y = cases{q,4};
    e = y - M*x;     Pz = diag(exp(l));

    a1 = 0.5 - 0.5*(e.^2).*exp(l) - p.P_lambda*(l - p.eta_lambda);
    a2 = -diag(0.5*(e.^2).*exp(l)) - p.P_lambda;
    a3 = M.'*Pz*e - p.P_u*(x - p.eta_u);
    a4 = -(M.'*Pz*M + p.P_u);

    [f1,f2] = fd(@(v) F(v,x,y), l);
    [f3,f4] = fd(@(v) F(l,v,y), x);

    rel = @(A,B) max(abs(A(:)-B(:)))/max(1,max(abs(B(:))));
    r   = [rel(a1,f1) rel(a2,f2) rel(a3,f3) rel(a4,f4)];
    worst = max(worst, max(r));
    fprintf('  %-18s %9.2e %9.2e %9.2e %9.2e\n', cases{q,1}, r);
end
ok = worst < tol;
fprintf('  ------------------------------------------------------------\n');
if ok, verdict = 'PASS'; else, verdict = 'FAIL'; end
fprintf('  worst relative error %.2e  ->  %s\n\n', worst, verdict);
if ~ok
    error('rhi_check_gradients:fail','Gradient mismatch %.2e > %g.', worst, tol);
end
end

function [g, H] = fd(f, v)
%FD  Central-difference gradient and Hessian of a scalar function.
n  = numel(v);  d1 = 1e-6;  d2 = 1e-4;
g  = zeros(n,1);  H = zeros(n);
for i = 1:n
    ei = zeros(n,1);  ei(i) = 1;
    g(i) = (f(v+d1*ei) - f(v-d1*ei))/(2*d1);
    for j = 1:n
        ej = zeros(n,1);  ej(j) = 1;
        H(i,j) = (f(v+d2*ei+d2*ej) - f(v+d2*ei-d2*ej) ...
                - f(v-d2*ei+d2*ej) + f(v-d2*ei-d2*ej))/(4*d2^2);
    end
end
end
