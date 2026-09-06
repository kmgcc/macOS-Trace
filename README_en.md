# macOS-Trace

[English](README_en.md) | [中文](README.md)

[![Agent Skills Open Standard](https://img.shields.io/badge/Agent_Skills-Open_Standard-blueviolet.svg)](https://agentskills.io)
[![Install](https://img.shields.io/badge/Install-npx_skills_add-000000.svg)](https://skills.sh/kmgcc/macOS-Trace)
[![Platform](https://img.shields.io/badge/Platform-macOS_12%2B-black.svg)](https://developer.apple.com/macos/)
[![Tooling](https://img.shields.io/badge/Xcode-Instruments_%2F_xctrace-007AFF.svg)](https://developer.apple.com/xcode/)
[![Python](https://img.shields.io/badge/Python-3.8%2B_(Zero_Deps)-3776AB.svg)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> Looking for iOS and iPadOS profiling on physical devices or simulators? See [iOS-Trace](https://github.com/kmgcc/iOS-Trace).

Autonomous, closed-loop application performance optimization engine for macOS applications using `xctrace` and Xcode Instruments.

Designed for AI coding agents (Claude Code, OpenAI Codex, Cursor, Google Antigravity, GitHub Copilot) and macOS systems engineers. It completely eliminates manual Instruments GUI interaction. From a single prompt, an agent can align on optimization goals with the user, capture headless diagnostic traces, implement targeted code fixes, and re-test with differential benchmarking across multiple iterations until the user's requirements are met.

---

## The Autonomous Optimization Loop

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

1. **Goal Alignment**: The agent queries the user upfront (via interactive questionnaire modal if available, or direct chat) with concrete recommended thresholds.
2. **Diagnostic Profiling**: Headless trace capture under idle baseline and active workload to isolate hot call-frames and allocation spikes.
3. **Code Modification**: The agent implements surgical, source-level optimizations directly in the codebase.
4. **Re-Test Verification**: Automated re-profiling under identical conditions to compute empirical Before vs After deltas.
5. **Iteration Gate**: If the user's targets are met, deliver the final report; if not, initiate the next optimization round automatically.

---

## Upfront Goal Alignment (Pre-Flight Questionnaire)

Before making changes or running traces, agents should align on targets with the user:

- **Interactive Modal / Components**: If the agent platform provides an interactive modal or prompt tool (e.g. `ask_question`), invoke it to present selectable options. Otherwise, ask directly in conversation.
- **Recommended Threshold Presets**:
  - **CPU & Energy**:
    - *Idle Baseline Target*: < 20 M/s instructions, CPU Impact < 0.5.
    - *Active Workload Target*: < 100 M/s instructions (or reduce current CPU by 30% - 50%).
  - **Memory Footprint**:
    - *Maximum Resident RAM*: Cap at < 150 MB (utility/audio apps) or < 300 MB (rich UI/media apps).
    - *Allocation Rate*: < 500 events/sec during steady-state execution.
    - *Leaks*: 0 persistent leaks.
  - **UI Smoothness & Hitches**:
    - *Hitch Ratio*: < 5.0 ms/s (acceptable), < 1.0 ms/s (fluid/zero dropped frames).
  - **Cold Launch Time**:
    - *Time to First Frame*: < 400 ms (excellent), < 800 ms (acceptable).

---

## Non-Negotiable Operational Rules for Agents

1. **Never Silently Alter UI, Visual Fidelity, or Core Behavior**:
   - If an optimization impacts visual aesthetics (blur materials, shadows, frame rates, complex animations) or critical application workflows, **agents must not unilaterally remove them**.
   - The agent must ask the user for explicit permission, presenting the exact before/after visual difference and the quantified expected gain (e.g. "Disabling blur reduces GPU impact from 1.5 to 0.2").
2. **Focus on Dominant Bottlenecks**:
   - Avoid scattered micro-optimizations across innocent utilities. Always isolate the primary driver (e.g. redundant surface instances, unthrottled timer re-evaluations, high-frequency unbuffered I/O) before modifying code.
3. **Strict Context Window Budgeting**:
   - Raw `.trace` archives and unparsed XML tables can reach hundreds of megabytes and will crash agent context windows. Agents must never dump raw traces or unparsed tables into the chat. Always filter, stream, and rank data using the bundled Python scripts.
4. **Clean Up Recording Artifacts**:
   - Every recording creates several-GB transient kernel traces (`instruments*.ktrace`) and an Instruments CLI cache in the system temp folder. `scripts/run_trace.sh` removes them automatically on exit. Once the user accepts the final report, delete the accumulated `.trace` bundles in `/tmp/macos-traces/` (unless the user asks to keep them). Never leave hundreds of GB of temporary recording data behind.

---

## Prerequisites and Scope

### Supported Targets
- **macOS Native Applications Only**: Designed exclusively for macOS desktop software (SwiftUI, AppKit, Metal, CoreAudio / AVAudioEngine, WebKit native host apps, and compiled CLI binaries).
- **Unsupported**: Not designed for iOS simulators, remote physical iPhones/iPads, watchOS/tvOS, or browser-only web applications.

### Tooling and System Requirements
- **macOS Version**: macOS 12.0 (Monterey) or later.
- **Xcode & xctrace**: Full Xcode installation or Xcode Command Line Tools with `xctrace` support (`xcrun xctrace version`).
- **Hardware Metrics**: The `Power Profiler` template and subsystem energy impact counters (`ProcessSubsystemPowerImpact`) require Apple Silicon hardware (M1/M2/M3/M4 series).
- **Process Entitlements**: Debug builds or binaries with `com.apple.security.get-task-allow` entitlement are required for `--attach <PID>`.
- **Python**: Python 3.8+ (uses standard library only; zero external pip dependencies).

---

## Installation

### Recommended: one command with the skills CLI

```bash
npx skills add kmgcc/macOS-Trace
```

The `skills` CLI detects installed agents (Claude Code, OpenAI Codex, Cursor, GitHub Copilot, Gemini CLI, Google Antigravity, OpenCode, Windsurf, and 70+ more) and links the skill into the correct directory for each. Add `-g` to install globally for all projects, or `-a claude-code -g` to target a single agent.

### Manual installation (per agent)

Each agent reads skills from its own directory. The skill directory name must be `macos-trace`, matching the `name` field in `SKILL.md`:

| Agent | Project scope | Global scope (all projects) |
| :--- | :--- | :--- |
| Claude Code | `.claude/skills/macos-trace` | `~/.claude/skills/macos-trace` |
| OpenAI Codex | `.agents/skills/macos-trace` | `~/.codex/skills/macos-trace` |
| Cursor | `.agents/skills/macos-trace` | `~/.cursor/skills/macos-trace` |
| OpenCode | `.agents/skills/macos-trace` | `~/.config/opencode/skills/macos-trace` |
| Gemini CLI | `.agents/skills/macos-trace` | `~/.gemini/skills/macos-trace` |
| Google Antigravity | `.agents/skills/macos-trace` | `~/.gemini/antigravity/skills/macos-trace` |
| GitHub Copilot | `.agents/skills/macos-trace` | `~/.copilot/skills/macos-trace` |
| Amp / Cline / Warp / Zed | `.agents/skills/macos-trace` | `~/.agents/skills/macos-trace` |

```bash
# Clone globally for Claude Code
git clone https://github.com/kmgcc/macOS-Trace.git ~/.claude/skills/macos-trace

# Or pin it inside a repository as a versioned git submodule (Claude Code project scope)
git submodule add https://github.com/kmgcc/macOS-Trace.git .claude/skills/macos-trace
```

### Complete Optimization Run Example

```bash
APP_NAME="YourApp"
SKILL_DIR="$HOME/.claude/skills/macos-trace"

# 1. Record 60s idle baseline (the runner resolves the process name to a PID itself):
"$SKILL_DIR/scripts/run_trace.sh" --process "$APP_NAME" --template power --duration 60s --label "01-baseline"

# 2. Record pre-optimization active workload:
"$SKILL_DIR/scripts/run_trace.sh" --process "$APP_NAME" --template power --duration 60s --label "02-pre-opt"

# 3. Implement code fixes, rebuild app, then record post-optimization active workload:
"$SKILL_DIR/scripts/run_trace.sh" --process "$APP_NAME" --template power --duration 60s --label "03-post-opt"

# 4. Compare Pre-Opt vs Post-Opt against Baseline:
python3 "$SKILL_DIR/scripts/compare_elements.py" \
  /tmp/macos-traces/01-baseline-power.xml:"Idle Baseline" \
  /tmp/macos-traces/02-pre-opt-power.xml:"Active Pre-Opt" \
  /tmp/macos-traces/03-post-opt-power.xml:"Active Post-Opt"
```

Output:
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

---

## Included Tooling

All scripts require Python 3.8+ and use the standard library only (`re`, `sys`, `os`, `xml.etree.ElementTree`, `collections`).

| Script | Function | Usage |
| :--- | :--- | :--- |
| `scripts/run_trace.sh` | CLI runner: record, export, and parse in one command; auto-cleans transient Instruments temp files on exit | `./scripts/run_trace.sh --process MyApp --template power` |
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
