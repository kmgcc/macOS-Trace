---
name: macos-trace
description: "Autonomous closed-loop performance optimization engine for macOS applications using xctrace and Xcode Instruments. Handles the full lifecycle: aligning optimization targets with the user, headless diagnostic trace capture, isolating hotspots, implementing code fixes, re-testing with differential A/B verification, and iterating until performance goals are met without manual GUI intervention. Use when the user reports high CPU usage, memory growth or leaks, UI stutter or dropped frames, slow cold launch, audio dropouts, or thermal issues in a macOS application, and asks to profile, benchmark, or optimize it."
compatibility: "macOS 12+, Xcode Command Line Tools, Python 3.8+"
license: MIT
metadata:
  author: kmgcc
  version: "1.2.2"
---

# macOS-Trace: Autonomous Application Performance Optimization

`macOS-Trace` is a closed-loop performance optimization engine for native macOS applications (SwiftUI, AppKit, Metal, CoreAudio, WebKit, and native binaries).

The objective is to eliminate manual Instruments GUI interaction. An AI agent can autonomously diagnose, locate bottlenecks, implement code changes, re-test with differential benchmarking, and iterate until performance targets are verified with empirical data.

```text
+-------------------------------------------------------------------------+
|                  The Autonomous Optimization Loop                        |
|                                                                         |
|  1. Goal Alignment ──> 2. Diagnostic Trace ──> 3. Targeted Code Fix     |
|         ^                                                 │             |
|         │                                                 ▼             |
|         └────── Iterate if Target Not Met <── 4. Re-test Verification   |
+-------------------------------------------------------------------------+
```

---

## Phase 1: User Goal Alignment (Pre-Flight Questionnaire)

Before modifying code or collecting traces, the agent must align with the user on optimization targets and success criteria.

### Modal Tool vs Chat Interaction
- **If your agent platform provides an interactive questionnaire/modal tool** (e.g., `ask_question`, input dialogs, or selectable option lists), invoke it to present these choices cleanly to the user.
- **If no modal tool is available**, ask the user directly in the conversation with structured options and concrete recommended values.

### Questions to Ask the User

1. **Primary Optimization Objective**:
   - Option A: Reduce CPU utilization, power consumption, and thermal throttling.
   - Option B: Lower memory footprint, transient allocation spikes, or eliminate leaks.
   - Option C: Eliminate UI frame stuttering and dropped animation frames (Hitches).
   - Option D: Accelerate application cold launch time.
2. **Specific Performance Targets (Provide Recommended Defaults)**:
   - **CPU / Energy Targets**:
     - *Idle Baseline Target*: < 20 M/s instructions, CPU Impact < 0.5.
     - *Active Workload Target*: < 100 M/s instructions (or specify: reduce by 30% - 50%).
   - **Memory Targets**:
     - *Maximum Resident RAM*: Cap at < 150 MB (utilities/audio) or < 300 MB (media/rich UI).
     - *Allocation Event Rate*: < 500 events/sec during steady-state execution.
     - *Memory Leaks*: Exactly 0 persistent leaks.
   - **UI Smoothness Targets**:
     - *Hitch Ratio*: < 5.0 ms/s (acceptable), < 1.0 ms/s (fluid/no dropped frames).
   - **Launch Time Targets**:
     - *Time to First Frame*: < 400 ms (excellent), < 800 ms (acceptable).
3. **Benchmark User Scenario**:
   - Ask the user which specific screen, user interaction, or workload to benchmark.

Once targets are confirmed, proceed to Phase 2.

---

## Scope and Prerequisites

- **Target platform**: macOS native desktop applications only (SwiftUI, AppKit, Metal, CoreAudio / AVAudioEngine, WebKit host views, native CLI executables). Does not support iOS simulators, remote mobile devices, or external browser-only web apps.
- **Xcode tooling**: Requires macOS 12+ and full Xcode or Xcode Command Line Tools (`xcode-select -p`, `xcrun xctrace version`).
- **Python**: Python 3.8+ (pre-installed on macOS; zero external pip dependencies).
- **Process permissions**: Debug builds or binaries with `get-task-allow` entitlement are required for `--attach <PID>` under Hardened Runtime.

---

## Rules for Agents

Follow these non-negotiable rules during automated profiling:

