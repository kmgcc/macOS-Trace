# Reproducing the Workload

Use this runbook when the report depends on an interaction, launch sequence, playback, import, synchronization, or other timed activity. Pick the reproduction path that measures the thing the user reported.

## Decide how to reproduce it

1. Describe the scenario as observable app state and user actions. Identify the exact interval that should be measured and any external dependencies (media, network, device, account, permissions).
2. Choose a trustworthy path for this app: a user-triggered run, accessibility-driven interaction, a supported launch/configuration hook, a project test/benchmark, or an existing automation flow. A launch argument is useful only if the app consumes it and it exercises the relevant work.
3. Prefer the least intrusive path that retains the reported behavior. Use manual interaction when automation changes timing, misses an interaction, cannot access the needed state, or the user wants to operate the app. Ask for user input only when a required action or state cannot be established safely by the agent.
4. Confirm the action actually happened and the target process is the one being recorded. Use app state, logs, a visual/accessibility observation, or trace markers as appropriate; a successful automation command alone is not proof.
5. For a before/after comparison, repeat the same path and scenario. Keep build configuration, hardware, OS, window state, inputs, external conditions, and capture scope comparable. If one cannot be held constant, record the difference and narrow the claim.

An idle run can help answer whether cost persists without interaction, but it is an optional control. It cannot establish that an active playback, scroll, launch, or other reported scenario improved.

## Interaction and window state

- Use accessibility-driven automation when its actions match the real user flow and the app exposes stable controls. Read the current UI state before choosing elements; do not guess coordinates or identifiers.
- Use coordinate-driven automation only when necessary and verify the window geometry and scaling first.
- Keep the target window in the foreground for measurements of rendering, animation, or GPU work. Note when the task legitimately occurs in the background.
- Use app-provided scenario hooks or benchmarks for repeatability when they exercise the same work. Distinguish a steady-state measurement from gesture, launch, or end-to-end interaction cost.
- If manual timing is unavoidable, coordinate the start/stop points and repeat enough runs to understand variation. Do not overstate precision from a single human-timed sample.

## Recording design

Choose duration from the behavior: include warm-up if the user experiences it, enough repeated cycles to observe a stable pattern, and stop before unrelated work dominates. For transient issues, include the trigger and aftermath. For growth or leak questions, include repeated lifecycle events and inspect retention after the lifecycle boundary. Use signposts or app logs when they materially improve event alignment.

During analysis, align the trace interval with the verified scenario. If the app was idle, the interaction failed, or the wrong process was captured, discard the run as evidence and fix the reproduction before diagnosing code.
