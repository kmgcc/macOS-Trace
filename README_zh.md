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

## 前置条件与适用范围

在部署或调用本 Skill 前，请仔细阅读以下系统要求与约束：

### 支持的目标类型
- **仅支持 macOS 原生应用**：专门针对 macOS 桌面端软件（SwiftUI、AppKit、Metal、CoreAudio / AVAudioEngine、WebKit 宿主应用及原生编译型 CLI 二进制程序）。
- **不支持的平台**：不支持 iOS 模拟器、远端 iPhone/iPad 真机、watchOS/tvOS，亦不支持在独立外部浏览器中运行的纯前端 Web 应用。

### 系统与工具链要求
- **操作系统**：macOS 12.0 (Monterey) 或更高版本。
- **Xcode 与 xctrace**：必须安装完整 Xcode 或包含 `xctrace` 工具的 Xcode 命令行工具（Command Line Tools）。可通过以下命令验证：
  ```bash
  xcode-select -p
  xcrun xctrace version
  ```
  若未安装，请通过 `xcode-select --install` 安装命令行工具，或从 Mac App Store / Apple Developer 网站下载安装 Xcode。
- **硬件指标支持**：`Power Profiler` 模板与底层子系统能耗 Impact 计数器（`ProcessSubsystemPowerImpact`）依赖 Apple Silicon（M1/M2/M3/M4 系列芯片）。
- **进程权限要求**：当通过 `--attach <PID>` 附加到开启了 Hardened Runtime（强化运行时）的进程时，被测应用必须包含 `com.apple.security.get-task-allow` 签名权限（Debug 模式默认包含）；否则需通过 `--launch` 直接启动二进制文件进行采样。
- **Python 环境**：Python 3.8+（macOS 系统自带）。所有内置脚本均**仅使用标准库**（`re`、`sys`、`os`、`xml.etree.ElementTree`、`collections`），无需配置虚拟环境或安装任何第三方 pip 依赖。

---

## AI Agent 安装与集成指南

本节面向 AI Agent 说明如何在项目自动化流程中安装、定位并正确执行 `macOS-Trace`。

### 1. 技能目录识别规范

当 Agent 需要向当前仓库引入本 Skill 时，应按以下优先级探测项目中已有的技能目录：

```bash
# Agent Skills 目录优先级探测顺序：
# 1. 开放标准目录：  .agents/skills/
# 2. OpenAI Codex：  .codex/skills/
# 3. Cursor：        .cursor/skills/
# 4. Claude Code：   .claude/skills/
```

若当前仓库不存在上述目录，优先创建标准目录 `.agents/skills/`。

### 2. Agent 安装命令

Agent 可根据工作流执行以下任一命令完成引入：

```bash
# 推荐：安装到项目标准 Agent Skills 目录
mkdir -p .agents/skills
git clone https://github.com/kmgcc/macOS-Trace.git .agents/skills/macos-trace

# 方式二：作为 Git Submodule 引入（便于跨仓库版本跟踪）
git submodule add https://github.com/kmgcc/macOS-Trace.git .agents/skills/macos-trace

# 方式三：安装到 Codex 专用目录
mkdir -p .codex/skills
git clone https://github.com/kmgcc/macOS-Trace.git .codex/skills/macos-trace

# 方式四：用户级全局安装（所有工作区通用）
mkdir -p ~/.agents/skills
git clone https://github.com/kmgcc/macOS-Trace.git ~/.agents/skills/macos-trace
```

### 3. Agent 自主执行协议（5 步闭环）

当 Agent 接到“分析应用卡顿/能耗/发热”或“验证优化前后性能”的任务时，必须严格执行以下闭环流程：

```text
第 1 步：验证环境与目标进程存在
   │    检查 xcrun xctrace，通过 pgrep 确认目标 App 处于运行中状态。
   ▼
第 2 步：采集静置基线（Baseline）
   │    窗口保持在前台，业务处于暂停状态。采集 60 秒作为对照基准。
   ▼
第 3 步：触发业务负载并采集高负载场景
   │    在 App 中激活目标动效/音频/运算链路。采集 60 秒作为测试样本。
   ▼
第 4 步：执行差值量化对比
   │    运行 scripts/compare_elements.py 计算：
   │    净开销 Delta = Active - Baseline。
   ▼
第 5 步：向用户交付量化报告
        输出结构化表格，以 M/s 指令增量和 CPU 均值差异为据交付结论。
```

