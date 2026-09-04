---
name: macos-trace
description: Profile macOS applications headlessly using xctrace and Xcode Instruments. Use when diagnosing CPU spikes, thermal throttling, UI hitching, memory leaks, high allocation rates, CoreAudio/DSP overhead, Metal shader execution costs, WebKit IPC latency, or when validating performance changes with differential A/B benchmarks.
compatibility: macOS 12+, Xcode Command Line Tools, Python 3.8+
license: MIT
metadata:
  author: kmgcc
  version: "1.0.0"
---

# macOS-Trace: Headless Performance Profiling

A workflow and toolchain for running headless Xcode Instruments profiling on macOS applications (SwiftUI, AppKit, Metal, CoreAudio, WebKit, and CLI binaries).

Use this skill to automate trace collection, extract data from Instruments tables into structured XML, and produce quantitative metrics and A/B comparisons without opening the Instruments GUI.

## Scope and Prerequisites

- **Target platform**: macOS native desktop applications only (SwiftUI, AppKit, Metal, CoreAudio / AVAudioEngine, WebKit host views, native CLI executables). Does not support iOS simulators, remote mobile devices, or external browser-only web apps.
- **Xcode tooling**: Requires macOS 12+ and full Xcode or Xcode Command Line Tools (`xcode-select -p`, `xcrun xctrace version`).
- **Python**: Python 3.8+ (pre-installed on macOS; zero external pip dependencies).
- **Process permissions**: Debug builds or binaries with `get-task-allow` entitlement are required for `--attach <PID>` under Hardened Runtime.

## Rules for Agents

Follow these constraints when profiling or verifying performance changes:

1. **Establish a baseline first**: Never record only the active workload. Total instructions or memory figures are uninformative without subtracting background load. Always capture an idle baseline (app open in foreground, target workload paused) before recording the active state. Compute: `Delta = Active - Baseline`.
2. **Verify target state before recording**: Check that the process exists using `pgrep -x <ProcessName>` and that the target feature is actively executing during the recording window.
3. **Keep the window in foreground**: macOS throttles rendering and display links for occluded or minimized windows (`NSWindowOcclusionState`). An occluded window will produce falsely low GPU and CPU readings.
4. **Use equal test parameters**: Compare runs with identical sample durations (default: `60s`), identical display scales, identical window sizes, and identical test input data. Never compare a Debug build against a Release build.
5. **No third-party Python dependencies**: All bundled scripts (`scripts/compare_elements.py`, `scripts/parse_power.py`, `scripts/top_categories.py`) use the Python 3 standard library only. Do not install pip packages.
6. **Save outputs to `/tmp/macos-traces/`**: Store all `.trace` bundles and `.xml` exports in `/tmp/macos-traces/` with timestamped and scenario-tagged filenames.

## Standard Workflow

### 1. Pre-Flight

```bash
# Verify tooling
xcrun xctrace version
python3 --version

# Prepare output directory
mkdir -p /tmp/macos-traces

# Find target PID
APP_NAME="YourApp"
PID=$(pgrep -x "$APP_NAME")
echo "PID: $PID"
```

### 2. Record and Analyze (Using `scripts/run_trace.sh`)

The script wraps `xcrun xctrace record`, `xcrun xctrace export`, and the Python parser into a single command:

```bash
# Step 1: Record 60s idle baseline
./scripts/run_trace.sh --process "$APP_NAME" --template power --duration 60s --label "01-idle-base"

# Step 2: Trigger the workload in the app, then record 60s active state
./scripts/run_trace.sh --process "$APP_NAME" --template power --duration 60s --label "02-active-workload"
```

### 3. Compute A/B Differential

Pass the exported XML files to `scripts/compare_elements.py`. The first file is treated as the reference baseline:

```bash
python3 scripts/compare_elements.py \
  /tmp/macos-traces/01-idle-base-power.xml:"Idle Baseline" \
  /tmp/macos-traces/02-active-workload-power.xml:"Active Workload"
```

Example output:
```text
Scenario                    Sec  CPU Avg  CPU Max  Display  GPU Avg  Total Instr    Instr M/s
============================================================================================
Idle Baseline                60     0.15     0.80     0.05     0.00        1.02G         17.0
Active Workload              60     1.85     3.40     0.90     1.20       12.60G        210.0
--------------------------------------------------------------------------------------------
Differential vs Baseline [Idle Baseline]:
  Active Workload              +193.0 M/s instructions, CPU Avg Delta +1.70
```

## Direct CLI Commands

If calling `xctrace` directly without `run_trace.sh`:

### Record

```bash
# Attach to running process (preserves app state)
xcrun xctrace record \
  --template 'Power Profiler' \
  --time-limit 60s \
  --output /tmp/macos-traces/power.trace \
  --attach $PID

# Launch executable directly
xcrun xctrace record \
  --template 'Time Profiler' \
  --time-limit 30s \
  --output /tmp/macos-traces/launch.trace \
  --launch -- /path/to/YourApp.app/Contents/MacOS/YourApp
```

### Export

