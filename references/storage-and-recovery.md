# Trace Storage and Recovery

Load this reference when a recording grows rapidly, the temporary volume loses space, `xctrace` remains alive after its time limit, or disk space does not return after a run.

## Before recording

- Check free space on the output volume and on the actual temporary volume. `TMPDIR` is a useful starting point, but Instruments services may use another path; inspect open files during a short capture before relying on a temporary-directory override.
- Start with a short recording when the instrument or workload has not been measured on this machine. Observe the trace bundle and free space while recording. Choose a storage reserve for the actual volume and workload; stop the capture before it consumes that reserve.
- `--time-limit` bounds the recording interval. It does not cap bytes or guarantee that the `xctrace` command exits as soon as the interval ends. Watch the recorder through finalization and set a reasonable completion deadline for the task.
- `--output` chooses the final `.trace` destination; it does not guarantee that intermediate files or service caches use that volume.
- Setting `TMPDIR` for `xctrace` may redirect some temporary files, but do not assume it changes paths used by `DTServiceHub` or other Instruments services. Confirm the live path with `lsof` and `df` before treating an external volume as protection for the internal disk.
- Before exporting a large table, check free space on the export volume, narrow the selection to the required table/time range, and monitor the output file. Do not start another export while a deleted-open `.ktrace` still consumes space.

## Check for deleted files still holding disk space

After the recorder exits, inspect open files with a link count below one:

```bash
lsof -nP +L1 2>/dev/null | grep -E 'DTServiceHub.*ktrace|ktrace.*DTServiceHub'
```

`+L1` selects files whose directory entry has been removed while a process still has the file open. Record each matching PID, path, and size. Confirm the process executable and start time with `ps -p <PID> -o pid=,lstart=,command=`. Check for other active `xctrace` or Instruments recordings before stopping a shared service.

If the exact `DTServiceHub` PID is holding a deleted `.ktrace` and no active recording depends on it, ask that PID to exit and verify whether the handle closes:

```bash
kill -TERM <PID>
sleep 3
lsof -nP +L1 2>/dev/null | grep -E 'DTServiceHub.*ktrace|ktrace.*DTServiceHub'
```

Only if the same verified stale PID still holds the deleted trace, escalate against that PID:

```bash
kill -KILL <PID>
```

Do not use `killall -9 DTServiceHub` as routine cleanup. The service may own another active recording. Do not kill by name when the PID, executable, open file, and recording state have not been checked. A deleted file releases its blocks when the last open handle closes; verify that free space returned with `df -h <temporary-volume>`.

## Clean named temporary files and caches

- Do not run a global `find ... -delete` for `instruments*.ktrace`. First confirm the recorder is finished, identify the specific files created by this run, and check whether any process still has them open. Remove only the exact stale paths that are not needed as evidence.
- Do not remove the entire `com.apple.dt.InstrumentsCLI` cache automatically. Inspect its size and contents, confirm no Instruments activity is using it, and clean it only when the files are verified as disposable. Cache cleanup is separate from releasing deleted-open file descriptors.
- After cleanup, check the recorder and service processes, rerun `lsof +L1`, and compare free space on the same volume. Report the observed values; do not infer reclaimed space from a successful `rm` alone.

## If the recorder does not finish

Keep the target app alive unless the user or project instructions say otherwise. Record the exact `xctrace` PID, executable, template, output path, time limit, and observed growth. Stop only the recorder process started for this run when its completion deadline passes or it threatens the selected storage reserve. Then inspect `DTServiceHub` handles as above before deciding whether the service is stale. Preserve an incomplete trace for diagnosis until its value and retention are clear.
