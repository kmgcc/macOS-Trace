# macOS-Trace

[English](README.md) | [中文](README_zh.md)

[![Agent Skills Open Standard](https://img.shields.io/badge/Agent_Skills-Open_Standard-blueviolet.svg)](https://agentskills.io)
[![Platform](https://img.shields.io/badge/Platform-macOS_12%2B-black.svg)](https://developer.apple.com/macos/)
[![Tooling](https://img.shields.io/badge/Xcode-Instruments_%2F_xctrace-007AFF.svg)](https://developer.apple.com/xcode/)
[![Python](https://img.shields.io/badge/Python-3.8%2B_(Zero_Deps)-3776AB.svg)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> Looking for iOS and iPadOS profiling on physical devices or simulators? See [iOS-Trace](https://github.com/kmgcc/iOS-Trace).

Headless profiling and quantitative A/B benchmarking toolchain for macOS applications using `xctrace` and Xcode Instruments.

Designed for AI coding agents (Claude Code, OpenAI Codex, Cursor, Google Antigravity, GitHub Copilot) and macOS systems engineers. It automates trace collection, table data extraction via XPath, and differential performance analysis without opening the Instruments GUI.

---

## Prerequisites and Scope

Read these system requirements and constraints before deploying or invoking this skill:

### Supported Targets
- **macOS Native Applications Only**: Designed exclusively for macOS desktop software (SwiftUI, AppKit, Metal, CoreAudio / AVAudioEngine, WebKit native host apps, and compiled CLI binaries).
- **Unsupported**: Not designed for iOS simulators, remote physical iPhones/iPads, watchOS/tvOS, or browser-only web applications running in external browsers.

### Tooling and System Requirements
- **macOS Version**: macOS 12.0 (Monterey) or later.
- **Xcode & xctrace**: Full Xcode installation or Xcode Command Line Tools with `xctrace` support. Verify with:
  ```bash
  xcode-select -p
  xcrun xctrace version
  ```
  If missing, install via `xcode-select --install` or download Xcode from the Mac App Store / Apple Developer portal.
- **Hardware Metrics**: The `Power Profiler` template and subsystem energy impact counters (`ProcessSubsystemPowerImpact`) require Apple Silicon hardware (M1/M2/M3/M4 series).
- **Process Entitlements**: When attaching (`--attach <PID>`) to processes built with Hardened Runtime enabled, the binary must include the `com.apple.security.get-task-allow` entitlement (standard in Debug builds). Otherwise, profiling must be performed by launching the executable directly via `--launch`.
- **Python**: Python 3.8+ (pre-installed on macOS). All included scripts use the standard library only (`re`, `sys`, `os`, `xml.etree.ElementTree`, `collections`). No third-party pip packages are required.

---

## Agent Installation and Integration Guide

This section outlines how an AI coding agent should install, locate, and execute `macOS-Trace` within an automated repository workflow.

### 1. Skill Location Detection

When an agent needs to install this skill into a repository, it should detect the existing skill directory convention in the workspace:

```bash
# Order of preference for agent skill directories:
# 1. Standard Agent Skills: .agents/skills/
# 2. OpenAI Codex:          .codex/skills/
# 3. Cursor:                 .cursor/skills/
# 4. Claude Code:            .claude/skills/
```

If none exists, default to `.agents/skills/`.

### 2. Installation Commands for Agents

Install into the target repository using one of the following commands:

```bash
# Option A: Standard Agent Skills directory (Recommended)
mkdir -p .agents/skills
git clone https://github.com/kmgcc/macOS-Trace.git .agents/skills/macos-trace

# Option B: As a Git Submodule (for versioned repository tracking)
git submodule add https://github.com/kmgcc/macOS-Trace.git .agents/skills/macos-trace

# Option C: OpenAI Codex specific directory
mkdir -p .codex/skills
git clone https://github.com/kmgcc/macOS-Trace.git .codex/skills/macos-trace

# Option D: User-level global installation (available across all workspaces)
mkdir -p ~/.agents/skills
git clone https://github.com/kmgcc/macOS-Trace.git ~/.agents/skills/macos-trace
```

### 3. Autonomous Execution Protocol for Agents

When an agent is tasked with diagnosing a performance issue or verifying an optimization, it should execute the following 5-step protocol:

```text
Step 1: Verify Environment & Liveness
   │    Check xcrun xctrace, verify target process exists via pgrep.
   ▼
Step 2: Record Idle Baseline Run
   │    Keep window in foreground. Record 60s with workload paused.
   ▼
Step 3: Execute Target Workload & Record Active Run
   │    Trigger target feature/audio/animation. Record 60s active state.
   ▼
Step 4: Compute Differential Delta
   │    Run scripts/compare_elements.py to compute:
   │    Delta = Active - Baseline.
   ▼
Step 5: Report Empirical Results
        Present table with M/s instruction delta and CPU change to the user.
```

#### Protocol Command Sequence

```bash
# Step 1: Pre-flight check
APP_NAME="YourApp"
PID=$(pgrep -x "$APP_NAME")
if [[ -z "$PID" ]]; then
  echo "Error: Process $APP_NAME is not running." >&2
  exit 1
fi

SKILL_DIR=".agents/skills/macos-trace"

# Step 2: Record 60s idle baseline (workload paused, window visible)
"$SKILL_DIR/scripts/run_trace.sh" --process "$PID" --template power --duration 60s --label "01-baseline"

# Step 3: Trigger the target feature in the app, then record 60s active state
"$SKILL_DIR/scripts/run_trace.sh" --process "$PID" --template power --duration 60s --label "02-active"

# Step 4: Run comparison
python3 "$SKILL_DIR/scripts/compare_elements.py" \
  /tmp/macos-traces/01-baseline-power.xml:"1. Idle Baseline" \
  /tmp/macos-traces/02-active-power.xml:"2. Active Workload"
```

---

## Workflow Architecture

```text
Target Native App (PID)
        │
        ▼
xcrun xctrace record (Headless Instruments)
        │
        ▼
Trace Package (.trace)
        │
        ▼
xcrun xctrace export (Table-level XPath Extraction)
        │
        ▼
Structured XML Tables
        │
        ▼
macOS-Trace Parsers (Python 3 standard library)
        │
        ▼
Quantitative Metrics & Baseline Delta (M/s, CPU %, Alloc/s)
```

---

## Quick Start Example

Running the comparison produces an empirical differential report:

```text
Scenario                    Sec  CPU Avg  CPU Max  Display  GPU Avg  Total Instr    Instr M/s
============================================================================================
1. Idle Baseline             60     0.15     0.80     0.05     0.00        1.02G         17.0
2. Active Workload           60     1.85     3.40     0.90     1.20       12.60G        210.0
--------------------------------------------------------------------------------------------
Differential vs Baseline [1. Idle Baseline]:
  2. Active Workload           +193.0 M/s instructions, CPU Avg Delta +1.70
```

---

## Included Tooling

All scripts require Python 3.8+ and use the standard library only (`re`, `sys`, `os`, `xml.etree.ElementTree`, `collections`).

| Script | Function | Usage |
| :--- | :--- | :--- |
| `scripts/run_trace.sh` | CLI runner: record, export, and parse in one command | `./scripts/run_trace.sh --process MyApp --template power` |
| `scripts/compare_elements.py` | Multi-run comparison table and baseline delta computation | `python3 scripts/compare_elements.py base.xml active.xml` |
| `scripts/parse_power.py` | Single-run breakdown of CPU, GPU, Display, and instruction throughput | `python3 scripts/parse_power.py run-power.xml "Workload"` |
| `scripts/top_categories.py` | Allocations ranking by event rate, transient, and persistent bytes | `python3 scripts/top_categories.py alloc.xml 60 10.0` |

---

## Instruments Templates

The toolchain supports standard Instruments templates via `scripts/run_trace.sh` shorthand flags:

### Compute & Energy
| Template | Shorthand | Target Metrics & Primary Use Case |
| :--- | :--- | :--- |
| `Power Profiler` | `power` | CPU instruction rate (M/s), CPU/GPU/Display subsystem impacts (`ProcessSubsystemPowerImpact`). Recommended for objective A/B testing. |
| `Time Profiler` | `time` | Thread CPU weights, call stack hotspots, main-thread blocking methods. |
| `CPU Counters` | `counters` | IPC (instructions per cycle), L1/L2 cache misses, branch mispredictions. For computational and DSP bottlenecks. |

### UI Responsiveness & Smoothness
| Template | Shorthand | Target Metrics & Primary Use Case |
| :--- | :--- | :--- |
| `Animation Hitches` | `hitches` | Hitch duration (ms), hitch ratio (ms/s), frame drops. Distinguishes App Phase (commit delays) from Render Phase (GPU delays). |
| `SwiftUI` | `swiftui` | View body evaluations, State invalidations, view update frequency. Diagnoses cascade re-renders. |
| `Metal System Trace` | `metal` | GPU encoder time, vertex/fragment shader durations, frame latency. Shader and particle pipeline stalls. |

### Memory & Allocations
| Template | Shorthand | Target Metrics & Primary Use Case |
| :--- | :--- | :--- |
| `Allocations` | `alloc` | Heap allocations, transient memory spikes, category event rates (`all-allocations-summary`). Buffer thrashing and peak allocation. |
| `Leaks` | `leaks` | Object leaks outliving parent lifecycle, retain cycles. |

### Startup & Concurrency
| Template | Shorthand | Target Metrics & Primary Use Case |
| :--- | :--- | :--- |
| `App Launch` | `launch` | Time to first frame, `dyld` loading time, static initializers, runloop setup. Cold-start optimization. |
| `Swift Concurrency` | `concurrency` | Swift Tasks (created/running/suspended), Actor reentrancy, cooperative thread pool saturation. |
| `System Trace` | `sys` | Thread state transitions (Running, Blocked on mutex, Waiting, Preempted), syscalls. Essential for "low CPU but frozen UI" hangs. |

### I/O & Audio
| Template | Shorthand | Target Metrics & Primary Use Case |
| :--- | :--- | :--- |
| `File Activity` | `files` / `io` | File open/read/write/close calls, I/O latency, throughput. Database (SwiftData/SQLite) or asset loading stalls. |
| `Audio System Trace` | `audio` | CoreAudio HAL IO thread jitter, audio buffer overruns/underruns (XRuns/glitches). Audio dropouts and DSP instability. |

---

## Subsystem Optimization Notes

Detailed implementation guidance is provided in [SKILL.md](SKILL.md):

1. **Real-Time Audio & DSP**: Zero heap allocations in `AURenderCallback` or `AVAudioNodeTap`; lock-free ring buffer dispatch for FFT analysis; UI update throttling (30-60Hz).
2. **Metal & Visual Effects**: Managing Retina pixel fill-rate multipliers (2x/3x scale factor on 4K displays); pausing `MTKView` and `CVDisplayLink` on window occlusion (`NSWindowOcclusionState`).
3. **WebKit & Hybrid Views**: Avoiding high-frequency `evaluateJavaScript` IPC saturation with large JSON payloads; using CSS transforms instead of layout-triggering properties for text animation.
4. **Desktop UI & Memory**: Downsampling high-resolution images or textures at decode time with `CGImageSourceCreateThumbnailAtIndex`; profiling SwiftUI root `@Observable` cascading body invalidation.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
