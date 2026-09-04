# macOS-Trace

[English](README.md) | [中文](README_zh.md)

[![Agent Skills Open Standard](https://img.shields.io/badge/Agent_Skills-Open_Standard-blueviolet.svg)](https://agentskills.io)
[![Platform](https://img.shields.io/badge/Platform-macOS_12%2B-black.svg)](https://developer.apple.com/macos/)
[![Tooling](https://img.shields.io/badge/Xcode-Instruments_%2F_xctrace-007AFF.svg)](https://developer.apple.com/xcode/)
[![Python](https://img.shields.io/badge/Python-3.8%2B_(Zero_Deps)-3776AB.svg)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> 如需对 iOS 及 iPadOS 应用（真机与模拟器）进行性能分析，请参考 [iOS-Trace](https://github.com/kmgcc/iOS-Trace)。

基于 `xctrace` 与 Xcode Instruments 的 **macOS 原生应用全自动闭环性能调优引擎**。

专为 **AI 编码 Agent**（Claude Code、OpenAI Codex、Cursor、Google Antigravity、GitHub Copilot）及 **macOS 研发工程师** 设计。彻底告别繁琐的手动 Instruments GUI 操作与生硬庞杂的数据界面。用户仅需对 Agent 提出调优需求，Agent 即可自主完成**目标对齐、无头诊断定位、源码定向修改、复测复盘量化对比**的全闭环，并支持自动多轮迭代，直到达到性能指标。

---

## 自动化性能调优闭环

```text
+-------------------------------------------------------------------------+
|                       全自动闭环性能调优链路                             |
|                                                                         |
|  1. 需求与目标对齐 ──> 2. 无头诊断与归因 ──> 3. 源码定向修改            |
|         ^                                                 │             |
|         │                                                 ▼             |
|         └────── 未达标自动发起下一轮迭代 <── 4. 复测验证与差值复盘       |
+-------------------------------------------------------------------------+
```

1. **需求与目标对齐**：Agent 开始前主动向用户提问（通过 Agent 交互式弹窗/选项组件或直接对话），确认优化目标并给出专业建议默认值。
2. **无头诊断与归因**：采集静置基线与高负载样本，无头提取 XML 表格，精准定位热点调用栈、高频堆分配或掉帧瓶颈。
3. **源码定向修改**：Agent 直接在工程源码中实施最小、精确的性能修复。
4. **复测验证与差值复盘**：在完全相同的测试环境下自动重新跑 Trace，输出优化前后（Before vs After）的客观差值对比表。
5. **决策门禁（Iteration Gate）**：若达标则向用户汇报量化成果并结项；若未达标则自动定位剩余瓶颈并进入下一轮调优，直至满足用户需求。

---

## 启动前目标对齐（问卷与建议值）

在采集 Trace 与修改代码前，Agent 应先向用户确认调优预期：

- **交互提问组件优先**：若当前 Agent 宿主平台提供交互式表单/弹窗组件（如 `ask_question`、选项列表等），优先调用该组件让用户选择；若不支持，则直接在对话中以结构化形式提问。
- **推荐参考指标（建议值）**：
  - **CPU 与能耗控制**：
    - *静止基线目标*：指令速率 < 20 M/s，CPU Impact < 0.5。
    - *业务负载目标*：指令速率 < 100 M/s，或相对优化前 CPU 降低 30% ~ 50%。
  - **内存占用控制**：
    - *常驻物理内存上限*：工具/音频类应用 < 150 MB，富文本/媒体类应用 < 300 MB。
    - *稳态分配事件速率*：稳态运行时每秒分配事件 < 500 events/s。
    - *内存泄漏*：0 处孤立内存泄漏。
  - **界面流畅度与掉帧**：
    - *卡顿率（Hitch Ratio）*：< 5.0 ms/s（良好），< 1.0 ms/s（极致丝滑，无感知掉帧）。
  - **冷启动耗时**：
    - *首帧呈现耗时*：< 400 ms（优秀），< 800 ms（良好）。

---

## Agent 执行铁律（红线规则）

1. **涉及 UI/视觉效果或软件核心行为时，绝不可擅自优化掉**：
   - 若某项优化涉及视觉渲染（如磨砂玻璃材质、动态阴影、平滑帧动效、转场）或应用关键逻辑，**严禁 Agent 自作主张直接剔除或降级**。
   - **必须向用户正式询问是否允许**，并明确说明修改前后的视觉变化、占用资源的原因以及预期的性能收益（例如：“移除实时背景模糊预计可将 GPU Impact 从 1.5 降至 0.2，并节省约 50 M/s CPU 指令”）。
2. **优化务必抓主要矛盾（抓重点）**：
   - 严禁在几十个无辜的底层工具函数上做无意义的微优化。必须先通过诊断定位出真正的第一耗能根因（如多 surface 重复实例化、高频定时器全局重算、未缓冲的频繁 I/O），并将精力集中在主要矛盾上。
3. **严格控制上下文预算，谨慎读取结果数据**：
   - 原始 `.trace` 文件与导出的未解析 XML 动辄几十上百兆，直接读取或转储将**瞬间撑爆 Agent 上下文**导致任务中断。必须始终通过内置 Python 脚本进行流式提取、Top 排序与差异摘要后再行分析。

---

## 前置条件与适用范围

在部署或调用本 Skill 前，请仔细阅读以下系统要求与约束：

### 支持的目标类型
- **仅支持 macOS 原生应用**：专门针对 macOS 桌面端软件（SwiftUI、AppKit、Metal、CoreAudio / AVAudioEngine、WebKit 宿主应用及原生编译型 CLI 二进制程序）。
- **不支持的平台**：不支持 iOS 模拟器、远端 iPhone/iPad 真机、watchOS/tvOS，亦不支持在独立外部浏览器中运行的纯前端 Web 应用。

### 系统与工具链要求
- **操作系统**：macOS 12.0 (Monterey) 或更高版本。
- **Xcode 与 xctrace**：必须安装完整 Xcode 或包含 `xctrace` 工具的 Xcode 命令行工具（`xcrun xctrace version`）。
- **硬件指标支持**：`Power Profiler` 模板与底层子系统能耗 Impact 计数器（`ProcessSubsystemPowerImpact`）依赖 Apple Silicon（M1/M2/M3/M4 系列芯片）。
- **进程权限要求**：Debug 模式需包含 `com.apple.security.get-task-allow` 签名权限才能通过 `--attach <PID>` 附加采样。
- **Python 环境**：Python 3.8+（macOS 系统自带，仅依赖内置标准库，零 pip 安装）。

---

## AI Agent 安装与集成指南

### 1. 技能目录识别规范

```bash
# Agent Skills 目录优先级探测顺序：
# 1. 开放标准目录：  .agents/skills/
# 2. OpenAI Codex：  .codex/skills/
# 3. Cursor：        .cursor/skills/
# 4. Claude Code：   .claude/skills/
```

若不存在上述目录，默认新建 `.agents/skills/`。

### 2. Agent 安装命令

```bash
# 推荐：安装到项目标准 Agent Skills 目录
mkdir -p .agents/skills
git clone https://github.com/kmgcc/macOS-Trace.git .agents/skills/macos-trace

# 方式二：作为 Git Submodule 引入
git submodule add https://github.com/kmgcc/macOS-Trace.git .agents/skills/macos-trace

# 方式三：安装到 Codex 专用目录
mkdir -p .codex/skills
git clone https://github.com/kmgcc/macOS-Trace.git .codex/skills/macos-trace

# 方式四：用户级全局安装
mkdir -p ~/.agents/skills
git clone https://github.com/kmgcc/macOS-Trace.git ~/.agents/skills/macos-trace
```

### 3. 完整调优运行示例

```bash
APP_NAME="YourApp"
PID=$(pgrep -x "$APP_NAME")
SKILL_DIR=".agents/skills/macos-trace"

# 1. 采集 60 秒静置基线：
"$SKILL_DIR/scripts/run_trace.sh" --process "$PID" --template power --duration 60s --label "01-baseline"

# 2. 采集优化前业务高负载样本：
"$SKILL_DIR/scripts/run_trace.sh" --process "$PID" --template power --duration 60s --label "02-pre-opt"

# 3. 实施代码优化并重新构建后，采集优化后高负载样本：
"$SKILL_DIR/scripts/run_trace.sh" --process "$PID" --template power --duration 60s --label "03-post-opt"

# 4. 横向对比优化前后数据：
python3 "$SKILL_DIR/scripts/compare_elements.py" \
  /tmp/macos-traces/01-baseline-power.xml:"静置基线" \
  /tmp/macos-traces/02-pre-opt-power.xml:"优化前高负载" \
  /tmp/macos-traces/03-post-opt-power.xml:"优化后高负载"
```

输出示例：
```text
Scenario                    Sec  CPU Avg  CPU Max  Display  GPU Avg  Total Instr    Instr M/s
============================================================================================
静置基线                     60     0.15     0.80     0.05     0.00        1.02G         17.0
优化前高负载                 60     2.40     4.80     1.10     1.50       16.20G        270.0
优化后高负载                 60     0.65     1.20     0.25     0.10        4.80G         80.0
--------------------------------------------------------------------------------------------
Differential vs Baseline [静置基线]:
  优化前高负载                 +253.0 M/s instructions, CPU Avg Delta +2.25
  优化后高负载                  +63.0 M/s instructions, CPU Avg Delta +0.50
```

---

## 内置工具与脚本

所有脚本要求 Python 3.8+，**仅使用标准库**（`re`、`sys`、`os`、`xml.etree.ElementTree`、`collections`），零任何第三方依赖。

| 脚本 | 功能说明 | 常用命令示例 |
| :--- | :--- | :--- |
| `scripts/run_trace.sh` | 终端自动化入口：一键完成录制、XML 导出与解析 | `./scripts/run_trace.sh --process MyApp --template power` |
| `scripts/compare_elements.py` | 多场景横向对比表生成与基准差值（Delta）计算 | `python3 scripts/compare_elements.py base.xml pre.xml post.xml` |
| `scripts/parse_power.py` | 单次 Power Profiler 导出的功耗、GPU 及指令速率深度解析 | `python3 scripts/parse_power.py run-power.xml "测试场景"` |
| `scripts/top_categories.py` | Allocations 堆内存高频分配速率与常驻/瞬时内存分析 | `python3 scripts/top_categories.py alloc.xml 60 10.0` |

---

## 常用 Instruments 模板

本工具链原生支持以下标准 Instruments 模板（可通过 `scripts/run_trace.sh` 简写参数直接调用）：

### 计算与能耗基线 (Compute & Energy)
| 模板名称 | 简写参数 | 核心量化指标 | 适用诊断场景 |
| :--- | :--- | :--- | :--- |
| `Power Profiler` | `power` | 每秒指令吞吐（M/s）、CPU/GPU/Display 功耗 Impact（`ProcessSubsystemPowerImpact`）。 | 客观 A/B 调优对比、整机能耗与发热排查。 |
| `Time Profiler` | `time` | 各线程 CPU 权重占比、调用栈热点（Call-tree）、主线程耗时方法。 | CPU 占满、高频计算、热点调用栈定位。 |
| `CPU Counters` | `counters` | IPC（每周期指令数）、L1/L2 缓存未命中、分支预测失败率。 | 底层密集型算法（DSP/编解码）性能瓶颈诊断。 |

### 界面流畅度与渲染耗时 (UI & Rendering)
| 模板名称 | 简写参数 | 核心量化指标 | 适用诊断场景 |
| :--- | :--- | :--- | :--- |
| `Animation Hitches` | `hitches` | 卡顿时长（Hitch Duration，ms）、卡顿率（Hitch Ratio，ms/s）、掉帧计数。 | 滚动掉帧，精准区分 App 阶段（Commit 延迟）与 Render 阶段（GPU 延迟）。 |
| `SwiftUI` | `swiftui` | View Body 求值次数、State 变更计数、属性修改频次。 | 诊断 SwiftUI 视图树级联重算与无效重绘。 |
| `Metal System Trace` | `metal` | GPU Encoder 耗时、片元/顶点着色器执行时间、帧管线停顿。 | 自定义着色器渲染瓶颈、粒子特效开销与帧同步延迟。 |

### 内存与资源分配 (Memory & Allocations)
| 模板名称 | 简写参数 | 核心量化指标 | 适用诊断场景 |
| :--- | :--- | :--- | :--- |
| `Allocations` | `alloc` | 堆内存分配事件速率、瞬时内存波峰、分类事件频次（`all-allocations-summary`）。 | 高频小对象堆分配、缓冲未复用、大图解码峰值。 |
| `Leaks` | `leaks` | 失去父级引用的孤立内存泄漏、循环引用（Retain Cycles）。 | 排查闭包捕获泄漏与未能正常释放的对象。 |

### 启动与多线程并发 (Startup & Concurrency)
| 模板名称 | 简写参数 | 核心量化指标 | 适用诊断场景 |
| :--- | :--- | :--- | :--- |
| `App Launch` | `launch` | 首帧渲染耗时、`dyld` 动态库加载时间、静态初始化耗时、Runloop 启动延迟。 | 应用冷启动全流程耗时优化（结合 `--launch` 参数）。 |
| `Swift Concurrency` | `concurrency` | Swift Task 状态（创建/挂起/运行）、Actor 重入频次、协作线程池饱和度。 | Swift `async/await` 协程饥饿、长时间挂起与 Actor 争用。 |
| `System Trace` | `sys` | 线程状态机转换（Running、Blocked on mutex、Waiting、Preempted）、系统调用。 | **“CPU 占用极低但界面完全卡死”**的根因排查（互斥锁争用或 I/O 阻塞）。 |

### 存储与音频 (I/O & Audio)
| 模板名称 | 简写参数 | 核心量化指标 | 适用诊断场景 |
| :--- | :--- | :--- | :--- |
| `File Activity` | `files` / `io` | 文件 Open/Read/Write/Close 调用频次、I/O 延迟、吞吐量。 | 磁盘 I/O 瓶颈、数据库（SwiftData/SQLite）卡死、大量文件扫描。 |
| `Audio System Trace` | `audio` | CoreAudio HAL IO 线程抖动、音频缓冲区溢出/下溢（XRuns/Glitches）。 | 音频播放爆音、断流与实时音频调度超时。 |

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