1. **Establish a baseline first**: Never record only the active workload. Always capture an idle baseline (app open in foreground, workload paused) before recording the active state. Compute: `Delta = Active - Baseline`.
2. **Verify target state before recording**: Check that the process exists using `pgrep -x <ProcessName>` and that the target feature is actively executing during the recording window.
3. **Keep the window in foreground**: macOS throttles rendering and display links for occluded or minimized windows (`NSWindowOcclusionState`). An occluded window will produce falsely low GPU and CPU readings.
4. **Use equal test parameters**: Compare runs with identical sample durations (default: `60s`), identical display scales, identical window sizes, and identical test input data. Never compare a Debug build against a Release build.
5. **No third-party Python dependencies**: All bundled scripts (`scripts/compare_elements.py`, `scripts/parse_power.py`, `scripts/top_categories.py`) use the Python 3 standard library only. Do not install pip packages.
6. **Save outputs to `/tmp/macos-traces/`**: Store all `.trace` bundles and `.xml` exports in `/tmp/macos-traces/` with timestamped and scenario-tagged filenames.
7. **Protect conversation context budget**: Trace files and raw exported XML documents can be tens or hundreds of megabytes. Never dump raw `.trace` outputs, full call-trees, or unparsed Allocations XML into the agent conversation context. Always use the bundled Python scripts to stream, filter, rank, and summarize the data before reading.
8. **Focus on primary bottlenecks**: Do not scatter micro-optimizations across dozens of innocent utility functions. Profile first to confirm the dominant contributor (e.g. redundant surface instances, high-frequency timer re-evaluations, unbuffered I/O) and focus optimization efforts exclusively on that root cause.
9. **Never silently alter UI, visual effects, or core behavior**: If a performance bottleneck involves visual fidelity (such as blur/glass materials, frame animations, shadows, layout transitions) or essential software behavior:
   - **Do not unilaterally remove or downgrade the visual feature.**
   - **Formally ask the user for permission first** (using an interactive prompt or explicit chat message).
   - **Clearly articulate the tradeoff**: Describe the visual change before and after, explain why the feature consumes resources, and present the concrete expected performance gain (e.g., "Disabling dynamic background blur will reduce active GPU impact from 1.5 to 0.2 and save ~50 M/s CPU instructions").
10. **Clean up recording artifacts**: Every `xctrace` recording writes several-GB transient kernel traces (`instruments*.ktrace`) and an Instruments CLI cache (`C/com.apple.dt.InstrumentsCLI`) into the per-user system temp folder (`$TMPDIR`). `scripts/run_trace.sh` removes them automatically on exit (both on success and failure). When running `xctrace` directly, clean them yourself before concluding:
    ```bash
    find "${TMPDIR:-/tmp}" -maxdepth 1 -type f -name 'instruments*.ktrace' -delete 2>/dev/null || true
    ```
    Never finish a session leaving hundreds of GB of transient recording data behind.

---

## The 4-Phase Optimization Protocol

### Phase 2: Diagnostic Profiling & Attribution

Before writing code, measure the current state and isolate the root cause:

```bash
# 1. Pre-flight check: the app must be running with its window visible
APP_NAME="YourApp"
pgrep -x "$APP_NAME" || { echo "[ERROR] $APP_NAME is not running. Launch it first."; exit 1; }

# SKILL_DIR = this skill's installed directory (adjust if installed elsewhere)
SKILL_DIR="$HOME/.claude/skills/macos-trace"

# 2. Record 60s idle baseline (workload paused, window visible)
# run_trace.sh resolves the process name to a PID itself
"$SKILL_DIR/scripts/run_trace.sh" --process "$APP_NAME" --template power --duration 60s --label "01-baseline"

# 3. Trigger workload in app, record active state
"$SKILL_DIR/scripts/run_trace.sh" --process "$APP_NAME" --template power --duration 60s --label "02-pre-opt"

# 4. Compute pre-optimization delta
python3 "$SKILL_DIR/scripts/compare_elements.py" \
  /tmp/macos-traces/01-baseline-power.xml:"Idle Baseline" \
  /tmp/macos-traces/02-pre-opt-power.xml:"Active Pre-Opt"
```

Use the specialized templates to attribute the bottleneck:
- Run `--template time` to isolate hot call-tree functions.
- Run `--template alloc` with `scripts/top_categories.py` to identify thrashing allocations.
- Run `--template hitches` during scrolling to isolate render vs commit delays.

### Phase 3: Targeted Code Modification

Apply minimal, surgical fixes based on findings:
- Real-time audio threads allocating heap memory? Replace with pre-allocated lock-free ring buffers.
- WebKit IPC saturated? Throttle state updates and switch to CSS transform animations.
- Metal fragment shader overdrawing on Retina? Add dynamic resolution scaling or pause offscreen render loops.
- High-resolution image decoding spikes? Adopt `CGImageSourceCreateThumbnailAtIndex` downsampling.

