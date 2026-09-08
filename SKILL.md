---
name: macos-trace
description: "Autonomous closed-loop performance optimization engine for macOS applications using xctrace and Xcode Instruments. Handles the full lifecycle: aligning optimization targets with the user, headless diagnostic trace capture, isolating hotspots, implementing code fixes, re-testing with differential A/B verification, and iterating until performance goals are met without manual GUI intervention. Use when the user reports high CPU usage, memory growth or leaks, UI stutter or dropped frames, slow cold launch, audio dropouts, or thermal issues in a macOS application, and asks to profile, benchmark, or optimize it."
compatibility: "macOS 12+, Xcode Command Line Tools, Python 3.8+"
license: MIT
metadata:
  author: kmgcc
  version: "1.3.0"
---

# macOS-Trace: Autonomous Application Performance Optimization

`macOS-Trace` is a closed-loop performance optimization engine for native macOS applications (SwiftUI, AppKit, Metal, CoreAudio, WebKit, native binaries). Its core objective is to eliminate manual Instruments GUI interaction: an agent aligns on targets, captures headless traces, isolates hotspots, applies code fixes, re-tests with differential benchmarking, and iterates until performance targets are verified with empirical data.

---

## Phase 1: User Goal Alignment (Pre-Flight Questionnaire)

Before modifying code or collecting traces, align with the user on optimization targets and success criteria. Use an interactive modal if available (`ask_question`, option lists); otherwise ask directly with structured options.

1. **Primary Optimization Objective**:
   - A: Reduce CPU utilization, power consumption, and thermal throttling.
   - B: Lower memory footprint / transient allocation spikes / eliminate leaks.
   - C: Eliminate UI frame stuttering and dropped frames (Hitches).
   - D: Accelerate cold launch time.

2. **Specific Performance Targets (recommended defaults)**:
   - **CPU / Energy**: idle < 20 M/s instructions, CPU Impact < 0.5; active < 100 M/s (or reduce 30–50%).
   - **Memory**: resident RAM < 150 MB (utilities/audio) / < 300 MB (rich UI); allocation rate < 500 events/sec steady-state; 0 persistent leaks.
   - **UI Smoothness**: hitch ratio < 5.0 ms/s (acceptable), < 1.0 ms/s (fluid/no dropped frames).
   - **Launch Time**: time to first frame < 400 ms (excellent), < 800 ms (acceptable).

3. **Benchmark User Scenario**: ask which specific screen, interaction, or workload to benchmark.

Once targets are confirmed, proceed to Phase 2.

---

## Scope and Prerequisites

- **Target platform**: macOS native desktop apps only (SwiftUI, AppKit, Metal, CoreAudio / AVAudioEngine, WebKit host views, native CLI executables). Does not support iOS simulators, remote mobile devices, or browser-only web apps.
- **Xcode tooling**: macOS 12+, full Xcode or Xcode Command Line Tools (`xcrun xctrace version`).
- **Hardware metrics**: `Power Profiler` and energy impact counters require Apple Silicon (M1/M2/M3/M4).
- **Python**: 3.8+ (standard library only, zero pip dependencies).
- **Process permissions**: debug builds or binaries with `get-task-allow` entitlement are required for `--attach <PID>` under Hardened Runtime.

---

## Rules for Agents

1. **Establish a baseline first**: always capture an idle baseline (app open, workload paused) before the active workload. Compute `Delta = Active - Baseline`.
2. **Verify target state before recording**: confirm the process exists (`pgrep -x <name>`) and the target feature is actively executing during the recording window.
3. **Keep the window in foreground**: macOS throttles rendering/display links for occluded or minimized windows (`NSWindowOcclusionState`) — an occluded window produces falsely low GPU/CPU readings.
4. **Use equal test parameters**: identical durations (default 60s), display scales, window sizes, and input data. Never compare Debug vs Release builds.
5. **Zero third-party Python dependencies**: bundled scripts use the standard library only.
6. **Save outputs to `/tmp/macos-traces/`**: timestamped, scenario-tagged filenames.
7. **Protect context budget**: never dump raw `.trace` bundles, call-trees, or unparsed XML into the conversation — they can be hundreds of MB. Always stream/filter/rank via the bundled scripts before reading.
8. **Focus on primary bottlenecks**: profile first to confirm the dominant contributor; don't scatter micro-optimizations across innocent utilities.
9. **Never silently alter UI, visual effects, or core behavior**: if an optimization affects visual fidelity or essential behavior, formally ask the user first and articulate the exact before/after tradeoff with quantified expected gain.
10. **Clean up recording artifacts**: `run_trace.sh` auto-cleans the several-GB transient kernel traces (`instruments*.ktrace` in `$TMPDIR`). When running `xctrace` directly, clean them yourself before concluding:
    ```bash
    find "${TMPDIR:-/tmp}" -maxdepth 1 -type f -name 'instruments*.ktrace' -delete 2>/dev/null || true
    ```

