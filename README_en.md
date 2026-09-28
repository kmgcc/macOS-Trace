# macOS-Trace

[English](README_en.md) | [中文](README.md)

[![Agent Skills Open Standard](https://img.shields.io/badge/Agent_Skills-Open_Standard-blueviolet.svg)](https://agentskills.io)
[![Install](https://img.shields.io/badge/Install-npx_skills_add-000000.svg)](https://skills.sh/kmgcc/macOS-Trace)
[![Platform](https://img.shields.io/badge/Platform-macOS-black.svg)](https://developer.apple.com/macos/)
[![Tooling](https://img.shields.io/badge/Xcode-Instruments_%2F_xctrace-007AFF.svg)](https://developer.apple.com/xcode/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> Need profiling for iOS or iPadOS? See [iOS-Trace](https://github.com/kmgcc/iOS-Trace).

An agent-native runbook for profiling native macOS apps. The agent selects instruments, workload reproduction, and success evidence for the reported issue. Capture with `xctrace` or the Instruments UI. Bundled scripts are optional data-processing helpers, not a required workflow.

## Prerequisites

- A native macOS app and a usable Xcode or Command Line Tools installation. Supported host OS versions depend on the selected Xcode; Xcode 27 requires macOS Tahoe 26.6 or later and runs only on Apple silicon.
- Instruments / `xctrace`. Check the active Xcode version, installed templates, and target OS support before recording.
- Python 3.8+ only when using the optional helper scripts.

## Installation

### Recommended: skills CLI

```bash
npx skills add kmgcc/macOS-Trace
```

Use `-g` for a user-level installation, or `-a` to select an agent supported by the CLI.

### Manual installation

| Agent | User-level global directory |
| :--- | :--- |
| Codex | `~/.agents/skills/macos-trace` |
| Antigravity | `~/.gemini/config/skills/macos-trace` |
| DSH | `~/.dsh/skills/macos-trace` |
| Claude Code | `~/.claude/skills/macos-trace` |
| Cursor | `~/.cursor/skills/macos-trace` |
| OpenCode | `~/.config/opencode/skills/macos-trace` |

Copy the repository contents into the selected directory. Discovery paths can change by agent version; follow the agent's current documentation for project-level installation.

## Use

Ask the agent to use `macos-trace` for a concrete scenario, such as playback dropouts, scrolling hitches, slow launch, or sustained memory growth. It will choose a profiler, reproduction path, and comparison method based on the question; no fixed script sequence is required.

## Documentation map

- `SKILL.md` — core runbook.
- `references/templates.md` — Instruments selection guide and Xcode 27 additions.
- `references/workload-reproduction.md` — choosing and verifying a reproduction path.
- `references/device-commands.md` — process verification, xctrace discovery, capture, and export.
- `references/xcode-agent-mcp.md` — optional Xcode MCP workflow and permission boundaries.
- `references/subsystems.md` — audio, Metal, WebKit, UI, memory, and media decoding leads.

## Boundaries

- Traces may contain prompts, paths, media metadata, or logs; treat them as sensitive task data.
- MCP is an optional Xcode project/development integration. It does not replace runtime measurements from Instruments.
- Follow the project's process, data ownership, build, test, and release rules.

## License

MIT License. See [LICENSE](LICENSE).
