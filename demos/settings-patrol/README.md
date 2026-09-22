# Settings Patrol

A [FluidUse](https://github.com/FluidInference/FluidUse) demo. Type a vague request ("stop emails
when my CI breaks", "make unsigned commits look suspicious") and laya, a 322M on-device decision
model, narrows GitHub's settings down to the control that does it. The window shows every step of
the decision and opens a local recreation of the settings page with the answer pulsing.

```bash
swift run -c release SettingsPatrol
```

The first launch downloads laya's 128, 512 and 1024-token buckets.

## What's on screen

- **Right:** a local recreation of GitHub's personal-account and organization settings (sidebar,
  sections, danger zones, toggles), rendered from `Resources/github-{user,org}.json`. It is a mock
  for this demo, not GitHub.
- **Left:** the funnel. One column per step, with bars for each option's probability. Blue means
  kept or advanced, faded means eliminated, and green marks the path to the winner. Each column
  header shows the step's laya calls and time.
- **Best matches:** the top five. Click one to open its page, pulse the control, and put halos on
  the other finalists on that page, scaled by probability. Heat bars in the sidebar show page scores.
- Example chips run the built-in ambiguous queries.

## How it decides

1. **Account:** one `choice` between the personal account and the organization. It is used as a
   soft prior (square root), so a wrong guess can't bury the answer.
2. **Settings · heats:** all ~450 settings compete in heats of 7, each described with its
   account, page, section and help text. The top 2 of each heat advance until 7 or fewer remain.
3. **Settings · final:** one `choice` among the survivors.
4. **Pages:** the finalists' scores summed per page.

Why heats instead of one big question: laya packs the question and all options into a 256-token
head, so a 30-option question leaves each option about 7 tokens. With 7 options each keeps about
30 tokens. Designs I tried and dropped:
- **sidebar group → page → setting:** errors cascade from the group step.
- **page tournament → setting:** a wrong page hides the right setting.
- **per-candidate `noul`:** it answered ~99% yes for nearly everything, so it couldn't rank.

## Engines

The segmented control switches the model; the funnel view shows each engine's own steps.

| Engine | How it decides | Setting #1 | Top 3 | Page #1 | Time/query |
|---|---|---|---|---|---|
| laya (on-device) | account prior, then heats of 7, then a final (above) | 3/15 | 6/15 | 7/15 | ~0.7 s, ~90 calls |
| Jev API | one request, three parallel Choices: account, all 220 personal settings, all 236 org settings; score = P(account) × P(setting) | 14/15 | 15/15 | 14/15 | ~0.7 s, 1 request |
| Claude (`claude-opus-5`, effort low) | whole catalog in a cached system prompt; structured output of top 5 ids with confidence and a reason | 14/15 | 15/15 | 14/15 | ~4 s, 1 request |

Keys: `JEV_API_KEY` and `ANTHROPIC_API_KEY`, from the environment or the nearest `.env`. Claude
requests opt into server-side refusal fallbacks (`fallbacks: "default"`).
`PATROL_AUTORUN=1 PATROL_ENGINE=all` runs all three and prints the comparison
(`PATROL_ENGINE=laya|jev|claude` for one).

## Data

`data/*.py` generate the JSON: `user.py`, `org.py` (from `org_a/b/c.py`), `summaries.py` (one
line per page), and `dsl.py`. Wording follows GitHub's settings UI as of 2026, from memory and
docs.github.com. Some sub-pages and sample values are approximations.

```bash
cd data && python3 user.py ../Sources/SettingsPatrol/Resources/github-user.json \
        && python3 org.py ../Sources/SettingsPatrol/Resources/github-org.json
```

## Self-test

`PATROL_AUTORUN=1 swift run SettingsPatrol` runs every example, prints each step's top options,
the top 3 matches (✓ = expected setting) and timings, then quits. Current result:
3/15 exact setting at rank 1, 6/15 in the top 3, 7/15 right page at rank 1, ~0.6 s per query
(~90 laya calls).
