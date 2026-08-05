function cmp = rhi_compare_models(p)
%RHI_COMPARE_MODELS  Run M1 and M2 on the same data and apply Eq (5).
%
%   cmp = RHI_COMPARE_MODELS(p) generates one realisation of the experiment
%   and runs the agent twice on *identical* sensory data, once believing M1
%   ("my hand is my real hand") and once believing M2 ("I own the rubber
%   hand").  The model with the lower posterior state uncertainty is the
%   selected one; the illusion starts when that switches from M1 to M2.
%
%   Fields:  data, m1, m2 (outputs of RHI_INFER), U1, U2, selected (1 or 2).

d       = rhi_generate_data(p);
[M1,M2] = rhi_models(p);

cmp.p        = p;
cmp.data     = d;
cmp.m1       = rhi_infer(d, p, M1);
cmp.m2       = rhi_infer(d, p, M2);
cmp.U1       = cmp.m1.U;
cmp.U2       = cmp.m2.U;
cmp.selected = 1 + (cmp.U2 < cmp.U1);      % Eq (5), argmin over the models
end
