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

## Three policies

| Policy | Where it runs | Calls per piece |
|---|---|---|
| **laya** | on-device, Neural Engine (~4 ms each) | one per landing |
| **Jev API** | [TypeSafe](https://docs.typesafe.ai/api) `jev-latest` over HTTPS | one request, a Noul per landing |
| **Heuristic** | Dellacherie-style formula, no model | — |

For Jev, put `JEV_API_KEY=…` in the repo's `.env` (git-ignored; the app walks up from the working
directory to find it), export it, or paste a key into the sidebar (kept in memory only).
Each request carries `{"piece", "landings": [sentence…]}` as state and asks
"Is `landings[i]` a clean placement…?" with explicit clean/messy criteria for every landing, so
each judgment sees the alternatives. The sidebar shows round-trip time, tokens, and the model
version; answers arrive together and are revealed in sweep order so the heatmap still animates.
`TETRIS_AUTORUN=1 TETRIS_POLICY=jev` runs the smoke test against the API.

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
