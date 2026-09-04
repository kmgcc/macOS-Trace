# macOS-Trace

[English](README.md) | [中文](README_zh.md)

[![Agent Skills Open Standard](https://img.shields.io/badge/Agent_Skills-Open_Standard-blueviolet.svg)](https://agentskills.io)
[![Platform](https://img.shields.io/badge/Platform-macOS_12%2B-black.svg)](https://developer.apple.com/macos/)
[![Tooling](https://img.shields.io/badge/Xcode-Instruments_%2F_xctrace-007AFF.svg)](https://developer.apple.com/xcode/)
[![Python](https://img.shields.io/badge/Python-3.8%2B_(Zero_Deps)-3776AB.svg)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Headless profiling and quantitative A/B benchmarking toolchain for macOS applications using `xctrace` and Xcode Instruments.

Designed for both AI coding agents (Claude Code, OpenAI Codex, Cursor, Google Antigravity, GitHub Copilot) and macOS systems engineers. It automates trace collection, table data extraction via XPath, and differential performance analysis without opening the Instruments GUI.

---

## Overview

Traditional Instruments profiling requires manual GUI interaction and exports opaque `.trace` bundles that cannot be parsed directly in automated pipelines or terminal sessions.

`macOS-Trace` provides:
- Headless recording for `Power Profiler`, `Time Profiler`, and `Allocations` via `xcrun xctrace`.
- Targeted XML extraction using table-level XPath queries (`ProcessSubsystemPowerImpact`, `all-allocations-summary`).
- Lightweight Python parsers using only the standard library (zero third-party dependencies).
- Differential A/B comparison that measures instruction rate deltas (M/s), CPU impact, and allocation frequency against an established baseline.
- Production-tested recipes for CoreAudio/DSP, Metal shaders, WebKit hybrid views, and AppKit/SwiftUI memory spikes.

---

## Workflow

```text
Target Process (PID)
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

## Quick Start

Use `scripts/run_trace.sh` to record, export, and parse in a single command:

```bash
# 1. Record 60s idle baseline:
./scripts/run_trace.sh --process "MyApp" --template power --duration 60s --label "01-idle-base"

# 2. Trigger the active workload in the app, then record:
./scripts/run_trace.sh --process "MyApp" --template power --duration 60s --label "02-active-workload"

# 3. Compare runs against baseline:
python3 scripts/compare_elements.py \
  /tmp/macos-traces/01-idle-base-power.xml:"1. Baseline" \
  /tmp/macos-traces/02-active-workload-power.xml:"2. Active Workload"
```

Output:
```text
Scenario                    Sec  CPU Avg  CPU Max  Display  GPU Avg  Total Instr    Instr M/s
============================================================================================
1. Baseline                  60     0.15     0.80     0.05     0.00        1.02G         17.0
2. Active Workload           60     1.85     3.40     0.90     1.20       12.60G        210.0
--------------------------------------------------------------------------------------------
Differential vs Baseline [1. Baseline]:
  2. Active Workload           +193.0 M/s instructions, CPU Avg Delta +1.70
```

---

## Installation

### Project-Level Installation

Clone into your workspace's agent skills directory:

```bash
# Standard Agent Skills directory (.agents/skills)
git clone https://github.com/kmgcc/macOS-Trace.git .agents/skills/macos-trace

# Codex workspace directory (.codex/skills)
git clone https://github.com/kmgcc/macOS-Trace.git .codex/skills/macos-trace

# As a Git submodule
git submodule add https://github.com/kmgcc/macOS-Trace.git .agents/skills/macos-trace
```

### Global Installation

```bash
# Global skills directory for Claude Code / Cursor / Antigravity
mkdir -p ~/.agents/skills
git clone https://github.com/kmgcc/macOS-Trace.git ~/.agents/skills/macos-trace

# Global skills directory for Codex
mkdir -p ~/.codex/skills
git clone https://github.com/kmgcc/macOS-Trace.git ~/.codex/skills/macos-trace
```

---

## Included Tooling

All scripts require Python 3.8+ and use the standard library only (`re`, `sys`, `os`, `xml.etree.ElementTree`, `collections`). No virtual environment or pip packages required.

| Script | Function | Usage |
| :--- | :--- | :--- |
| `scripts/run_trace.sh` | CLI runner: record, export, and parse in one command | `./scripts/run_trace.sh --process MyApp --template power` |
| `scripts/compare_elements.py` | Multi-run comparison table and baseline delta computation | `python3 scripts/compare_elements.py base.xml active.xml` |
| `scripts/parse_power.py` | Single-run breakdown of CPU, GPU, Display, and instruction throughput | `python3 scripts/parse_power.py run-power.xml "Workload"` |
| `scripts/top_categories.py` | Allocations ranking by event rate, transient, and persistent bytes | `python3 scripts/top_categories.py alloc.xml 60 10.0` |

---

## Instruments Templates

| Template | Shorthand | Target Metrics & Use Case |
| :--- | :--- | :--- |
| `Power Profiler` | `power` | CPU instruction rate (M/s), CPU/GPU/Display subsystem impacts (`ProcessSubsystemPowerImpact`). Recommended for A/B testing. |
| `Time Profiler` | `time` | Thread CPU weights, call stack hotspots, main-thread blocking methods. |
| `Allocations` | `alloc` | Heap allocation rates, transient memory spikes, category event rates (`all-allocations-summary`). |
| `Leaks` | `leaks` | Object leaks outliving parent lifecycle, retain cycles. |
| `Metal System Trace` | `metal` | GPU encoder time, vertex/fragment shader durations, frame latency. |

---

## Subsystem Optimization Notes

Detailed implementation guidance is provided in [SKILL.md](SKILL.md):

1. **Real-Time Audio & DSP**: Zero heap allocations in `AURenderCallback` or `AVAudioNodeTap`; lock-free ring buffer dispatch for FFT analysis; UI update throttling (30-60Hz).
2. **Metal & Visual Effects**: Managing Retina pixel fill-rate multipliers (2x/3x scale factor on 4K displays); pausing `MTKView` and `CVDisplayLink` on window occlusion (`NSWindowOcclusionState`).
3. **WebKit & Hybrid Views**: Avoiding high-frequency `evaluateJavaScript` IPC saturation with large JSON payloads; using CSS transforms instead of layout-triggering properties for text animation.
4. **Desktop UI & Memory**: Downsampling full-resolution image artwork during decoding with `CGImageSourceCreateThumbnailAtIndex`; profiling SwiftUI root `@Observable` cascading body invalidation.

---

## Prerequisites

- macOS 12.0 (Monterey) or later.
- Xcode Command Line Tools (`xcode-select --install`).
- Python 3.8+ (included with macOS).

---

## License

MIT License. See [LICENSE](LICENSE) for details.
