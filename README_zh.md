# macOS-Trace

[English](README.md) | [中文](README_zh.md)

[![Agent Skills Open Standard](https://img.shields.io/badge/Agent_Skills-Open_Standard-blueviolet.svg)](https://agentskills.io)
[![Platform](https://img.shields.io/badge/Platform-macOS_12%2B-black.svg)](https://developer.apple.com/macos/)
[![Tooling](https://img.shields.io/badge/Xcode-Instruments_%2F_xctrace-007AFF.svg)](https://developer.apple.com/xcode/)
[![Python](https://img.shields.io/badge/Python-3.8%2B_(Zero_Deps)-3776AB.svg)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

基于 `xctrace` 与 Xcode Instruments 的 macOS 原生应用无头（Headless）性能诊断与客观 A/B 差值量化工具链。

专为 **AI 编码 Agent**（Claude Code、OpenAI Codex、Cursor、Google Antigravity、GitHub Copilot）及 **macOS 研发工程师** 设计。无需开启 Instruments 图形界面，即可在终端或自动化流水线中完成 Trace 采集、XPath 数据表精准提取、量化指标解析与优化前后对比。

---

## 概述

使用 Instruments GUI 诊断 macOS 应用通常需要大量人工交互，且生成的 `.trace` 专有包体体积庞大，无法直接在终端或自动化 Agent 闭环中被解析与消费。

`macOS-Trace` 提供：
- 基于 `xcrun xctrace` 的无头采集流程，支持 `Power Profiler`、`Time Profiler` 与 `Allocations`。
- 基于精确 XPath 选择器的数据表提取机制（如 `ProcessSubsystemPowerImpact`、`all-allocations-summary`）。
- 仅依赖 Python 3 标准库的轻量化分析脚本（零第三方 pip 依赖，任何沙箱环境开箱即用）。
- 差值量化引擎：自动以静置基线为基准，计算指令吞吐速率增量（M/s）、CPU/GPU 能耗 Impact 及堆内存分配速率变化。
- 源自生产环境的实战调优手册：覆盖 CoreAudio/DSP 实时管线、Metal 着色器、WebKit 跨进程桥接及 AppKit/SwiftUI 内存抖动。

---

## 工作流

```text
目标进程 (PID)
      │
      ▼
xcrun xctrace record (无头 Instruments 采集)
      │
      ▼
Trace 产物包 (.trace)
      │
      ▼
xcrun xctrace export (基于 XPath 的数据表提取)
      │
      ▼
结构化 XML 表格
      │
      ▼
macOS-Trace 分析脚本 (Python 3 纯标准库)
      │
      ▼
客观量化报告与基线差值 (M/s 指令、CPU %、Alloc/s)
```

---

## 快速上手

使用内置脚本 `scripts/run_trace.sh`，一行命令完成采集、导出与量化解析：

```bash
# 1. 采集 60 秒应用静置基线：
./scripts/run_trace.sh --process "MyApp" --template power --duration 60s --label "01-idle-base"

# 2. 在应用中触发目标业务负载，采集 60 秒高负载场景：
./scripts/run_trace.sh --process "MyApp" --template power --duration 60s --label "02-active-workload"

# 3. 对比两轮测试，计算相对基线的真实净开销：
python3 scripts/compare_elements.py \
  /tmp/macos-traces/01-idle-base-power.xml:"静置基线" \
  /tmp/macos-traces/02-active-workload-power.xml:"业务负载"
```

输出示例：
```text
Scenario                    Sec  CPU Avg  CPU Max  Display  GPU Avg  Total Instr    Instr M/s
============================================================================================
静置基线                     60     0.15     0.80     0.05     0.00        1.02G         17.0
业务负载                     60     1.85     3.40     0.90     1.20       12.60G        210.0
--------------------------------------------------------------------------------------------
Differential vs Baseline [静置基线]:
  业务负载                     +193.0 M/s instructions, CPU Avg Delta +1.70
```

---

## 安装指南

### 项目级集成（推荐）

直接克隆至目标工程的 Agent Skills 目录，Claude Code、Codex、Cursor 与 Antigravity 即可自动识别：

```bash
# 标准 Agent Skills 目录 (.agents/skills)
git clone https://github.com/kmgcc/macOS-Trace.git .agents/skills/macos-trace

# Codex 项目目录 (.codex/skills)
git clone https://github.com/kmgcc/macOS-Trace.git .codex/skills/macos-trace

# 或作为 Git Submodule 引入
git submodule add https://github.com/kmgcc/macOS-Trace.git .agents/skills/macos-trace
```

### 全局安装

```bash
# Claude Code / Cursor / Antigravity 全局技能目录
mkdir -p ~/.agents/skills
git clone https://github.com/kmgcc/macOS-Trace.git ~/.agents/skills/macos-trace

# Codex 全局技能目录
mkdir -p ~/.codex/skills
git clone https://github.com/kmgcc/macOS-Trace.git ~/.codex/skills/macos-trace
```

---

## 内置工具与脚本

所有脚本要求 Python 3.8+，**仅使用标准库**（`re`、`sys`、`os`、`xml.etree.ElementTree`、`collections`），无需配置虚拟环境或安装任何第三方包。

| 脚本 | 功能说明 | 常用命令示例 |
| :--- | :--- | :--- |
| `scripts/run_trace.sh` | 自动化终端入口：一键完成录制、XML 导出与解析 | `./scripts/run_trace.sh --process MyApp --template power` |
| `scripts/compare_elements.py` | 多场景横向对比表生成与基准差值（Delta）计算 | `python3 scripts/compare_elements.py base.xml active.xml` |
| `scripts/parse_power.py` | 单次 Power Profiler 导出的功耗、GPU 及指令速率深度解析 | `python3 scripts/parse_power.py run-power.xml "测试场景"` |
| `scripts/top_categories.py` | Allocations 堆内存高频分配速率与常驻/瞬时内存分析 | `python3 scripts/top_categories.py alloc.xml 60 10.0` |

---

## 常用 Instruments 模板

| 模板名称 | 简写参数 | 核心量化指标与适用场景 |
| :--- | :--- | :--- |
| `Power Profiler` | `power` | 每秒指令吞吐（M/s）、CPU/GPU/Display 功耗 Impact（`ProcessSubsystemPowerImpact`）。A/B 对比首选。 |
| `Time Profiler` | `time` | 各线程 CPU 权重占比、调用栈热点（Call-tree）、主线程卡顿分析。 |
| `Allocations` | `alloc` | 堆内存分配速率、瞬时内存波峰、分类事件频次（`all-allocations-summary`）。 |
| `Leaks` | `leaks` | 失去父级引用的内存泄漏、循环引用（Retain Cycles）。 |
| `Metal System Trace` | `metal` | GPU Encoder 执行耗时、片元/顶点着色器负载、帧边界渲染延迟。 |

---

## 核心子系统调优实战

完整实操规则详见 [SKILL.md](SKILL.md)：

1. **实时音频与 DSP（CoreAudio / AVAudioEngine）**：
   - 音频回调硬性原则：`AURenderCallback` 与 `AVAudioNodeTap` 严禁在实时线程申请堆内存（`malloc`、数组重分配、对象创建）或持有阻塞互斥锁。
   - 频谱计算解耦：使用预分配无锁环形缓冲区（Ring Buffer）将音频帧转入后台线程，UI 频谱仪表刷新强制节流至 30~60Hz。
2. **Metal 着色器与视觉特效**：
   - Retina 视网膜像素陷阱：4K/5K 屏幕存在 2x/3x 缩放倍率，全屏后处理着色器每帧需处理上千万像素。GPU 负载偏高时优先采用降采样离屏纹理渲染。
   - 窗口遮挡休眠：监听 `NSWindow.occlusionState`，当窗口最小化或完全被其他应用覆盖时，主动暂停 `MTKView` 渲染与 `CVDisplayLink`。
3. **WebKit 跨进程混合架构**：
   - 规避 IPC 消息过载：避免以 100Hz 的频率通过 `evaluateJavaScript` 传递大体积 JSON。改由 Swift 推送稀疏同步时间锚点（如 1Hz），前端内部通过 `requestAnimationFrame` 驱动平滑过渡。
   - DOM 重排优化：歌词滚动与高亮严禁频繁修改 `top`、`margin` 或 `height`，统一采用 CSS `transform: translateY()` 与 `opacity`。
4. **桌面 UI 与大图内存治理**：
   - 杜绝大图直接解码：3000x3000px 专辑封面未压缩位图常驻内存单张即达 36MB，引发明显锯齿波峰。必须使用 `CGImageSourceCreateThumbnailAtIndex` 按视图实际像素降采样解码。
   - SwiftUI 级联刷新：排查根视图不当 `@Observable` 触发的整棵视图树 body 重算。

---

## 环境要求

- macOS 12.0 (Monterey) 或更高版本。
- Xcode 命令行工具 (`xcode-select --install`)。
- Python 3.8+ (macOS 系统自带)。

---

## 开源协议

基于 [MIT License](LICENSE) 开源。
