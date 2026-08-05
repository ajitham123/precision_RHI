# Correspondence between this code and the manuscript

> **Review this file before making the repository public.** Several items below
> are places where the manuscript and the code disagree. Most of them would be
> better fixed in the manuscript than documented here.

## Parameters behind each figure

Everything comes from `rhi_default_params`, which is the parameter list of
Appendix 5.1 in executable form. Only the deviations from those defaults are
listed here.

| figure | model | changed from the defaults |
|---|---|---|
| Fig 2 | *M₁* and *M₂* | — (`Ry = 0.8`) |
| Fig 3 | *M₁* | — |
| Fig 4 | *M₁* and *M₂* | `P_lambda = diag(exp([10 -4 -4 -4]))` |
| Fig 5 | *M₁* and *M₂* | `Ry = -5:0.2:5`, excluding `Ry = 0` |
| Fig 6 | *M₁* and *M₂*, frozen | — |
| Fig 7 | *M₂* | `Ry = 0.3` and `Ry = 1.2` |
| Fig 8 | α-mixture | `alpha ∈ {-10,-1,0,1,10}`, `Ry = -1.6:0.2:1.6` |

Defaults worth restating: `T = 32 s`, `dt = 0.1 s`, true λ `[9 7 8 10]` while the
hand is visible and `[-1 7 8 4]` once covered, `eta_lambda = [10 10 10 10]`,
`P_lambda = diag(exp([-4 -4 -4 -4]))`, `P_u = I`, all learning rates `k = 4`,
`Ay = 0`, noise seed 12.

## Values reproduced

| quantity | published | this code |
|---|---|---|
| Fig 5A, Ry→0 | *M₁* 0.28 / *M₂* 0.31 | 0.29 / 0.32 |
| Fig 5A, Ry = 5 | *M₁* 0.67 / *M₂* 0.80 | 0.68 / 0.83 |
| Fig 5B, Ry→0 | *M₁* 1.42 / *M₂* 1.20 | 1.43 / 1.21 |
| Fig 5B, Ry = 5 | *M₁* 1.39 / *M₂* 1.82 | 1.39 / 1.81 |
| Fig 5B, largest Ry with illusion | ≈ 3.4 | 3.4 |
| Fig 8 at Ry = 1.6 | 0.370 / 0.255 / 0.148 / 0.065 | 0.367 / 0.256 / 0.149 / 0.071 |
| Fig 4A, mean λ^Av while covered | "around 10" | 9.3 (true value −1) |

The Ry = 5 entry of Fig 5A is the loosest match, at 0.83 against a read-off
0.80. At the edge of that sweep the curve climbs about 0.02 per 0.2 of Ry, so
reading its endpoint off a printed axis is the dominant source of the difference.

## Where the code and the manuscript disagree

### 1. The drift measure summarised in Fig 8

Three places define it differently:

- Appendix 5.1 — "the average of *Sy* between the 17th and the 30th second"
- Fig 8 caption — "the maximum value of the proprioceptive drift"
- the original script — `mean(brain.u(4,170:300))`, i.e. the mean over 16.9–29.9 s

These are not interchangeable, because the drift is far from flat across that
window. At `Ry = 1.6`, `alpha = -10` it is about 0.06 over 16–18 s, about 0.68
over 20–28 s, and about 0.00 by 30–32 s, since the strokes stop at t = 28 and the
drift decays once stimulation ends. So:

| summary | value at Ry = 1.6, α = −10 |
|---|---|
| mean over 16.9–29.9 s (the original script) | 0.48 |
| mean over 15–32 s (the whole covered half) | 0.37 |
| maximum over the window | ≈ 0.9 |

The published Fig 8 shows 0.37, and averaging over the whole covered half
reproduces all five α curves. `rhi_drift` therefore defaults to
`drift_window = [15 32]` with `drift_stat = 'mean'`. **Either the Appendix and
the caption need correcting, or Fig 8 needs regenerating with the stated
window.** The shape, ordering and α-dependence of the curves are the same under
any of these choices; only the absolute scale changes.

