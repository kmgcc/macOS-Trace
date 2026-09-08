# macOS-Trace

[English](README_en.md) | [中文](README.md)

[![Agent Skills Open Standard](https://img.shields.io/badge/Agent_Skills-Open_Standard-blueviolet.svg)](https://agentskills.io)
[![Install](https://img.shields.io/badge/Install-npx_skills_add-000000.svg)](https://skills.sh/kmgcc/macOS-Trace)
[![Platform](https://img.shields.io/badge/Platform-macOS_12%2B-black.svg)](https://developer.apple.com/macos/)
[![Tooling](https://img.shields.io/badge/Xcode-Instruments_%2F_xctrace-007AFF.svg)](https://developer.apple.com/xcode/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> Looking for iOS/iPadOS profiling on physical devices or simulators? See [iOS-Trace](https://github.com/kmgcc/iOS-Trace).

An autonomous, closed-loop performance optimization engine for **macOS native apps** built on `xctrace` and Xcode Instruments. Lets AI coding agents (Claude Code, OpenAI Codex, Cursor, Google Antigravity, GitHub Copilot) work without touching the Instruments GUI: goal alignment → headless diagnostics → hotspot isolation → targeted code fixes → differential re-testing → automatic iteration until targets are met.

---

## Prerequisites

- **Host**: macOS 12+, full Xcode or Xcode Command Line Tools (`xcrun xctrace version`).
- **Target**: macOS native desktop apps only (SwiftUI, AppKit, Metal, CoreAudio, WebKit, CLI binaries). Not for iOS simulators/devices or browser-only web apps.
- **Hardware metrics**: `Power Profiler` and energy counters require Apple Silicon (M1/M2/M3/M4).
- **Python**: 3.8+ (standard library only, zero third-party dependencies).

---

## Installation

### Recommended: one command (skills CLI matches each agent's directory)

```bash
npx skills add kmgcc/macOS-Trace
```

Add `-g` for global (all projects), or `-a claude-code -g` to target a single agent.

### Manual installation (directory name must be `macos-trace`)

| Agent | Project scope | Global scope |
| :--- | :--- | :--- |
| Claude Code | `.claude/skills/macos-trace` | `~/.claude/skills/macos-trace` |
| OpenAI Codex | `.agents/skills/macos-trace` | `~/.codex/skills/macos-trace` |
| Cursor | `.agents/skills/macos-trace` | `~/.cursor/skills/macos-trace` |
| OpenCode | `.agents/skills/macos-trace` | `~/.config/opencode/skills/macos-trace` |
| Other agents | `.agents/skills/macos-trace` | `~/.agents/skills/macos-trace` |

```bash
git clone https://github.com/kmgcc/macOS-Trace.git ~/.claude/skills/macos-trace
```

---

## How to Invoke

After installation, the agent auto-triggers from the description's conditions, or you can ask directly: "use macOS-Trace to optimize X". Minimal run:

```bash
SKILL_DIR="$HOME/.claude/skills/macos-trace"
"$SKILL_DIR/scripts/run_trace.sh" --process "YourApp" --template power --duration 60s --label "01-baseline"
python3 "$SKILL_DIR/scripts/compare_elements.py" /tmp/macos-traces/01-baseline-power.xml:"Idle" /tmp/macos-traces/02-active-power.xml:"Active"
```

---

## Documentation Map (load on demand)

- **`SKILL.md`** — Core behavior: goal alignment, agent rules, the 4-phase loop.
- **`references/templates.md`** — Instruments template picker (which template for which bottleneck).
- **`references/subsystems.md`** — Per-subsystem optimization patterns (audio / Metal / WebKit / UI-memory / media decoding).
- **`references/workload-reproduction.md`** — How to reproduce the workload (Tier 0–2), including Accessibility-driven UI automation.

---

## Limitations & Notes

- Processes targeted with `--attach` must be debug/development-signed builds (`get-task-allow`).
- Occluded or minimized windows are throttled by macOS and produce falsely low GPU/CPU readings — keep the target window in the foreground.
- macOS UI automation requires Accessibility permission for the automation host.
- For "AI operating the app to reproduce a scenario", see `references/workload-reproduction.md`.

---

## License

MIT License. See [LICENSE](LICENSE).