---

## The 4-Phase Optimization Protocol

### Phase 2: Diagnostic Profiling & Attribution

```bash
APP_NAME="YourApp"
SKILL_DIR="$HOME/.claude/skills/macos-trace"

# Idle baseline (workload paused, window visible)
"$SKILL_DIR/scripts/run_trace.sh" --process "$APP_NAME" --template power --duration 60s --label "01-baseline"

# Active workload (user triggers the scenario in the app while this records)
"$SKILL_DIR/scripts/run_trace.sh" --process "$APP_NAME" --template power --duration 60s --label "02-pre-opt"

# Pre-optimization delta
python3 "$SKILL_DIR/scripts/compare_elements.py" \
  /tmp/macos-traces/01-baseline-power.xml:"Idle Baseline" \
  /tmp/macos-traces/02-pre-opt-power.xml:"Active Pre-Opt"
```

Attribute the bottleneck with specialized templates: `--template time` for hot call-trees, `alloc` with `top_categories.py` for allocation thrashing, `hitches` during scrolling for render vs commit delays, `sys` for lock contention. See `references/templates.md` for the full template reference.

> **If the target workload requires interaction or reproduction** (clicks, scrolling, gestures), **read `references/workload-reproduction.md` before recording** and decide which reproduction tier to use.

### Phase 3: Targeted Code Modification

Apply minimal, surgical fixes based on findings:
- **Real-time audio threads allocating heap memory?** Replace with pre-allocated lock-free ring buffers.
- **WebKit IPC saturated?** Throttle state updates and switch to CSS transform animations.
- **Metal fragment shader overdrawing on Retina?** Add dynamic resolution scaling or pause offscreen render loops.
- **High-resolution image decoding spikes?** Adopt `CGImageSourceCreateThumbnailAtIndex` downsampling.

Rebuild the application.

### Phase 4: Re-Test, Quantitative Review & Decision Gate

```bash
# Post-optimization active workload
"$SKILL_DIR/scripts/run_trace.sh" --process "$APP_NAME" --template power --duration 60s --label "03-post-opt"

# Compare Pre-Opt vs Post-Opt against Baseline
python3 "$SKILL_DIR/scripts/compare_elements.py" \
  /tmp/macos-traces/01-baseline-power.xml:"Idle Baseline" \
  /tmp/macos-traces/02-pre-opt-power.xml:"Active Pre-Opt" \
  /tmp/macos-traces/03-post-opt-power.xml:"Active Post-Opt"
```

Example Decision Output:

```text
Scenario                    Sec  CPU Avg  CPU Max  Display  GPU Avg  Total Instr    Instr M/s
============================================================================================
Idle Baseline                60     0.15     0.80     0.05     0.00        1.02G         17.0
Active Pre-Opt               60     2.40     4.80     1.10     1.50       16.20G        270.0
Active Post-Opt              60     0.65     1.20     0.25     0.10        4.80G         80.0
----------------------------------------------------------------------------------------------
Optimization Delta (Post-Opt vs Pre-Opt):
  Instruction throughput: -70.4% (80.0 vs 270.0 M/s)
  CPU Average Impact:     -72.9% (0.65 vs 2.40)
```

**Decision Gate**: target met → present the comparison table and conclude. Target not met → keep the current optimization, isolate the next hotspot, repeat Phases 3–4.

**Post-Report Cleanup**: after the user accepts the report, delete accumulated `.trace` bundles under `/tmp/macos-traces/` (each can be tens of GB) unless the user asks to keep them.

---

## Direct CLI

You may call `xctrace` directly instead of the bundled scripts. Run `xcrun xctrace record --help` and `xcrun xctrace export --help` for full options. You may also modify the bundled scripts for a specific task — keep the originals intact.

```bash
# Record an attached-process sample
xcrun xctrace record --template 'Time Profiler' --time-limit 60s \
  --output /tmp/macos-traces/run.trace --attach $(pgrep -x YourApp)

# Export the Power Impact table
xcrun xctrace export --input /tmp/macos-traces/power.trace \
  --xpath "/trace-toc/run[@number='1']/data/table[@schema='ProcessSubsystemPowerImpact']" \
  > /tmp/macos-traces/power.xml
```

---

## Reference Documents (load on demand)

- `references/templates.md` — Instruments template picker (which template for which bottleneck).
- `references/subsystems.md` — per-subsystem optimization patterns (audio, Metal, WebKit, UI/memory).
- `references/workload-reproduction.md` — how to reproduce the workload (Tier 0–2), including Accessibility-driven UI automation.
