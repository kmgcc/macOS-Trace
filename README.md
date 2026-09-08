# macOS-Trace

[中文](README.md) | [English](README_en.md)

[![Agent Skills Open Standard](https://img.shields.io/badge/Agent_Skills-Open_Standard-blueviolet.svg)](https://agentskills.io)
[![Install](https://img.shields.io/badge/Install-npx_skills_add-000000.svg)](https://skills.sh/kmgcc/macOS-Trace)
[![Platform](https://img.shields.io/badge/Platform-macOS_12%2B-black.svg)](https://developer.apple.com/macos/)
[![Tooling](https://img.shields.io/badge/Xcode-Instruments_%2F_xctrace-007AFF.svg)](https://developer.apple.com/xcode/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> 需要 iOS / iPadOS 应用（真机与模拟器）性能分析？见 [iOS-Trace](https://github.com/kmgcc/iOS-Trace)。

基于 `xctrace` 与 Xcode Instruments 的 **macOS 原生应用自主闭环性能调优引擎**。让 AI 编码 Agent（Claude Code、OpenAI Codex、Cursor、Google Antigravity、GitHub Copilot）无需手动操作 Instruments GUI，即可完成：目标对齐 → 无头诊断 → 定位瓶颈 → 定向改码 → 复测对比 → 未达标自动迭代。

---

## 前置条件

- **宿主**：macOS 12+，完整 Xcode 或 Xcode 命令行工具（`xcrun xctrace version`）。
- **目标**：macOS 原生桌面 App（SwiftUI、AppKit、Metal、CoreAudio、WebKit、命令行二进制）。不支持 iOS 模拟器/真机与纯浏览器 Web App。
- **硬件指标**：`Power Profiler` 与能耗计数需 Apple Silicon（M1/M2/M3/M4）。
- **Python**：3.8+（仅标准库，零第三方依赖）。

---

## 安装

### 推荐：一条命令（skills CLI 自动匹配各 Agent 目录）

```bash
npx skills add kmgcc/macOS-Trace
```

加 `-g` 全局安装（所有项目可用），或 `-a claude-code -g` 指定单个 Agent。

### 手动安装（目录名必须为 `macos-trace`）

| Agent | 项目级 | 用户级全局 |
| :--- | :--- | :--- |
| Claude Code | `.claude/skills/macos-trace` | `~/.claude/skills/macos-trace` |
| OpenAI Codex | `.agents/skills/macos-trace` | `~/.codex/skills/macos-trace` |
| Cursor | `.agents/skills/macos-trace` | `~/.cursor/skills/macos-trace` |
| OpenCode | `.agents/skills/macos-trace` | `~/.config/opencode/skills/macos-trace` |
| 其他 Agent | `.agents/skills/macos-trace` | `~/.agents/skills/macos-trace` |

```bash
git clone https://github.com/kmgcc/macOS-Trace.git ~/.claude/skills/macos-trace
```

---

## 怎么调用

安装后，Agent 会根据 description 里的触发条件自动匹配，或直接要求"用 macOS-Trace 优化 XX"。核心运行示例：

```bash
SKILL_DIR="$HOME/.claude/skills/macos-trace"
"$SKILL_DIR/scripts/run_trace.sh" --process "YourApp" --template power --duration 60s --label "01-baseline"
python3 "$SKILL_DIR/scripts/compare_elements.py" /tmp/macos-traces/01-baseline-power.xml:"Idle" /tmp/macos-traces/02-active-power.xml:"Active"
```

---

## 文档地图（按需读取）

- **`SKILL.md`** — 核心行为指令：目标对齐、执行规则、4 阶段闭环协议。
- **`references/templates.md`** — Instruments 模板选择（哪种瓶颈用哪个模板）。
- **`references/subsystems.md`** — 各子系统调优知识（音频/Metal/WebKit/UI 内存）。
- **`references/workload-reproduction.md`** — 负载如何复现（Tier 0–2，含 macOS 无障碍 UI 自动化）。

---

## 局限与注意点

- 需要 `--attach` 的进程必须为 debug/开发签名构建（`get-task-allow`）。
- 被遮挡/最小化的窗口会被 macOS 节流渲染，产生偏低的 GPU/CPU 读数——保持目标窗口在前台。
- macOS UI 自动化需要给自动化宿主授权"辅助功能"（Accessibility）权限。
- 若需"AI 自动操作 App 复现场景"，见 `references/workload-reproduction.md`。

---

## License

MIT License。见 [LICENSE](LICENSE)。