```bash
# Export Power Impact table (instructions, CPU, GPU, display)
xcrun xctrace export \
  --input /tmp/macos-traces/power.trace \
  --xpath "/trace-toc/run[@number='1']/data/table[@schema='ProcessSubsystemPowerImpact']" \
  > /tmp/macos-traces/power.xml

# Export Allocations summary table (heap allocation counts and bytes by category)
xcrun xctrace export \
  --input /tmp/macos-traces/alloc.trace \
  --xpath "/trace-toc/run[@number='1']/data/table[@schema='all-allocations-summary']" \
  > /tmp/macos-traces/alloc.xml
```

## Template Reference

| Template | Short Name | Target Metrics & Export Schema |
| :--- | :--- | :--- |
| `Power Profiler` | `power` | Instructions/sec (M/s), CPU/GPU/Display subsystem impacts (`ProcessSubsystemPowerImpact`). Best for A/B testing. |
| `Time Profiler` | `time` | CPU sample weights by thread, call-tree hotspots, main-thread blocking calls. |
| `Allocations` | `alloc` | Heap allocations, transient vs persistent memory, category event rates (`all-allocations-summary`). |
| `Leaks` | `leaks` | Memory leaks that outlive their owner, reference cycles. |
| `Metal System Trace` | `metal` | GPU encoder time, vertex/fragment shader durations, frame boundary latency. |

## Subsystem Optimization Notes

### Real-Time Audio & DSP (CoreAudio / AVAudioEngine)
- **Zero heap allocation**: Code inside `AURenderCallback` or `AVAudioNodeTap` must not allocate heap memory (`malloc`, Swift `Array` reallocations, object creation) or acquire blocking locks (`os_unfair_lock` or mutexes that can priority-invert).
- **Buffer dispatch**: Copy audio data into a pre-allocated lock-free ring buffer. Push to background queues for FFT or level calculations.
- **UI meter throttling**: Throttle UI updates (e.g., LED meters, waveform views) to 30Hz or 60Hz. Never post UI updates on every audio buffer arrival (which occurs at ~100-300Hz depending on buffer size).
- **Diagnosis**: Use `Allocations`. If allocation rate exceeds 500 events/sec during audio playback, inspect audio tap closures using `scripts/top_categories.py`.

### Metal & Visual FX
- **Retina pixel fill rate**: High-DPI screens render at 2x or 3x scale. A fullscreen fragment shader (blur, bokeh, raymarching) on a 4K display shades over 16 million pixels per frame. If GPU impact is elevated, render to an offscreen half-resolution texture before compositing, or reduce sample counts.
- **Window occlusion**: Observe `NSWindow.occlusionState`. When `contains(.visible)` is false (window minimized or covered), pause `CVDisplayLink` or set `isPaused = true` on `MTKView`.
- **Diagnosis**: Use `Power Profiler` (`GPU Impact` column) and `Metal System Trace`.

### WebKit & Hybrid Views
- **IPC message rate**: Calling `evaluateJavaScript` with large JSON payloads at high frequency (e.g., 100Hz progress updates) saturates WebKit IPC and spikes CPU. Send sparse synchronization anchors (e.g., 1Hz) and let JavaScript interpolate smooth movement using `requestAnimationFrame`.
- **DOM layout thrashing**: Continuously changing properties like `top`, `margin`, or `height` in synchronized text views forces browser layout recalculation. Use CSS `transform: translateY()` or `opacity` instead.
- **Diagnosis**: Use `Time Profiler` and search for `WebCore::RenderLayer` or IPC serialization symbols.

### UI & Memory Management
- **Image downsampling**: Decoding high-resolution image assets (e.g., 3000x3000px or larger raw bitmaps) directly into `NSImage` allocates ~36MB of uncompressed bitmap memory per image. Downsample at decode time using `CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceThumbnailMaxPixelSize`.
- **SwiftUI body invalidation**: Root-level state changes trigger re-evaluation of downstream view bodies. Use `Time Profiler` to inspect repeated `View.body.getter` calls.
- **Diagnosis**: Use `Allocations` with `scripts/top_categories.py` to identify large transient buffer spikes.

## Script Usage

### `scripts/run_trace.sh`
Automates record, export, and parsing:
```bash
./scripts/run_trace.sh [options]
  -p, --process <name|pid>    Target process name or PID
  -l, --launch <binary_path>  Launch binary directly
  -t, --template <name>       power (default) | time | alloc | leaks | metal
  -d, --duration <time>       Duration (default: 60s)
  -o, --output-dir <path>     Output directory (default: /tmp/macos-traces)
  --label <text>              Run label
  --no-analyze                Skip automatic XML export and Python analysis
```

### `scripts/compare_elements.py`
Compares multiple exported Power XML runs:
```bash
python3 scripts/compare_elements.py <file1:label1> <file2:label2> [...]
```

### `scripts/parse_power.py`
Parses a single Power XML file:
```bash
python3 scripts/parse_power.py <path_to_xml> [label]
```

### `scripts/top_categories.py`
Ranks allocation categories by event rate and size:
```bash
python3 scripts/top_categories.py <path_to_xml> <duration_sec> [min_rate]
```
