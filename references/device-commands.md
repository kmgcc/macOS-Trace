# Command Reference (macOS)

Load this file when profiling a macOS app and you need the exact process /
launch / export invocation, or when the target process is not behaving as
expected. It captures real pitfalls so you do not have to re-discover them by
trial and error.

## Hardware & Template Compatibility

- **`Power Profiler` requires Apple Silicon** (M1/M2/M3/M4). On Intel Macs the
  energy counters are unavailable; use `--template time` (hot call-trees) +
  `--template activity` (per-process CPU ms/s) instead.
- `Time Profiler` / `Activity Monitor` / `Allocations` work on all hardware.

Interpretation: Time Profiler gives **attribution** (hot functions, which thread),
Activity Monitor gives **magnitude** (CPU ms/s; 1000 ms/s ≈ one full core).

## Attaching to the Correct Process

Prefer `--process <name>` (attach) for an already-running app, or
`--launch <binary_path>` for a cold start.

```bash
# Attach by name (resolves PID via pgrep)
"$SKILL_DIR/scripts/run_trace.sh" --process MyApp --template time --duration 60s

# Attach to the latest PID when multiple instances match
pgrep -x MyApp          # exact process name
pgrep -f MyApp          # full command line match (fallback)
```

If multiple processes match a name, `run_trace.sh` attaches to the latest PID
and prints a warning — verify you captured the right instance.

## Launching With Arguments (Tier 1 reproduction)

```bash
# Launch a binary directly with arguments (deterministic, no clicking)
/Applications/MyApp.app/Contents/MacOS/MyApp --scenario myState --flag
# ...then attach-sample it:
"$SKILL_DIR/scripts/run_trace.sh" --process MyApp --template time --duration 60s

# Or one-shot cold launch under the profiler
xcrun xctrace record --template 'Time Profiler' --time-limit 60s \
  --output /tmp/macos-traces/run.trace \
  --launch -- /path/to/MyApp.app/Contents/MacOS/MyApp --scenario myState
```

## Window State Matters

macOS throttles rendering for occluded or minimized windows
(`NSWindowOcclusionState`) — an occluded window produces falsely low GPU/CPU
readings. Keep the target window in the foreground during recordings.

## Accessibility-Driven UI Automation (Tier 2)

macOS UI automation works via Accessibility (System Events / osascript), because
the agent and the app share the same host:

```bash
osascript -e 'tell application "System Events" to tell process "MyApp" to click button "Play"'
osascript -e 'tell application "System Events" to tell process "MyApp" to get name of every button of window 1'
```

Requires **Accessibility permission** for the automation host; without it these
calls fail silently or error. See `references/workload-reproduction.md` for the
full Tier 0–2 selection logic.

## Adapting Scripts (allowed, with rules)

The bundled scripts are meant to be adapted for specific tasks. Rules:

1. **Never edit files inside the skill directory** (`SKILL_DIR/scripts/…`).
2. **Copy to a temp directory first, then modify the copy**:
   ```bash
   mkdir -p /tmp/my-trace-tools
   cp "$SKILL_DIR"/scripts/*.py /tmp/my-trace-tools/
   # edit /tmp/my-trace-tools/top_time.py, then run:
   python3 /tmp/my-trace-tools/top_time.py ...
   ```
3. Keep the original scripts untouched so every user/run sees the same baseline.
