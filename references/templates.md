# Instruments Template Reference (macOS)

Load this file when you need to pick the right Instruments template for a specific
bottleneck. Each template is supported via `scripts/run_trace.sh --template <short>`
and headless `xctrace`.

## Compute & Energy

| Template | Short Name | Target Metrics & Export Schema | Use Case |
| :--- | :--- | :--- | :--- |
| `Power Profiler` | `power` | Instructions/sec (M/s), CPU/GPU/Display energy impacts (`ProcessSubsystemPowerImpact`). | Objective A/B benchmarking and power efficiency testing. |
| `Time Profiler` | `time` | CPU sample weights by thread, call-tree hotspots, main-thread blocking methods. | High CPU utilization, runaway threads, and hot function paths. |
| `CPU Counters` | `counters` | IPC (instructions per cycle), L1/L2 cache misses, branch mispredictions. | Low-level computational and DSP algorithm performance bottlenecks. |

## UI Responsiveness & Smoothness

| Template | Short Name | Target Metrics & Export Schema | Use Case |
| :--- | :--- | :--- | :--- |
| `Animation Hitches` | `hitches` | Hitch duration (ms), hitch ratio (ms/s), frame drops, app vs render phase latency. | Scrolling stutter, dropped animation frames, and CoreAnimation commit delays. |
| `SwiftUI` | `swiftui` | View body evaluations, State invalidation counts, view update frequency. | Unnecessary view re-evaluations and state invalidation cascades. |
| `Metal System Trace` | `metal` | GPU encoder time, vertex/fragment shader durations, frame boundary latency. | Shader execution bottlenecks, particle FX overhead, and render pipeline stalls. |

## Memory & Allocations

| Template | Short Name | Target Metrics & Export Schema | Use Case |
| :--- | :--- | :--- | :--- |
| `Allocations` | `alloc` | Heap allocations, transient vs persistent memory, category event rates (`all-allocations-summary`). | High-frequency temporary allocations, memory spikes, and buffer thrashing. |
| `Leaks` | `leaks` | Retained memory leaks that outlive parent lifecycle, reference cycles. | Abandoned memory, closure capture leaks, and unreleased delegate cycles. |

## Startup & Concurrency

| Template | Short Name | Target Metrics & Export Schema | Use Case |
| :--- | :--- | :--- | :--- |
| `App Launch` | `launch` | Time to first frame, `dyld` loading time, static initializers, runloop setup. | Cold start optimization (`--launch -- <binary_path>`). |
| `Swift Concurrency` | `concurrency` | Swift Tasks (created/running/suspended), Actor reentrancy, cooperative pool usage. | `async/await` starvation, actor contention, and long-suspended tasks. |
| `System Trace` | `sys` | Thread state transitions (Running, Blocked on mutex, Waiting, Preempted), syscalls. | Low CPU usage but frozen/unresponsive UI (lock contention or I/O waits). |

## I/O & Audio

| Template | Short Name | Target Metrics & Export Schema | Use Case |
| :--- | :--- | :--- | :--- |
| `File Activity` | `files` / `io` | File open/read/write/close calls, I/O latency, throughput. | Disk I/O bottlenecks, database (SwiftData/SQLite) stalls, and asset loading. |
| `Audio System Trace` | `audio` | CoreAudio HAL IO thread jitter, audio buffer overruns/underruns (XRuns/glitches). | Audio dropouts, buffer underruns, and real-time audio pipeline instability. |
