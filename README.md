# macOS-Trace

[中文](README.md) | [English](README_en.md)

[![Agent Skills Open Standard](https://img.shields.io/badge/Agent_Skills-Open_Standard-blueviolet.svg)](https://agentskills.io)
[![Install](https://img.shields.io/badge/Install-npx_skills_add-000000.svg)](https://skills.sh/kmgcc/macOS-Trace)
[![Platform](https://img.shields.io/badge/Platform-macOS-black.svg)](https://developer.apple.com/macos/)
[![Tooling](https://img.shields.io/badge/Xcode-Instruments_%2F_xctrace-007AFF.svg)](https://developer.apple.com/xcode/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> 需要 iOS / iPadOS 性能分析？见 [iOS-Trace](https://github.com/kmgcc/iOS-Trace)。

面向 AI 编码 Agent 的 macOS 原生应用性能分析 runbook。Agent 按实际症状选择 Instruments、复现路径和验收证据；`xctrace` 负责记录，GUI 与命令行都可使用。附带脚本仅是可选的数据处理工具，不是固定执行流程。

## 前置条件

- macOS 原生应用与可用的 Xcode 或 Command Line Tools。支持的系统范围由当前 Xcode 版本决定；Xcode 27 要求 macOS Tahoe 26.6 或更新版本，并仅支持 Apple silicon Mac。
- 可用的 Instruments / `xctrace`。记录前应确认当前 Xcode 版本、模板和目标系统支持所需能力。
- Python 3.8+ 仅用于可选脚本。

## 安装

### 推荐：skills CLI

```bash
npx skills add kmgcc/macOS-Trace
```

使用 `-g` 安装到用户级目录；可用 `-a` 选择 CLI 支持的 Agent。

### 手动安装

| Agent | 用户级全局目录 |
| :--- | :--- |
| Codex | `~/.agents/skills/macos-trace` |
| Antigravity | `~/.gemini/config/skills/macos-trace` |
| DSH | `~/.dsh/skills/macos-trace` |
| Claude Code | `~/.claude/skills/macos-trace` |
| Cursor | `~/.cursor/skills/macos-trace` |
| OpenCode | `~/.config/opencode/skills/macos-trace` |

把仓库内容放入对应目录即可。具体发现路径可能随 Agent 版本变化；项目级安装请遵循该 Agent 当前文档。

## 使用

要求 Agent 使用 `macos-trace` 调查明确的用户场景，例如音频播放卡顿、滚动掉帧、启动变慢或内存持续增长。Agent 会按目标选择采样器、复现方式和对比方法；不需要先运行固定脚本。

## 文档地图

- `SKILL.md` — 核心执行 runbook。
- `references/templates.md` — Instruments 选择指南与 Xcode 27 增强项。
- `references/workload-reproduction.md` — 按实际交互选择和验证复现路径。
- `references/device-commands.md` — 进程确认、xctrace 能力发现、记录与导出。
- `references/storage-and-recovery.md` — 临时文件增长、已删除但仍打开的 `.ktrace` 回收与安全清理。
- `references/xcode-agent-mcp.md` — 可选 Xcode MCP 工作流及权限边界。
- `references/subsystems.md` — 音频、Metal、WebKit、UI、内存和媒体解码优化线索。

## 使用边界

- trace 可能包含提示词、路径、媒体或日志信息，按敏感任务数据处理。
- MCP 是可选的 Xcode 项目/开发集成；它不替代 Instruments 运行时测量。
- 遵循项目自身的进程、数据所有权、构建、测试和发布规则。

## License

MIT License。见 [LICENSE](LICENSE)。
