# Process and xctrace Reference

Load when choosing a target process, recording mode, or export path. Prefer commands reported by the active Xcode installation; examples below illustrate intent and may need adjustment to local CLI syntax.

## Discover the current toolchain

- Check the selected Xcode and `xctrace` versions before relying on an Instruments 27 feature. Multiple Xcode installations may expose different capabilities.
- Inspect `xcrun xctrace list templates`, `xcrun xctrace record --help`, and `xcrun xctrace export --help`. For Xcode 27 recording settings, use `xcrun xctrace record --show-recording-options` with the relevant template/instrument form shown by the installed help.
- Verify the target OS and hardware before interpreting instrument availability or counters. Power and energy metrics vary by hardware and OS; do not infer unavailable values.
- Check whether an instrument supports attaching, launching, a specific device, or only some target types. Let help and the selected template determine valid options.

## Select and verify the target

- Identify the app's exact process name, PID, executable path, and build. When multiple instances exist, inspect each candidate rather than attaching to the newest match by default.
- Choose attach for an already-running workload when that preserves the scenario. Choose profiler-launched execution when launch behavior itself is under test. Follow repository-specific locks, data ownership, signing, and process rules.
- Some hardened or production-signed apps do not allow sampling attachment. Diagnose the permission/signing boundary and use an authorized development build or supported launch mode; do not weaken signing or entitlements silently.
- Verify the process and user scenario during capture. A recorder that exits successfully can still have captured the wrong process or no useful workload.

## Capture and export

Create the output directory and name each trace for the scenario, run phase, and relevant variant. Prefer the CLI when it preserves the question and exact scope; open the trace in Instruments when track relationships, inspectors, or run comparison require visual inspection.

Before passing custom recording options, inspect the template defaults and save only the small reviewed change needed for the question. Before exporting, use the installed export help and narrow the time range, process, table, or fields to the evidence required. Keep raw traces out of chat and treat prompt text, user media metadata, file paths, and logs as sensitive.

If a capture fails, report the exact tool/Xcode version, target, instrument, and relevant diagnostic, then adapt based on the error. Do not blindly retry with a different process, weaker permissions, or a broader capture.

When a recording grows unexpectedly, uses substantial temporary storage, or does not exit after its time limit, load [storage and recovery](storage-and-recovery.md). `--output` selects the final trace location; it does not prove where Instruments services place intermediate files.
