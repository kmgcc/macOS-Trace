# Workload Reproduction (Tier 0–3)

**Read before recording when the target workload requires interaction or
reproduction** (clicks, scrolling, gestures, launch sequences). Decide how the
workload is reproduced, and keep that mechanism identical across the idle
baseline, pre-optimization, and post-optimization runs.

## Selection & Fallback Process

Reproduction is an active decision at the start of every task, not a fixed
workflow. Follow these rules in order:

1. **Prefer automation.** Never default to manual operation when the workload can
   be reproduced automatically. Tier 0 (manual) is the last resort.
2. **Selection priority** (most preferred to last resort):
   1. **Tier 1 (launch args / deep config)** — if the app exposes a launch-argument
      or config entry and you only need steady-state metrics: most deterministic,
      cheapest to repeat.
   2. **Tier 2 (UI automation)** — real clicks/swipes are needed. On macOS this
      includes Accessibility-driven control (System Events, `osascript`, UI
      scripting), which works reliably because the agent and app share the same
      host.
   3. **Tier 0 (manual)** — fallback when nothing above works.
3. **State the choice up front.** Tell the user which tier you are using and why,
   so they can correct or add context.
4. **Switch tier on failure.** If a path fails or produces unusable data (command
   errors, app ignores args, gestures have no effect, results not reproducible),
   do not keep retrying the same path — fall back to the next tier. Switching
   within one task is allowed.
5. **Ask for manual help explicitly.** When no automation works, tell the user
   exactly what to do ("open the X window, scroll for 30s, stop") and why
   automation failed. Never make the user cooperate blindly.
6. **Respect an explicit manual request.** If the user says up front "I'll do it
   myself", use Tier 0 directly — do not attempt automation.
7. **Keep one mechanism for all runs.** Whatever tier you end up with, baseline /
   pre / post must use the same mechanism for comparable results.

## Tier Comparison

| Tier | Mechanism | Interactive? | Measures gesture cost? |
|---|---|---|---|
| 0 | Manual (user triggers the scenario) | ✅ | ✅ |
| 1 | Launch args / config (programmatic) | ❌ | ❌ |
| 2 | UI automation (Accessibility / osascript / UI scripting) | ✅ | ✅ |

## Tier 0 — Manual Triggering (always available)

The agent records while the user performs the scenario by hand (scrolling,
playing, navigating), coordinated over chat ("start recording now, scroll for
30 s, stop"). Use when the app has no automation hooks and no UI-automation
toolchain is set up. Requires a human in the loop; human timing jitter reduces
A/B precision — mitigate with longer, consistent sample windows.

## Tier 1 — Launch Arguments (deterministic, preferred)

Programmatic launch that lands the app in the target state without touch input.
The most deterministic tier, best for A/B benchmarking.

```bash
# Launch with arguments
open -a "YourApp" --args --scenario <name> --flag

# Or launch a binary directly with arguments
/Applications/YourApp.app/Contents/MacOS/YourApp --scenario <name> --flag

# Attach-sampling a running process (launch it first, then record)
xcrun xctrace record --template 'Time Profiler' --time-limit 60s \
  --output /tmp/macos-traces/run.trace --attach $(pgrep -x YourApp)
```

The app must act on the input: read `CommandLine.arguments` (or
`ProcessInfo.processInfo.arguments`) and route to the scenario. A debug-only
`--scenario <name>` hook is the cleanest contract.

**Best for:** steady-state CPU / memory / energy of a specific feature;
unattended multi-iteration loops; reproducible before/after comparisons.

**Limitations:** it is navigation, not interaction — the gesture pipeline is
bypassed, so click/scroll gesture cost cannot be measured. Requires the app to
implement parsing; passing an argument an app ignores produces a false success.

## Tier 2 — UI Automation (interactive, macOS-native)

Because the agent and the app share the same Mac, UI automation on macOS is
straightforward and reliable. Prefer accessibility-driven interaction.

```bash
# Drive the app via System Events (requires Accessibility permission for the host)
osascript -e 'tell application "System Events" to tell process "YourApp" to click button "Play"'

# Read the UI hierarchy to find targets
osascript -e 'tell application "System Events" to tell process "YourApp" to get name of every button of window 1'

# Coordinate clicks / scrolls via cliclick (brew install cliclick)
cliclick c:200,400
cliclick w:500,300
```

**Best for:** gesture-driven features (scroll lists, animations, hitches);
interactive exploration — the agent reads the UI, decides, clicks; flows that
mix launch-argument setup with real gestures.

**Limitations:** requires Accessibility permission for the automation host;
precise coordinates depend on window state and scaling. For precompiled
repeatable suites, XCUITest on macOS is an alternative.

## Common Pitfalls

- Launch arguments reach the process, but the app must actually consume them —
  verify with a log line or a state assertion, or the run silently tests nothing.
- Launch arguments do not simulate clicks; they cannot measure gesture cost. Use
  Tier 2 for gesture-level questions.
- macOS UI automation needs Accessibility permission granted to the automation
  host; without it, `osascript`/System Events calls fail silently or error.
- Never assume a window is visible/occlusion-free: an occluded window produces
  falsely low GPU/CPU readings. Keep the target window in the foreground.
- Keep the scenario fixed across baseline / pre / post runs: same window state,
  same inputs, same duration, same tier combination.
