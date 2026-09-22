# Tetris Heatmap

A [FluidUse](https://github.com/FluidInference/FluidUse) demo. For every piece, laya — a
322M on-device decision model — scores every legal landing with *"Is this a clean placement?"*
and the board lights up as a heatmap of its answers before the piece drops.

```bash
swift run -c release TetrisHeatmap
```

- **Board:** each empty cell is colored by the hottest landing that would cover it.
  Orange outline = landing being scored, green = the chosen one.
- **Decision matrix:** rotation × column grid of P(clean) for the current piece.
- **Top landings:** the five best, with the exact sentence laya was shown.
- **Sidebar:** pieces, lines, holes, how often laya agrees with the Dellacherie heuristic,
  and laya timing (load, mean/p50/p95, throughput, per-piece cost, latency trace).
- Space plays/pauses, **S** steps one piece, the segmented control swaps in the heuristic
  policy for comparison, and the pacing sliders slow things down (pauses aren't timed).

## Three columns

laya, Kev and Jev play the same seed in lockstep: laya history | laya | Kev | Kev history | Jev | Jev history.

| Column | Where it runs | Calls per piece | Measured here (M-series Mac, 30 pieces) |
|---|---|---|---|
| **laya** | on-device, Neural Engine | one per landing | ~4 ms per call, ~90–150 ms per piece |
| **Kev** ([jaredpalmer/kev](https://github.com/jaredpalmer/kev)) | local Python server on the Mac GPU (MPS) | one request, a Noul per landing | ~850 ms mean per piece, ~1.6 s p95 |
| **Jev API** | [TypeSafe](https://docs.typesafe.ai/api) `jev-latest` over HTTPS | one request, a Noul per landing | ~400 ms mean round trip, ≈ $0.00012 per piece |

Kev serves the same `/v1/systemone` API as Jev, so both use one client. Start it first:

```bash
scripts/kev-server.sh     # clones Kev to ~/.cache/kev, uv sync, serves Kev-4B (Qwen3) on 127.0.0.1:8009
```

The first run downloads about 8 GB. `KEV_RUN=jaredpalmer/kev-4b` picks the newer Qwen3.5 generation,
which the Kev README measures as ~4× slower on Apple Silicon. `KEV_URL` points the app elsewhere. If
no server answers, the Kev column says so and the other two keep playing.

For Jev, put `JEV_API_KEY=…` in the repo's `.env` (git-ignored; the app walks up from the working
directory to find it), export it, or paste a key into the toolbar (kept in memory only).
Each request carries `{"piece", "landings": [sentence…]}` as state and asks
"Is `landings[i]` a clean placement…?" with explicit clean/messy criteria for every landing, so
each judgment sees the alternatives. `TETRIS_AUTORUN=1` plays 30 pieces in all three columns and
prints a summary per column.

Colors are relative per piece: laya's raw P(clean) sits in a narrow band (about 5–45%),
so the ramp is stretched to that piece's min–max; the legend shows the actual range.

Smoke test: `TETRIS_AUTORUN=1 swift run TetrisHeatmap` plays 30 pieces unpaced, prints each
pick and a summary, then quits. The first launch downloads laya's 128-token bucket.

`TetrisSimulation.swift` is vendored from FluidUse (Apache-2.0) because its `LayaTetris`
target is not exported as a library product.

## Inspecting model calls

Click any decision matrix (the live one under a board once the piece is decided, or any entry in
the history sidebars) to open the call inspector. Click a landing to focus its call.

- **laya:** the Swift call, the exact sequence the encoder sees
  (`[CLS] noul question: … [SEP] [MASK] false: … [MASK] true: … [SEP] <state> [SEP]`), token count,
  bucket, truncation, latency, token ids on demand, and the per-option logits, raw and calibrated
  probabilities. One call per landing.
- **Jev:** that landing's question and state entry, its answer, the HTTP line and headers (key
  masked), and the full request and response bodies byte-for-byte with copy buttons. One request
  per piece.
