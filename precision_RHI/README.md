# precision_RHI

MATLAB code reproducing every figure of

> F. Novický, A. Anil Meera, F. Zeldenrust, P. Lanillos.
> *Online precision adaptation to model body-ownership illusion dynamics under
> Bayesian inference.*

[![checks](https://github.com/ajitham123/precision_RHI/actions/workflows/checks.yml/badge.svg)](https://github.com/ajitham123/precision_RHI/actions/workflows/checks.yml)

The model treats the rubber hand illusion as a consequence of uncertainty
minimisation. An agent holds two hypotheses about the world — *M₁*, "my hand is
my real hand", and *M₂*, "my hand is the rubber hand" — learns the precision
(inverse variance) of each sensory channel online, and at every moment believes
whichever hypothesis leaves it least uncertain about its own body state.
Occluding the real hand makes its visual channel noisy; precision learning
follows that noise down; the posterior uncertainty of *M₁* overtakes that of
*M₂*; and the agent switches. The proprioceptive drift falls out of state
estimation under *M₂*, separately from the switch itself.

## Requirements

- MATLAB R2016b or newer, no toolboxes required. GNU Octave 6+ also works — see
  [Octave differences](docs/PAPER_CORRESPONDENCE.md#running-under-octave).
- The Symbolic Math Toolbox is needed for one optional check
  (`rhi_check_vs_original`) and for nothing else.

## Quick start

```matlab
setup_path                  % adds code/ and tests/ to the path
run_all_figures             % every figure, about 30 s
run_all_figures(true)       % and write PNGs to ./figures_out
run_all_checks              % verify the gradients, the numbers and the figures
```

Every figure is a function taking an optional parameter struct, so a single
panel can be regenerated on its own with anything overridden:

```matlab
fig06_drift_by_model                              % as published
p = rhi_default_params();  p.Ry = 1.2;
fig06_drift_by_model(p)                           % rubber hand further away
```

## The figures

| script | paper | shows |
|---|---|---|
| `fig02_perceptual_switch` | Fig 2 | posterior uncertainty of *M₁* and *M₂*; the switch after occlusion |
| `fig03_precision_adaptation` | Fig 3 | the noisy Av channel, and λ tracking the true noise online |
| `fig04_breaking_precision` | Fig 4 | disable precision learning on Av and the switch never happens |
| `fig05_illusion_vs_distance` | Fig 5 | the illusion only occurs for \|Ry\| ≲ 3.4 |
| `fig06_drift_by_model` | Fig 6 | drift is structural to *M₂* and absent from *M₁* |
| `fig07_drift_by_distance` | Fig 7 | drift grows with inter-hand distance |
| `fig08_drift_by_susceptibility` | Fig 8 | drift against distance and susceptibility α |

Figure 1 is a schematic and has no code. Only the uncertainty panel of Figure 2
is generated; the photographs, arrows and panel numbers of the published version
were composited separately, as were the brush and hand icons on Figs 3, 6 and 7.

## Verification

`run_all_checks` runs three checks that need no toolbox, and errors on any
failure, so it doubles as the CI entry point.

| check | what it establishes |
|---|---|
| `rhi_check_gradients` | the closed-form gradients of Eq (7) match central differences of *F* (12 checks, worst relative error 6·10⁻⁸) |
| `rhi_check_published_values` | the simulation matches values read off the published panels (26 comparisons) |
| `rhi_audit_figures` | every axis limit, label, legend entry, line style and colour matches the published panels (228 checks) |
| `rhi_check_vs_original` | `rhi_infer` reproduces the original Symbolic Toolbox loop step for step — *optional, needs the toolbox* |

`rhi_infer` writes the four gradients of the free energy out in closed form
rather than differentiating symbolically at every time step, which is what makes
the parameter sweeps of Figs 5 and 8 feasible: 0.13 s per trial instead of about
a minute. `rhi_infer_symbolic` keeps the original `sym`/`eval` loop, untidied, so
that `rhi_check_vs_original` compares against the original computation and not a
reinterpretation of it.

`rhi_audit_figures` reads properties back out of the graphics objects instead of
trusting the rendered image, so it catches an argument left on the wrong value or
an axis limit that only looks right because the data happen to fill it. Its
expected colours are hard-coded rather than read from `rhi_colors`, because
otherwise editing the palette would change both sides of the comparison and pass
silently.

## Layout

```
setup_path.m              put code/ and tests/ on the path
code/
  rhi_default_params.m    every parameter, in one place
  rhi_models.m            M1, M2 and the alpha-mixture   — Eqs (2)-(4)
  rhi_generate_data.m     the environment: causes, true lambda, observations
  rhi_infer.m             the agent                      — Eqs (7)-(10)
  rhi_compare_models.m    M1 and M2 on identical data    — Eq (5)
  rhi_drift.m             the proprioceptive drift measure
  rhi_plot_*.m            panels shared between figures
  fig02_*.m … fig08_*.m   one function per figure
  run_all_figures.m
tests/
  run_all_checks.m        entry point for all checks
  rhi_check_*.m           the checks themselves
  rhi_infer_symbolic.m    the original symbolic loop, for comparison only
docs/
  PAPER_CORRESPONDENCE.md which parameters produce which figure, and where the
                          code and the manuscript differ
```

## Correspondence with the paper

[`docs/PAPER_CORRESPONDENCE.md`](docs/PAPER_CORRESPONDENCE.md) records the exact
parameter values behind each figure, and documents several places where the
manuscript text and this code do not agree — most importantly the definition of
the drift measure summarised in Fig 8. Read it before comparing numbers with the
published panels.

## Citing

See [`CITATION.cff`](CITATION.cff), or cite the paper directly. Please cite the
paper rather than this repository if you are only using the model.

## Licence

[MIT](LICENSE).
