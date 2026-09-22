# jev-tests

Three small macOS demos that try out typed decision models: models that return probabilities
for yes/no, multiple-choice and rating questions instead of generating text. They compare four
backends:

- **[FluidUse](https://github.com/FluidInference/FluidUse)**: on-device models on the Apple
  Neural Engine. CUA-S1-FORMS (706K parameters) for form filling, laya (322M) for general
  typed questions.
- **[Jev](https://docs.typesafe.ai/api)**: TypeSafe's hosted System One model.
- **[Kev](https://github.com/jaredpalmer/kev)**: open Jev-like models served locally with the
  same API.
- **Claude** (`claude-opus-5`), in one demo, as a general-model baseline.

Each demo is a SwiftPM app in `demos/` with its own README. Every demo has a headless
self-test that prints its numbers.

| Demo | What it shows |
|---|---|
| [`demos/form-ghost`](demos/form-ghost) | Loads a sample form (checkout, passport renewal, W-4, clinic intake) and overlays what CUA-S1-FORMS would type into each field, with confidence halos, timings, and a personal database of your details. |
| [`demos/tetris-heatmap`](demos/tetris-heatmap) | laya, Kev and Jev play Tetris side by side on one seed. Every landing is scored with "Is this a clean placement?", drawn as a heatmap, and every model call can be inspected. |
| [`demos/settings-patrol`](demos/settings-patrol) | A local recreation of GitHub's user and org settings. Type a vague request ("stop emails when my CI breaks") and laya, Jev or Claude narrows it down to the exact setting, showing each step. |

## Requirements

- An Apple silicon Mac on macOS 14 or later, with Swift 6.
- The first run downloads the FluidUse Core ML models from Hugging Face.
- Keys go in a `.env` at the repo root (git-ignored) or the environment:
  - `JEV_API_KEY` for Jev, in the Tetris and Settings Patrol demos.
  - `ANTHROPIC_API_KEY` for the Claude engine in Settings Patrol.
- For the Kev column in Tetris: [uv](https://docs.astral.sh/uv/) and about 23 GB of memory for
  Kev-4B. Start it with `demos/tetris-heatmap/scripts/kev-server.sh`.

```bash
cd demos/tetris-heatmap && swift run -c release TetrisHeatmap
```

## What we found

All numbers are from one M5 Max Mac. They are small samples (30 Tetris pieces,
15 settings queries), so treat them as anecdotes rather than benchmarks.

**Form filling.** CUA-S1-FORMS takes about 2 ms per field. From each form's sample profile it
got most names, addresses and contact fields, skipped many fields whose labels didn't match,
and was confidently wrong now and then (a ZIP code into "Promo code" at 99.9%). A personal
database raised the fields filled per form from 9/12/4/7 to 13/18/6/10, mostly by matching
field labels in code before asking the model.

**Tetris** (30 pieces, same seed):

| | laya (on-device) | Kev-4B (local) | Jev (API) |
|---|---|---|---|
| Time per piece | ~90 ms (≈22 calls of 4 ms) | ~855 ms | ~400 ms |
| Lines cleared | 8 | 3 | 1–5 across runs |
| Memory | ~0.4 GB (whole app) | ~23 GB | — |
| Cost | $0 | $0 | ≈ $0.0037 per 30 pieces |

No model sees the board. Code computes each landing's features and describes it in one
sentence; the model judges the sentence. This is a latency demo, not a good Tetris player.
Kev-0.8B was also tried: 5.6–8.7 GB of memory but slower (2.5 s per piece) and much worse
(0 lines).

**Settings search** (15 vague queries against ~450 GitHub settings):

| Engine | Right setting ranked #1 | In top 3 | Time per query |
|---|---|---|---|
| laya (on-device) | 3/15 | 6/15 | ~0.7 s (~90 calls) |
| Jev | 14/15 | 15/15 | ~0.7 s (1 request) |
| Claude (`claude-opus-5`, low effort) | 14/15 | 15/15 | ~4 s (1 request) |

laya fits a question and all its options into 256 tokens, so it can only compare a few
settings at a time. Jev takes up to 255 options per question and sees every setting at once.

## Notes

- The GitHub settings pages are a local mock written from memory of GitHub's UI, not scraped
  from GitHub.
- `demos/tetris-heatmap/Sources/TetrisHeatmap/TetrisSimulation.swift` is vendored from
  FluidUse (Apache-2.0).
- Personal data in the demos is fictional (`example.invalid` addresses, `000-…` SSNs).