Rebuild the application.

### Phase 4: Re-Test, Quantitative Review & Decision Gate

Rerun the profile under identical conditions and evaluate the delta:

```bash
# 1. Record post-optimization active workload
"$SKILL_DIR/scripts/run_trace.sh" --process "$APP_NAME" --template power --duration 60s --label "03-post-opt"

# 2. Compare Pre-Opt vs Post-Opt against Baseline
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
--------------------------------------------------------------------------------------------
Differential vs Baseline [Idle Baseline]:
  Active Pre-Opt               +253.0 M/s instructions, CPU Avg Delta +2.25
  Active Post-Opt               +63.0 M/s instructions, CPU Avg Delta +0.50
```

#### Decision Gate:
- **If target met** (e.g. instruction rate dropped from 270 M/s to 80 M/s, satisfying the < 100 M/s goal): Present the before/after empirical report to the user and conclude.
- **If target not met**: Isolate the remaining bottleneck and begin the next iteration cycle.

**Post-Report Cleanup**: After the user accepts the final optimization report, delete the accumulated `.trace` bundles under `/tmp/macos-traces/` (each can be tens of GB) unless the user explicitly asks to keep them. The finalized comparison table and `.xml` exports shown in the report are sufficient evidence.

---

## Direct CLI Reference

```bash
# Attach to running process
xcrun xctrace record \
  --template 'Power Profiler' \
  --time-limit 60s \
  --output /tmp/macos-traces/power.trace \
  --attach $PID

# Export Power Impact table (instructions, CPU, GPU, display)
xcrun xctrace export \
  --input /tmp/macos-traces/power.trace \
  --xpath "/trace-toc/run[@number='1']/data/table[@schema='ProcessSubsystemPowerImpact']" \
  > /tmp/macos-traces/power.xml

# Export Allocations summary table
xcrun xctrace export \
  --input /tmp/macos-traces/alloc.trace \
  --xpath "/trace-toc/run[@number='1']/data/table[@schema='all-allocations-summary']" \
  > /tmp/macos-traces/alloc.xml
```

---

## Template Reference

Instruments templates supported by `scripts/run_trace.sh` and headless `xctrace`:

### Compute & Energy
| Template | Short Name | Target Metrics & Export Schema | Use Case |
| :--- | :--- | :--- | :--- |
| `Power Profiler` | `power` | Instructions/sec (M/s), CPU/GPU/Display energy impacts (`ProcessSubsystemPowerImpact`). | Objective A/B benchmarking and power efficiency testing. |
| `Time Profiler` | `time` | CPU sample weights by thread, call-tree hotspots, main-thread blocking methods. | High CPU utilization, runaway threads, and hot function paths. |
| `CPU Counters` | `counters` | IPC (instructions per cycle), L1/L2 cache misses, branch mispredictions. | Low-level computational and DSP algorithm performance bottlenecks. |

### UI Responsiveness & Smoothness
| Template | Short Name | Target Metrics & Export Schema | Use Case |
| :--- | :--- | :--- | :--- |
| `Animation Hitches` | `hitches` | Hitch duration (ms), hitch ratio (ms/s), frame drops, app vs render phase latency. | Scrolling stutter, dropped animation frames, and CoreAnimation commit delays. |
| `SwiftUI` | `swiftui` | View body evaluations, State invalidation counts, view update frequency. | Unnecessary view re-evaluations and state invalidation cascades. |
| `Metal System Trace` | `metal` | GPU encoder time, vertex/fragment shader durations, frame boundary latency. | Shader execution bottlenecks, particle FX overhead, and render pipeline stalls. |

### Memory & Allocations
| Template | Short Name | Target Metrics & Export Schema | Use Case |
| :--- | :--- | :--- | :--- |
| `Allocations` | `alloc` | Heap allocations, transient vs persistent memory, category event rates (`all-allocations-summary`). | High-frequency temporary allocations, memory spikes, and buffer thrashing. |
| `Leaks` | `leaks` | Retained memory leaks that outlive parent lifecycle, reference cycles. | Abandoned memory, closure capture leaks, and unreleased delegate cycles. |

