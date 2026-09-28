---
name: macos-trace
description: "Agent-native runbook for evidence-based profiling and optimization of native macOS apps with xctrace and Xcode Instruments. Use when investigating CPU or energy use, memory growth or leaks, UI hitches, slow launch, concurrency stalls, audio dropouts, or thermal behavior. Selects tools and workload reproduction to fit the reported issue; scripts are optional helpers."
compatibility: "macOS with Xcode or Xcode Command Line Tools providing xctrace; Python 3.8+ only for optional helper scripts"
license: MIT
metadata:
  author: kmgcc
  version: "1.6.0"
---

# macOS-Trace

An agent-native runbook for investigating performance in native macOS apps. Use judgment to choose the smallest useful measurement, reproduce the user's real workload, interpret the trace, and verify any change. `xctrace` and Instruments are the measurement tools; bundled scripts are optional helpers for repeatable exports and comparisons, not a required workflow.

## Runbook

1. **Understand the report.** Identify the affected app, user-visible symptom, reproduction steps, environment, and what evidence would show improvement. Ask only for missing details that materially change the measurement. Do not impose generic numeric targets or assume that every report needs an optimization loop.
2. **Inspect the actual target and tools.** Read the repository's agent instructions. Establish the exact app process, binary/build, macOS and hardware, active Xcode selection, and `xctrace` version. Check the installed template/instrument names and relevant CLI help before recording; Xcode and OS versions expose different capabilities. Never start or stop an app process without following the repository's process and data-safety rules.
3. **Choose a measurement for a hypothesis.** Consult `references/templates.md` and select the least intrusive instrument or combination that can distinguish likely causes. Discover recording options from the installed tool instead of assuming fixed template aliases or options. Use GUI Instruments when its timelines, inspectors, or comparison views make the evidence clearer; use CLI capture/export when that is more direct.
4. **Reproduce the real workload.** Use `references/workload-reproduction.md` when interaction or timing matters. Prefer the user's actual active scenario for acceptance. Decide whether automation, a launch hook, or a user-triggered interaction is trustworthy for this particular app; do not force a universal tier or treat an ignored launch argument as a successful run. An idle capture is an optional control, not a substitute for the workload. Keep compared runs aligned on build, hardware, OS, window state, inputs, and capture scope, and note unavoidable differences.
5. **Capture only useful evidence.** Attach to the correct process or launch the intended binary as the question requires. Keep a rendering workload visible when frame or GPU behavior matters. Start with a short capture when storage behavior is unknown, and monitor both the output and the actual temporary volume during recording. A time limit is not a byte limit or a guarantee that finalization will finish promptly. Load `references/storage-and-recovery.md` when a trace grows unexpectedly, the recorder stays alive after its limit, or Instruments temporary data may be retained. Store traces in a task-appropriate location; treat traces and exports as potentially sensitive. Do not print entire trace bundles or huge exports into chat.
6. **Interpret before editing.** Connect the symptom to the relevant track, interval, task, thread, allocation, wait, or call tree. Cross-check a suspected hot path against source and call sites. Separate observed evidence from inference and avoid changing code when the trace does not support a specific hypothesis.
7. **Make a focused change and compare.** Follow project instructions for edits and validation. Re-run the same meaningful user scenario with comparable capture settings and compare before/after evidence. Use an idle or unrelated scenario only as a control when it answers a separate question. If evidence is noisy or the result is inconclusive, explain the limit and refine the measurement rather than claiming success.
8. **Report and preserve.** Summarize the scenario, instruments, build/environment, observed bottleneck, change, measured result, and unverified layers. After recording, verify that the recorder exited, check for deleted-but-open `.ktrace` files, and confirm reclaimed space on the affected volume. Preserve requested traces; remove only intermediates identified as belonging to this run. Follow `references/storage-and-recovery.md` for stale `DTServiceHub` handles and never use broad temporary-file cleanup.

## Xcode 27 and Instruments

When Xcode 27 is installed, load `references/templates.md` for its new instruments and recording workflow. Capabilities depend on the installed Xcode and target OS; discover them at runtime. In particular, Swift Executors details require OS 27, and the Foundation Models instrument is for Apple's Foundation Models framework, not a generic profiler for remote model providers.

For optional Xcode coding/build/test integration through MCP, load `references/xcode-agent-mcp.md`. MCP complements profiling; it does not replace Instruments traces. Do not enable an MCP server or widen its permissions as an implicit profiling step.

## Optional helpers

- Use a bundled script only if it fits the question or provides a repeatable export/comparison that is otherwise tedious. Resolve the skill directory dynamically and inspect the script's usage first.
- Never edit scripts inside the installed skill. If a task truly needs a one-off parser change, copy only the relevant helper to a task scratch directory and adapt the copy.
- For an existing project-specific profiler workflow, follow its instructions and data/process ownership boundaries before using generic examples here.

## References (load as needed)

- `references/templates.md` — choose Instruments by symptom; includes Xcode 27 additions.
- `references/workload-reproduction.md` — selecting and validating a real workload reproduction path.
- `references/device-commands.md` — process selection, xctrace capability discovery, capture and export.
- `references/storage-and-recovery.md` — temporary-file growth, deleted-open `.ktrace` recovery, and safe post-record cleanup.
- `references/xcode-agent-mcp.md` — optional Xcode 27 MCP integration and safe capability discovery.
- `references/subsystems.md` — optimization patterns for audio, Metal, WebKit, UI, memory, and media decoding.
