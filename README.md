# Precision adaptation and the rubber hand illusion

MATLAB implementation of the model in:

> Novický, F., Anil Meera, A., Zeldenrust, F., & Lanillos, P.
> *Online precision adaptation to model body-ownership illusion dynamics under Bayesian inference.*

## The idea

Body-ownership illusions and proprioceptive drift are usually treated as one
phenomenon, but experimentally they can dissociate. This model separates them
into two computations that run in parallel:

- **Drift** comes from *state estimation* — minimising prediction error pulls the
  perceived hand position towards the rubber hand.
- **Ownership** comes from *uncertainty minimisation* — the brain picks whichever
  hypothesis about the world leaves it least uncertain.

The agent holds two hypotheses:

| | |
|---|---|
| `M1` | "my hand is my real hand" |
| `M2` | "my hand is the rubber hand" |

They differ only in where the felt touch and the felt hand position come from:
the real hand (`Ea`) under `M1`, the rubber hand (`Er`) under `M2`.

Covering the real hand is modelled as the visual channel `Av` becoming very
noisy. Online precision learning notices this and down-weights `Av`. `M1` then
loses its grip on the hand position and its posterior uncertainty rises, while
`M2` stays anchored via the rubber-hand channel. When `M2` becomes the more
certain model, the illusion begins.

Both computations are gradient descent on the same free energy, so the whole
thing is one continuous-time system rather than a static probability
calculation — which is what lets it show *when* the illusion emerges, not just
whether it does.

## Running it

Requires MATLAB R2017a or newer (for `smoothdata`). No toolboxes — in
particular, no Symbolic Math Toolbox.

```matlab
precision_RHI          % all figures, ~30 s
precision_RHI(2,5,8)   % just these
```

For a single condition:

```matlab
f = precision_RHI('api');
p = f.default_params();  p.Ry = 2;  p.brain = 'M2';
s = f.simulate(p);       plot(s.t, s.Xh(4,:))
```

## Figures

| | |
|---|---|
| 2 | the perceptual switch, and the drift it produces |
| 3 | precision learning tracks the true noise level |
| 4 | freeze `Av` precision with a strong prior → no switch, no illusion |
| 5 | the switch only happens for moderate inter-hand distances |
| 6 | drift appears under `M2`, not under `M1` |
| 7 | a farther rubber hand gives a larger drift |
| 8 | drift vs. distance and susceptibility `α` |

## Code layout

Everything is in `precision_RHI.m`.

- `default_params` — every number, in one place (Appendix 5.1 of the paper)
- `hypotheses` — the two model matrices (Eqs. 3 and 4)
- `simulate` — one trial: generate the data, then run the agent
- `fig2_…` … `fig8_…` — one function per figure, each starting from
  `default_params` and overriding only what it needs

To change a parameter, edit `default_params`; nothing is buried in a loop.
Free-energy gradients are written out in closed form in `simulate` and are
labelled with the corresponding equation numbers.
