---
name: macos-trace
description: Profile macOS applications headlessly using xctrace and Xcode Instruments. Use when asked to profile performance, measure CPU/GPU/display energy impact, locate thermal throttling or battery drain, investigate UI hitching/hangs, diagnose memory leaks/spikes, optimize audio/DSP taps, Metal shaders, or WebKit hybrid views, or perform objective A/B benchmarking between optimizations.
compatibility: macOS 12+, Xcode Command Line Tools (xctrace), Python 3.8+ (zero external pip packages required)
license: MIT
metadata:
  author: kmgcc
  version: "1.0.0"
---

# macOS-Trace: Headless Performance & Memory Profiling

A standardized, automation-first profiling skill for macOS applications (SwiftUI, AppKit, Metal, CoreAudio / AVAudioEngine, WebKit, and native executables).

This skill enables AI coding agents and engineers to autonomously capture Instruments traces headlessly, extract tabular data via `xctrace export`, and compute objective differential (A/B) performance metrics without manual GUI interaction.

---

## 1. Core Guardrails (Rules for Agents)

When an AI agent performs performance profiling or optimization verification, the following rules are **strictly mandatory**:

1. **Always Establish an Idle Baseline First (Differential A/B Rule)**:
   - Absolute figures (e.g. "120 M/s instructions" or "450 MB RAM") are meaningless without a reference point.
   - Always record an **Idle / Baseline run** first (app running with window in foreground, but workload paused/inactive).
   - The true cost of a feature or optimization is always: `Delta = Workload_Metric - Baseline_Metric`.
2. **Never Profile Blindly (Verify Liveness & Real Workload)**:
   - Verify the target process exists and obtain its PID using `pgrep -x <ProcessName>`.
   - Ensure the app is actually performing the target workload during recording (e.g., audio playing, animation running, scrolling active).
   - Note: macOS aggressively throttles occluded or minimized windows (`NSWindowOcclusionState`). Keep the window visible in the foreground to prevent artificially low readings.
3. **Control Environmental Variables**:
   - Use identical recording durations across comparative runs (standardize on `60s` for standard runs, `30s` for rapid smoke checks, `120s` for thermal/power runs).
   - Ensure identical window sizes, display Retina scale factors, and test media/data.
   - Verify build configuration: do not compare a Debug build against a Release build.
4. **Zero External Python Dependencies**:
   - All bundled analysis scripts (`scripts/compare_elements.py`, `scripts/parse_power.py`, `scripts/top_categories.py`) use the **Python 3.8+ standard library only**.
   - Do not install third-party pip packages; the workflow runs cleanly out-of-the-box in any standard shell or sandbox.
5. **Safe Output Staging**:
   - Save all trace packages and exported XMLs to `/tmp/macos-traces/` using timestamped and scenario-tagged filenames.

---

## 2. Fast-Track Execution Workflow

### Step 1: Pre-Flight Check

```bash
# 1. Verify xctrace availability
xcrun xctrace version

# 2. Prepare scratch directory
mkdir -p /tmp/macos-traces

# 3. Locate target process PID
APP_NAME="kmgccc_player" # Replace with target process name
PID=$(pgrep -x "$APP_NAME")
echo "Target PID: $PID"
```

### Step 2: Automated Profiling & Analysis (All-in-One Runner)

The bundled runner `scripts/run_trace.sh` records the trace, exports the relevant XML table, and invokes the Python analysis script in a single command:

```bash
# Profile Power Profiler (CPU instructions, Display, GPU impact) for 60s:
./scripts/run_trace.sh --process "$APP_NAME" --template power --duration 60s --label "01-baseline-idle"

# Trigger target feature in the app, then record active scenario:
./scripts/run_trace.sh --process "$APP_NAME" --template power --duration 60s --label "02-active-workload"
```

### Step 3: Compare Scenarios (Differential Delta Analysis)

Feed the exported XML files into `scripts/compare_elements.py` (the first file is treated as the Baseline):

```bash
python3 scripts/compare_elements.py \
  /tmp/macos-traces/01-baseline-idle-power.xml:"1. Idle Baseline" \
  /tmp/macos-traces/02-active-workload-power.xml:"2. Active Workload"
```

Output example:
```
Scenario                    Sec  CPU Avg  CPU Max  Display  GPU Avg  Total Instr    Instr M/s
============================================================================================
1. Idle Baseline             60     0.15     0.80     0.05     0.00        1.02G         17.0
2. Active Workload           60     1.85     3.40     0.90     1.20       12.60G        210.0
--------------------------------------------------------------------------------------------
Differential vs Baseline [1. Idle Baseline]:
  2. Active Workload           +193.0 M/s instructions, CPU Avg Δ +1.70
```

---

## 3. Direct Headless CLI Commands (Manual Fallback)

If running without `run_trace.sh`, use the official headless toolchain directly:

### 1. Record Trace via `xcrun xctrace record`

```bash
# Attach to running process (Recommended: preserves app state and active window)
xcrun xctrace record \
  --template 'Power Profiler' \
  --time-limit 60s \
  --output /tmp/macos-traces/run.trace \
  --attach $PID

# Alternatively, cold-launch executable binary:
xcrun xctrace record \
  --template 'Time Profiler' \
  --time-limit 30s \
  --output /tmp/macos-traces/launch.trace \
  --launch -- /path/to/YourApp.app/Contents/MacOS/YourApp
```

### 2. Export Structured Data via `xcrun xctrace export`