### 2. Stroke amplitudes

Appendix 5.1 gives the bump magnitudes for *Ea, Er, Et, Sy* as 0.5, 1, 1, 0. The
script uses those only while the hand is visible. Once it is covered, `Ea = 0`
for every stroke, and the final bump at t = 28 additionally has `Et = 0` ("hand
covered, not touched"). The table in `rhi_default_params` follows the script,
since that is what the published figures show. The Appendix appears to describe
only the visible-hand strokes.

### 3. Onset of hand coverage

The λ step is placed at sample `floor(nt/2) = 160`, i.e. t = 16.0 s, while the
text and every figure annotation say 15 s. The discrepancy is 1 s and affects
nothing else, but the two should be aligned. `cover_frac` controls it.

### 4. The vertical axis of Figs 2, 4B and 5

It is the **trace** of Eq (5), `sum(sigma,1)` — the sum over the four state
components of the posterior standard deviations. It is not an average across
channels: that would be four times smaller and would not match the published
panels. The word "mean" in the Fig 5 caption refers to the average over the
evaluation window in time.

### 5. Π^λ

Algorithm 1 lists Π^λ as an evaluated posterior precision, but the code sets it
equal to the prior P^λ. It enters only the free-energy diagnostic and no figure,
so no result depends on it; `rhi_infer` keeps the original behaviour and returns
`F` for reference.

### 6. Figs 3B and 4A are expected to be near-identical away from Av

The λ update is diagonal in the channels, so raising the prior precision on λ^Av
leaves the others almost untouched: λ^Rv moves by 0.02, λ^At by 0.06 and λ^Py by
0.0003, all invisible on a −2…12 axis. The two panels therefore differ only in
the Av trace, by construction. Worth stating in Section 3.3, since identical
traces across two figures otherwise look like an error.

### 7. α for Figs 3 and 4

Not stated anywhere in the manuscript. These scripts use *M₁*. By item 6 the
choice barely affects the panels, but it should be recorded.

### 8. The "real λ" legend key

Figs 3B and 4A draw four solid estimates and four dash-dot true values, then
label five entries. A legend given five labels attaches the fifth to the fifth
line *drawn*, which is the Av dash-dot line, so the key takes Av's colour and
reads as "real λ for Av" rather than "dash-dot means ground truth".
`rhi_plot_lambda` defaults to `'match'`, which adds an off-screen black dash-dot
proxy purely to own that legend slot. `'key-Av'` reproduces the coloured key and
`'black'` reproduces an all-black set of true-value lines.

### 9. Residual λ bias, and why the checks allow it

`rhi_check_published_values` holds λ^Av and λ^Py to within 1.0 of the true value
once settled, but λ^Rv and λ^At only to 2.5. That asymmetry is deliberate:
Section 3.2 states that those two channels retain a residual bias because their
effective signal-to-noise changes through the cross-channel coupling
`Mᵀ Π^z M` once Av collapses. Measured errors over 25–32 s are Av 0.60,
Py 0.22, At 1.46, Rv 1.85, which is the pattern the text describes.

## Running under Octave

The code runs under Octave 6+, with three differences that matter when comparing
against the published figures.

1. **The noise realisation.** MATLAB's `rng(12)` and Octave's generator differ,
   so individual traces differ sample by sample. Window averages agree, which is
   why the checks compare averages. `rhi_seed` handles both.
2. **`smoothdata`.** Octave does not provide it, so `rhi_smooth` falls back to an
   approximate gaussian window. The effect is bounded: the drift changes by less
   than 0.005 across smoothing windows from 1 to 128 samples, and by less than
   0.005 across noise seeds 1–8.
3. **Legend rendering.** The gnuplot toolkit, which is what works on a headless
   runner, draws legend line samples poorly. The lines themselves are correct;
   `rhi_audit_figures` verifies every colour independently of how they render.

For a figure intended for publication, generate it in MATLAB.
