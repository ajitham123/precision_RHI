function ok = run_all_checks(include_symbolic)
%RUN_ALL_CHECKS  Verify the model, the numbers and the figures.
%
%   run_all_checks         the three checks that need no toolbox
%   run_all_checks(true)   also the end-to-end check against the original
%                          symbolic loop (needs the Symbolic Math Toolbox)
%
%   1  RHI_CHECK_GRADIENTS         the closed-form gradients of Eq (7) against
%                                  central differences of F
%   2  RHI_CHECK_PUBLISHED_VALUES  the simulation against values read off the
%                                  published panels
%   3  RHI_AUDIT_FIGURES           each figure's axis limits, labels, legends,
%                                  line styles and colours
%   4  RHI_CHECK_VS_ORIGINAL       RHI_INFER against RHI_INFER_SYMBOLIC, the
%                                  original Symbolic Toolbox loop
%
%   Any failure raises an error, so this is usable as a CI entry point.

if nargin < 1 || isempty(include_symbolic), include_symbolic = false; end

t0 = tic;
fprintf('\n================ 1/3  gradients ================\n');
rhi_check_gradients;
fprintf('================ 2/3  numbers ==================\n');
rhi_check_published_values;
fprintf('================ 3/3  figures ==================\n');
rhi_audit_figures;

if include_symbolic
    fprintf('================ 4/4  symbolic =================\n');
    rhi_check_vs_original;
end

ok = true;
fprintf('all checks passed in %.1f s\n\n', toc(t0));
end
