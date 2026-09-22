# Form Ghost

A [FluidUse](https://github.com/FluidInference/FluidUse) demo. It loads a sample form
into an embedded web view, scores every control with the on-device CUA-S1-FORMS model,
and overlays a "ghost" on each field: the value it would enter plus a confidence halo
(green ≥ 85%, amber ≥ 50%, red below, grey for skip/click). Nothing is typed until you ask.

```bash
swift run -c release FormGhost
```

- **Run ghost** (⌘R) snapshots the page and scores each control. The sidebar shows model load,
  snapshot time, per-decision latency (mean/p50/p95/min/max, chart), throughput, and a
  decision breakdown with each control's runner-up option.
- **Fill all** (⌘F) applies every ghost above the threshold; click a ghost's tag or a sidebar
  row to apply just that one. **Reset** clears the form.
- *Scan pacing* slows the scan so you can watch it; pauses are excluded from timings.

## Your information

By default the ghost reads a personal database instead of each form's sample profile:
`~/Library/Application Support/FormGhost/me.json` (override with `FORM_GHOST_DB`). It is created
from `Resources/me.example.json` on first launch — open it from the sidebar, put in your details,
and press **Reload**. It lives outside the repo so your data never gets committed.

```json
{ "key": "phone", "label": "Phone", "value": "(720) 555-0123",
  "aliases": ["Mobile phone", "Primary contact phone number"] }
```

- **Aliases** are the other captions forms use. For each field the host scores every record
  against the field's label, captions each one with its closest alias, and offers only the
  relevant ones, so the model compares near-identical labels and cannot drop a ZIP into
  "Promo code".
- **`{key}` references** compose values: `"{city}, {state} {zip}"`.
- **`"type": "date"`** values are stored `yyyy-mm-dd` and reformatted when the field asks for
  `mm/dd/yyyy` or `dd/mm/yyyy`.
- **Exact-match rule** (blue halo, action `answer`): if the model skips a text field whose label,
  minus parenthesized hints, is exactly one of your captions, it is filled anyway. Toggle it off
  in the sidebar to see the model alone. The sidebar's segmented control switches back to the
  sample profiles for comparison (`FORM_GHOST_SOURCE=sample` in autorun).

Sample forms and their profiles (`Label: value` lines) live in
`Sources/FormGhost/Resources/forms/`: checkout, passport renewal, W-4 withholding, clinic intake.
Add a form by dropping in `name.html` + `name.txt` and listing it in `SampleForm.all`.

Smoke test: `FORM_GHOST_AUTORUN=1 swift run FormGhost` scans and fills every form, prints
stats and each decision, then quits. The model downloads on first launch.
