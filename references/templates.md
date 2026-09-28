# Instruments Template Guide

Load when choosing a recording for a specific performance question. Instruments templates and CLI spellings vary with Xcode and OS versions. First inspect the installed catalog (`xcrun xctrace list templates`) and help; use exact names reported by that installation. This guide describes what to look for, not a hardcoded command matrix.

| Question or symptom | Candidate instruments | Evidence to inspect |
| --- | --- | --- |
| CPU work, hot functions, or unexpected wakeups | Time Profiler; CPU Profiler where available | Sample weights by thread, call tree, running intervals, and whether the work overlaps the reported symptom. |
| Energy use or system resource impact | Power Profiler where supported; Time Profiler as attribution | Per-process subsystem impact and hot work during the real workload. Do not infer energy values from CPU samples. |
| Rendering stutter, dropped frames, or slow transitions | Animation Hitches; SwiftUI; Metal System Trace when the GPU is implicated | Hitch intervals and phases; view/layout work; GPU work and frame timing. Keep the affected window visible when rendering is under study. |
| Memory growth, churn, or retained objects | Allocations; Leaks | Live and persistent allocations, allocation backtraces, growth over the scenario, and whether owners outlive their intended lifecycle. A Leaks result alone does not establish bounded memory use. |
| Slow cold launch | App Launch; Time Profiler or signposts for attribution | Launch phases, dyld work, static initialization, first useful frame, and app-specific readiness signal. Keep launch conditions comparable. |
| Async stalls, actor contention, or executor starvation | Swift Concurrency; Swift Executors; Time Profiler or CPU Profiler; System Trace for scheduling evidence | Tasks and actors, wait/suspension intervals, executor queues, thread state and scheduling around the user-visible delay. |
| Locking, I/O, or scheduler delay | System Trace; File Activity; Time Profiler | Thread state transitions, priority, waits, syscalls, file operation latency, and the chain leading to the blocked user-facing work. |
| Audio glitches or real-time callback instability | Audio System Trace; Time Profiler; Allocations when allocation is suspected | I/O thread timing, missed/late work, callback duration, locks, and allocations on real-time paths. |
| Low-level compute or shader cost | CPU Counters where supported; Metal System Trace | Counters and GPU pass/encoder timing tied to the measured workload. Check hardware support before interpreting counters. |
| Apple Foundation Models latency or usage | Foundation Models | Instructions, prompts, responses, token usage, tool activity, and inference latency for calls through Apple's Foundation Models framework. Treat captured prompt/response data as sensitive. |

## Xcode 27 additions

- **Swift Executors**: shows the Cooperative Thread Pool, Main Actor, and custom `TaskExecutor` / `SerialExecutor` implementations. Names are available on OS 27; on earlier systems they may appear as `Unknown executor`.
- **Swift Concurrency + CPU profiling**: recording Swift Concurrency alongside Time Profiler or CPU Profiler enables the `Profile` detail for call trees sampled while tasks are running. Use this when a task/actor timeline needs code-level CPU attribution; it adds recording overhead and should be justified by the question.
- **SwiftUI layout detail**: the SwiftUI instrument exposes more layout-pass information, including why some layout computations were not cached. Use it to investigate repeated layout work, then confirm it overlaps the visible hitch or CPU symptom.
- **System Trace**: combines system calls, VM faults, and thread-state evidence in a unified timeline and adds thread-priority context. Follow scheduling events around the affected thread instead of treating a busy system-wide trace as proof of an app bottleneck.
- **Foundation Models**: this instrument targets Apple's Foundation Models usage. It is not a general profiler for arbitrary cloud APIs, third-party SDKs, or every local model runtime. Prompt and response content can be sensitive.
- **Capture/export improvements**: `xctrace record --show-recording-options` reports the installed template's recording settings; pass a reviewed JSON file through `--recording-options` only when needed. `xctrace export` can restrict the exported time range, and allocation exports can include captured backtraces. Inspect current CLI help because supported options depend on the selected Xcode.
- **Reviewing runs**: Instruments supports side-by-side run comparisons and better summary navigation. Use the UI when a comparison is clearer there; keep the same scenario and inspect run metadata before concluding.

## Selection notes

- Start with one instrument that can confirm or reject the leading hypothesis. Add a second only when it answers a different part of the question (for example, task timeline plus CPU call tree).
- Instrument combinations and options can add overhead or change data volume. Check available recording settings and disclose relevant capture limits.
- A system-wide instrument may be needed for scheduler, audio, energy, or device behavior. Filter interpretation back to the correct process and time interval.
- Do not rely on short example aliases such as `time`, `power`, or `sys` unless the selected helper explicitly maps them to the installed template.