#### 标准命令序列

```bash
# 第 1 步：环境与进程验活
APP_NAME="YourApp"
PID=$(pgrep -x "$APP_NAME")
if [[ -z "$PID" ]]; then
  echo "错误: 未找到正在运行的 $APP_NAME 进程。" >&2
  exit 1
fi

SKILL_DIR=".agents/skills/macos-trace"

# 第 2 步：采集 60 秒静置基线（业务暂停，窗口保持可见）
"$SKILL_DIR/scripts/run_trace.sh" --process "$PID" --template power --duration 60s --label "01-baseline"

# 第 3 步：在 App 中触发目标功能后，采集 60 秒业务负载态
"$SKILL_DIR/scripts/run_trace.sh" --process "$PID" --template power --duration 60s --label "02-active"

# 第 4 步：生成多场景横向对比表并输出相对基线的差值
python3 "$SKILL_DIR/scripts/compare_elements.py" \
  /tmp/macos-traces/01-baseline-power.xml:"1. 静置基线" \
  /tmp/macos-traces/02-active-power.xml:"2. 业务负载"
```

---

## 架构与工作流

```text
目标原生应用 (PID)
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

## 快速上手示例

运行差值对比脚本将输出如下客观量化报告：

```text
Scenario                    Sec  CPU Avg  CPU Max  Display  GPU Avg  Total Instr    Instr M/s
============================================================================================
1. 静置基线                  60     0.15     0.80     0.05     0.00        1.02G         17.0
2. 业务负载                  60     1.85     3.40     0.90     1.20       12.60G        210.0
--------------------------------------------------------------------------------------------
Differential vs Baseline [1. 静置基线]:
  2. 业务负载                  +193.0 M/s instructions, CPU Avg Delta +1.70
```

---

## 内置工具与脚本

所有脚本要求 Python 3.8+，**仅使用标准库**（`re`、`sys`、`os`、`xml.etree.ElementTree`、`collections`），无任何第三方 pip 依赖。

| 脚本 | 功能说明 | 常用命令示例 |
| :--- | :--- | :--- |
| `scripts/run_trace.sh` | 终端自动化入口：一键完成录制、XML 导出与解析 | `./scripts/run_trace.sh --process MyApp --template power` |
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
   - 实时分析解耦：使用预分配无锁环形缓冲区（Ring Buffer）将音频帧派发至后台队列处理，UI 可视化仪表刷新强制节流至 30~60Hz。
2. **Metal 着色器与视觉特效**：
   - Retina 视网膜像素陷阱：4K/5K 屏幕存在 2x/3x 缩放倍率，全屏后处理着色器每帧需处理上千万像素。GPU 负载偏高时优先采用降采样离屏纹理渲染。
   - 窗口遮挡休眠：监听 `NSWindow.occlusionState`，当窗口最小化或完全被其他应用覆盖时，主动暂停 `MTKView` 渲染与 `CVDisplayLink`。
3. **WebKit 跨进程混合架构**：
   - 规避 IPC 消息过载：避免以 100Hz 的频率通过 `evaluateJavaScript` 传递大体积 JSON。改由 Swift 推送稀疏同步时间锚点（如 1Hz），前端内部通过 `requestAnimationFrame` 驱动平滑过渡。
   - DOM 重排优化：高频动态列表或文本滚动动效严禁频繁修改 `top`、`margin` 或 `height`，统一采用 CSS `transform: translateY()` 与 `opacity`。
4. **桌面 UI 与大图内存治理**：
   - 杜绝大图直接解码：高分辨率位图（如 3000x3000px 以上素材图）直接解码为未压缩位图常驻内存单张即可消耗数十兆，引发明显锯齿内存波峰。必须使用 `CGImageSourceCreateThumbnailAtIndex` 按视图呈现尺寸做后台降采样解码。
   - SwiftUI 级联刷新：排查根视图不当 `@Observable` 触发的整棵视图树 body 重算。

---

## 开源协议

基于 [MIT License](LICENSE) 开源。