```bash
# Export Power Impact table (CPU instructions, energy, GPU, Display)
xcrun xctrace export \
  --input /tmp/macos-traces/run.trace \
  --xpath "/trace-toc/run[@number='1']/data/table[@schema='ProcessSubsystemPowerImpact']" \
  > /tmp/macos-traces/run-power.xml

# Export Allocations summary table (heap allocation categories, count, bytes)
xcrun xctrace export \
  --input /tmp/macos-traces/run.trace \
  --xpath "/trace-toc/run[@number='1']/data/table[@schema='all-allocations-summary']" \
  > /tmp/macos-traces/run-alloc.xml
```

---

## 4. Template Selection Matrix

| Objective | Instruments Template | Key Metrics & Data Schema |
| :--- | :--- | :--- |
| **CPU Instruction Rate & Energy Impact** | `Power Profiler` | Instructions/sec (M/s), CPU/GPU/Display energy impacts (`ProcessSubsystemPowerImpact`). Best for A/B testing. |
| **Call Stack Hotspots & UI Hangs** | `Time Profiler` | Thread sample weights, hot call frames, main-thread blocking methods. |
| **Memory Spikes & Heap Allocation Rates** | `Allocations` | Transient vs persistent bytes, allocation event rate by category (`all-allocations-summary`). |
| **Retained Leaks & Abandoned Memory** | `Leaks` | Object allocation stack traces for leaks that persist beyond their lifecycle. |
| **Shader Performance & GPU Rendering** | `Metal System Trace` | GPU frame time, encoder bottlenecks, vertex/fragment shader execution duration. |

---

## 5. Subsystem Optimization Playbooks & Real-World Recipes

### Recipe A: Real-Time Audio & DSP Pipelines (CoreAudio / AVAudioEngine)
- **Zero Heap Allocation Rule**: Real-time audio threads (`AURenderCallback` or `AVAudioNodeTap`) must **never** allocate heap memory (`malloc`, Swift `Array` resizing, object creation) or acquire blocking locks.
- **Spectrum & FFT Throttling**:
  - Buffer audio in a pre-allocated lock-free Ring Buffer.
  - Compute FFT and push UI meter updates on a background timer at 30Hz or 60Hz. Never post UI notifications on every single incoming audio buffer!
- **Verification**: Run `Allocations` on active playback. If allocation rate exceeds 1,000 events/sec, inspect audio tap callbacks using `scripts/top_categories.py`.

### Recipe B: Metal Shaders, Particle FX & Dynamic Backgrounds
- **Retina Overdraw Trap**: High-DPI screens render at 2x or 3x scale. A fullscreen fragment shader (e.g. procedural blur, bokeh, raymarching) on a 4K display must shade over 16 million pixels per frame.
  - Implement dynamic resolution scaling or render to an offscreen half-resolution texture before compositing.
- **Window Occlusion Handling**:
  - Check `NSWindow.occlusionState.contains(.visible)`. When the window is minimized or fully covered by other applications, suspend `CVDisplayLink` or pause the `MTKView` render loop.
- **Verification**: Run `Power Profiler` and check `GPU Impact` and `Display Impact`.

### Recipe C: WebKit & Hybrid WebView Architectures (AMLL / WKWebView / Electron)
- **IPC Message Saturation**: Pushing high-frequency state updates (e.g. playback progress every 10ms) from Swift to JavaScript via `evaluateJavaScript` incurs heavy JSON serialization and cross-process IPC costs.
  - Push anchor timestamps at lower frequencies (e.g. 1Hz) and let JavaScript drive continuous smooth animations using `requestAnimationFrame`.
- **DOM Reflow Under Continuous Scroll**: Ensure smooth karaoke/lyric highlights use CSS `transform: translateY()` or `opacity` rather than animating `top`, `margin`, or `height` which trigger layout recalculations.
- **Verification**: Run `Time Profiler` to detect IPC serialization hotspots in `WebCore` and `WKWebView`.

### Recipe D: Desktop UI, Image Loading & SwiftData / CoreData
- **Sawtooth Memory Spikes**: Decoding large raw images (e.g. 3000x3000px album covers or artwork) directly into `NSImage` allocates ~36MB of uncompressed bitmap memory per image.
  - Always downsample during decoding using `CGImageSourceCreateThumbnailAtIndex` specifying `kCGImageSourceThumbnailMaxPixelSize`.
- **SwiftUI Cascade Invalidation**: Misplaced `@Observable` or `@State` properties at the root view re-evaluate the entire body hierarchy. Profile with `Time Profiler` to identify repeated view body evaluations.

---

## 6. Included Analysis Scripts

All scripts are located in `scripts/` and require Python 3.8+ standard library:

1. **`compare_elements.py`**:
   - Takes arbitrary number of exported Power XML files: `python3 compare_elements.py <file1:label1> <file2:label2> ...`
   - Automatically establishes the first file as Baseline and computes net instruction rate delta (`+M/s`) and CPU impact delta.
2. **`parse_power.py`**:
   - Single-file power breakdown: `python3 parse_power.py <path_to_xml> [optional_label]`
   - Formats total instructions (Giga-instructions), rate (M/s), and subsystem impact metrics.
3. **`top_categories.py`**:
   - Memory allocation categories analyzer: `python3 top_categories.py <path_to_xml> <duration_sec> [min_rate]`
   - Extracts category rows sorted by allocation frequency and memory footprint.
4. **`run_trace.sh`**:
   - CLI automation runner for capturing traces and auto-invoking parsers.