### Startup & Concurrency
| Template | Short Name | Target Metrics & Export Schema | Use Case |
| :--- | :--- | :--- | :--- |
| `App Launch` | `launch` | Time to first frame, `dyld` loading time, static initializers, runloop setup. | Cold start optimization (`--launch -- <binary_path>`). |
| `Swift Concurrency` | `concurrency` | Swift Tasks (created/running/suspended), Actor reentrancy, cooperative pool usage. | `async/await` starvation, actor contention, and long-suspended tasks. |
| `System Trace` | `sys` | Thread state transitions (Running, Blocked on mutex, Waiting, Preempted), syscalls. | Low CPU usage but frozen/unresponsive UI (lock contention or I/O waits). |

### I/O & Audio
| Template | Short Name | Target Metrics & Export Schema | Use Case |
| :--- | :--- | :--- | :--- |
| `File Activity` | `files` / `io` | File open/read/write/close calls, I/O latency, throughput. | Disk I/O bottlenecks, database (SwiftData/SQLite) stalls, and asset loading. |
| `Audio System Trace` | `audio` | CoreAudio HAL IO thread jitter, audio buffer overruns/underruns (XRuns/glitches). | Audio dropouts, buffer underruns, and real-time audio pipeline instability. |

---

## Subsystem Optimization Notes

### Real-Time Audio & DSP (CoreAudio / AVAudioEngine)
- **Zero heap allocation**: Code inside `AURenderCallback` or `AVAudioNodeTap` must not allocate heap memory (`malloc`, Swift `Array` reallocations, object creation) or acquire blocking locks (`os_unfair_lock` or mutexes that can priority-invert).
- **Buffer dispatch**: Copy audio data into a pre-allocated lock-free ring buffer. Push to background queues for FFT or level calculations.
- **UI meter throttling**: Throttle UI updates (e.g., visualizers, waveform views) to 30Hz or 60Hz. Never post UI updates on every audio buffer arrival.
- **Diagnosis**: Use `Allocations`. If allocation rate exceeds 500 events/sec during audio playback, inspect audio tap closures using `scripts/top_categories.py`.

### Metal & Visual FX
- **Retina pixel fill rate**: High-DPI screens render at 2x or 3x scale. A fullscreen fragment shader on a 4K display shades over 16 million pixels per frame. If GPU impact is elevated, render to an offscreen half-resolution texture before compositing, or reduce sample counts.
- **Window occlusion**: Observe `NSWindow.occlusionState`. When `contains(.visible)` is false (window minimized or covered), pause `CVDisplayLink` or set `isPaused = true` on `MTKView`.
- **Diagnosis**: Use `Power Profiler` (`GPU Impact` column) and `Metal System Trace`.

### WebKit & Hybrid Views
- **IPC message rate**: Calling `evaluateJavaScript` with large JSON payloads at high frequency saturates WebKit IPC and spikes CPU. Send sparse synchronization anchors (e.g., 1Hz) and let JavaScript interpolate smooth movement using `requestAnimationFrame`.
- **DOM layout thrashing**: Continuously changing properties like `top`, `margin`, or `height` in dynamic scroll or text views forces browser layout recalculation. Use CSS `transform: translateY()` or `opacity` instead.
- **Diagnosis**: Use `Time Profiler` and search for `WebCore::RenderLayer` or IPC serialization symbols.

### UI & Memory Management
- **Image downsampling**: Decoding high-resolution image assets (e.g., 3000x3000px or larger raw bitmaps) directly into `NSImage` allocates ~36MB of uncompressed bitmap memory per image. Downsample at decode time using `CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceThumbnailMaxPixelSize`.
- **SwiftUI body invalidation**: Root-level state changes trigger re-evaluation of downstream view bodies. Use `Time Profiler` to inspect repeated `View.body.getter` calls.
- **Diagnosis**: Use `Allocations` with `scripts/top_categories.py` to identify large transient buffer spikes.

---

## Script Usage

### `scripts/run_trace.sh`
```bash
./scripts/run_trace.sh [options]
  -p, --process <name|pid>    Target process name or PID
  -l, --launch <binary_path>  Launch binary directly
  -t, --template <name>       power (default) | time | alloc | leaks | metal | hitches | swiftui | concurrency | launch | files | sys | audio | counters
  -d, --duration <time>       Duration (default: 60s)
  -o, --output-dir <path>     Output directory (default: /tmp/macos-traces)
  --label <text>              Run label
  --no-analyze                Skip automatic XML export and Python analysis
```

### `scripts/compare_elements.py`
```bash
python3 scripts/compare_elements.py <file1:label1> <file2:label2> [...]
```

### `scripts/parse_power.py`
```bash
python3 scripts/parse_power.py <path_to_xml> [label]
```

### `scripts/top_categories.py`
```bash
python3 scripts/top_categories.py <path_to_xml> <duration_sec> [min_rate]
```
