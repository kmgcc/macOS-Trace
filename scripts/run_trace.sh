#!/usr/bin/env bash
# macOS-Trace Automation Runner
# Wraps xcrun xctrace record, export, and python parsing into a single command.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="/tmp/macos-traces"
TEMPLATE="Power Profiler"
DURATION="60s"
PROCESS=""
LAUNCH_CMD=""
LABEL=""
AUTO_ANALYZE=1
FINALIZE_TIMEOUT_SECONDS=30
STARTUP_TIMEOUT_SECONDS=30
MIN_FREE_SPACE_GB=10
XCTRACE_PID=""

usage() {
  cat <<EOF
macOS-Trace Automated Runner

Usage:
  $(basename "$0") [options]

Target Selection (Required: choose one):
  -p, --process <name|pid>    Target process name (e.g. 'MyApp', 'Safari') or numeric PID to attach to
  -l, --launch <binary_path>  Launch executable directly instead of attaching

Profiling Options:
  -t, --template <name>       Instruments template. Supports shorthands:
                              power       -> 'Power Profiler' (default)
                              time        -> 'Time Profiler'
                              activity    -> 'Activity Monitor'
                              alloc       -> 'Allocations'
                              leaks       -> 'Leaks'
                              metal       -> 'Metal System Trace'
                              hitches     -> 'Animation Hitches'
                              swiftui     -> 'SwiftUI'
                              concurrency -> 'Swift Concurrency'
                              launch      -> 'App Launch'
                              files | io  -> 'File Activity'
                              sys         -> 'System Trace'
                              audio       -> 'Audio System Trace'
                              counters    -> 'CPU Counters'
                              Or specify any exact Instruments template name.
  -d, --duration <time>       Recording duration limit (default: 60s, e.g. 30s, 120s)
  -o, --output-dir <path>     Directory to save .trace and exported .xml files (default: /tmp/macos-traces)
  --label <text>              Custom label for report (default: process name or scenario)
  --startup-timeout <sec>     Startup allowance before the duration/finalization deadline (default: 30)
  --finalize-timeout <sec>    Stop waiting if xctrace exceeds duration plus startup and finalization grace (default: 30)
  --min-free-space-gb <GB>    Stop the recorder before either monitored volume falls below this reserve (default: 10)
  --no-analyze                Skip automatic XML export and Python analysis

Notes:
  - Power Profiler requires Apple Silicon; energy counters are unavailable on Intel.
  - The runner monitors TMPDIR and OUTPUT_DIR volumes; verify actual Instruments service paths separately.
  - It never deletes shared Instruments temp files or the Instruments CLI cache.
  - Auto-analysis per template: power -> parse_power.py; time -> top_time.py;
    activity -> activity_cpu.py; alloc -> top_categories.py.

Examples:
  # Profile running app for 60s with Power Profiler and parse results:
  $(basename "$0") --process MyApp --template power --duration 60s

  # Profile allocations for 45s:
  $(basename "$0") --process MyApp --template alloc --duration 45s

  # Profile UI animation hitches during UI interactions:
  $(basename "$0") --process MyApp --template hitches --duration 30s

  # Cold-launch binary under Time Profiler for 20s:
  $(basename "$0") --launch /path/to/MyApp.app/Contents/MacOS/MyApp --template time --duration 20s

  # Hot call-trees + per-process CPU fallback:
  $(basename "$0") --process MyApp --template time --duration 60s
  $(basename "$0") --process MyApp --template activity --duration 30s
EOF
  exit 0
}

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--process)
      PROCESS="$2"
      shift 2
      ;;
    -l|--launch)
      LAUNCH_CMD="$2"
      shift 2
      ;;
    -t|--template)
      case "$2" in
        power)       TEMPLATE="Power Profiler" ;;
        time)        TEMPLATE="Time Profiler" ;;
        activity)    TEMPLATE="Activity Monitor" ;;
        alloc)       TEMPLATE="Allocations" ;;
        leaks)       TEMPLATE="Leaks" ;;
        metal)       TEMPLATE="Metal System Trace" ;;
        hitches)     TEMPLATE="Animation Hitches" ;;
        swiftui)     TEMPLATE="SwiftUI" ;;
        concurrency) TEMPLATE="Swift Concurrency" ;;
        launch)      TEMPLATE="App Launch" ;;
        files|io)    TEMPLATE="File Activity" ;;
        sys)         TEMPLATE="System Trace" ;;
        audio)       TEMPLATE="Audio System Trace" ;;
        counters)    TEMPLATE="CPU Counters" ;;
        *)           TEMPLATE="$2" ;;
      esac
      shift 2
      ;;
    -d|--duration)
      DURATION="$2"
      shift 2
      ;;
    -o|--output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --label)
      LABEL="$2"
      shift 2
      ;;
    --finalize-timeout)
      FINALIZE_TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    --startup-timeout)
      STARTUP_TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    --min-free-space-gb)
      MIN_FREE_SPACE_GB="$2"
      shift 2
      ;;
    --no-analyze)
      AUTO_ANALYZE=0
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

if [[ ! "$DURATION" =~ ^([0-9]+)(ms|s|m|h)$ ]]; then
  echo "[ERROR] Duration must be an integer followed by ms, s, m, or h (for example, 30s)." >&2
  exit 1
fi
DURATION_VALUE="${BASH_REMATCH[1]}"
DURATION_UNIT="${BASH_REMATCH[2]}"
case "$DURATION_UNIT" in
  ms) DURATION_SECONDS=$(((DURATION_VALUE + 999) / 1000)) ;;
  s)  DURATION_SECONDS="$DURATION_VALUE" ;;
  m)  DURATION_SECONDS=$((DURATION_VALUE * 60)) ;;
  h)  DURATION_SECONDS=$((DURATION_VALUE * 3600)) ;;
esac

if [[ ! "$FINALIZE_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || (( FINALIZE_TIMEOUT_SECONDS < 1 )); then
  echo "[ERROR] --finalize-timeout must be a positive number of seconds." >&2
  exit 1
fi
if [[ ! "$STARTUP_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || (( STARTUP_TIMEOUT_SECONDS < 1 )); then
  echo "[ERROR] --startup-timeout must be a positive number of seconds." >&2
  exit 1
fi
if [[ ! "$MIN_FREE_SPACE_GB" =~ ^[0-9]+$ ]] || (( MIN_FREE_SPACE_GB < 1 )); then
  echo "[ERROR] --min-free-space-gb must be a positive integer." >&2
  exit 1
fi

# Check prerequisites
if ! command -v xcrun &>/dev/null; then
  echo "[ERROR] 'xcrun' not found. Install Xcode Command Line Tools via: xcode-select --install" >&2
  exit 1
fi

if ! xcrun xctrace version &>/dev/null; then
  echo "[ERROR] 'xctrace' is not functional. Ensure Xcode or Command Line Tools are active." >&2
  exit 1
fi
XCTRACE_BIN="$(xcrun --find xctrace)"
if [[ ! -x "$XCTRACE_BIN" ]]; then
  echo "[ERROR] Could not resolve an executable xctrace binary." >&2
  exit 1
fi

if [[ -z "$PROCESS" && -z "$LAUNCH_CMD" ]]; then
  echo "[ERROR] You must specify either --process <name|pid> or --launch <binary_path>." >&2
  echo "Run '$(basename "$0") --help' for usage." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
SAFE_TEMPLATE=$(echo "$TEMPLATE" | tr -d ' ' | tr '[:upper:]' '[:lower:]')

# Determine target PID if process name was given
TARGET_PID=""
TARGET_NAME=""
if [[ -n "$PROCESS" ]]; then
  if [[ "$PROCESS" =~ ^[0-9]+$ ]]; then
    TARGET_PID="$PROCESS"
    TARGET_NAME="pid$TARGET_PID"
  else
    TARGET_NAME="$PROCESS"
    FOUND_PIDS=($(pgrep -x "$PROCESS" || true))
    if [[ ${#FOUND_PIDS[@]} -eq 0 ]]; then
      FOUND_PIDS=($(pgrep -f "$PROCESS" || true))
    fi

    if [[ ${#FOUND_PIDS[@]} -eq 0 ]]; then
      echo "[ERROR] No running process found matching '$PROCESS'." >&2
      exit 1
    elif [[ ${#FOUND_PIDS[@]} -gt 1 ]]; then
      echo "[WARN] Multiple processes found matching '$PROCESS' (${FOUND_PIDS[*]}). Attaching to latest PID: ${FOUND_PIDS[${#FOUND_PIDS[@]}-1]}"
      TARGET_PID="${FOUND_PIDS[${#FOUND_PIDS[@]}-1]}"
    else
      TARGET_PID="${FOUND_PIDS[0]}"
    fi
  fi
fi

if [[ -z "$LABEL" ]]; then
  LABEL="${TARGET_NAME:-launch}-${SAFE_TEMPLATE}"
fi

TRACE_FILE="${OUTPUT_DIR}/${LABEL}-${TIMESTAMP}.trace"

available_kb() {
  df -Pk "$1" 2>/dev/null | awk 'NR == 2 { print $4 }'
}

report_storage_state() {
  local tmp_free output_free trace_kb
  tmp_free="$(available_kb "$TMP_ROOT")"
  output_free="$(available_kb "$OUTPUT_DIR")"
  trace_kb="$(du -sk "$TRACE_FILE" 2>/dev/null | awk 'NR == 1 { print $1 }')"
  echo "[INFO] Storage state: trace ${trace_kb:-unknown} KiB; TMPDIR free ${tmp_free:-unknown} KiB; output volume free ${output_free:-unknown} KiB"
}

recorder_running() {
  local state
  [[ -n "$XCTRACE_PID" ]] || return 1
  state="$(ps -p "$XCTRACE_PID" -o stat= 2>/dev/null | tr -d '[:space:]')"
  [[ -n "$state" && "$state" != *Z* ]]
}

stop_recorder() {
  [[ -n "$XCTRACE_PID" ]] || return 0
  kill -TERM "$XCTRACE_PID" 2>/dev/null || true
  for _ in 1 2 3 4 5; do
    recorder_running || break
    sleep 1
  done
  if recorder_running; then
    echo "[WARN] xctrace PID $XCTRACE_PID did not stop after SIGTERM; sending SIGKILL to this recorder only." >&2
    kill -KILL "$XCTRACE_PID" 2>/dev/null || true
  fi
  wait "$XCTRACE_PID" 2>/dev/null || true
  XCTRACE_PID=""
}

report_unlinked_ktraces() {
  local matches
  command -v lsof >/dev/null 2>&1 || return 0
  matches="$(lsof -nP +c 0 +L1 2>/dev/null | grep -E 'DTServiceHub.*ktrace|ktrace.*DTServiceHub' || true)"
  if [[ -n "$matches" ]]; then
    echo "[WARN] A DTServiceHub process still holds a deleted .ktrace file:" >&2
    echo "$matches" >&2
    echo "[WARN] Verify the PID and active Instruments sessions; see references/storage-and-recovery.md." >&2
    return 1
  fi
  return 0
}

on_signal() {
  echo "[WARN] Interrupted; stopping only this run's xctrace process." >&2
  stop_recorder
  exit 130
}

TMP_ROOT="${TMPDIR:-/tmp}"
MIN_FREE_KB=$((MIN_FREE_SPACE_GB * 1024 * 1024))
TMP_FREE_KB="$(available_kb "$TMP_ROOT")"
OUTPUT_FREE_KB="$(available_kb "$OUTPUT_DIR")"
if [[ ! "$TMP_FREE_KB" =~ ^[0-9]+$ || ! "$OUTPUT_FREE_KB" =~ ^[0-9]+$ ]]; then
  echo "[ERROR] Could not inspect free space on TMPDIR or OUTPUT_DIR volume." >&2
  exit 1
fi
if (( TMP_FREE_KB < MIN_FREE_KB || OUTPUT_FREE_KB < MIN_FREE_KB )); then
  echo "[ERROR] A monitored volume has less than ${MIN_FREE_SPACE_GB} GB free; refusing to start the recording." >&2
  exit 1
fi

echo "========================================================================"
echo " macOS-Trace Profiling Run"
echo "========================================================================"
echo "  Template:  $TEMPLATE"
echo "  Duration:  $DURATION"
echo "  Min free:  ${MIN_FREE_SPACE_GB} GB on TMPDIR and output volume"
echo "  Deadline:  duration + ${FINALIZE_TIMEOUT_SECONDS} s finalization + ${STARTUP_TIMEOUT_SECONDS} s startup allowance"
echo "  TMP free:  $TMP_FREE_KB KiB"
echo "  Out free:  $OUTPUT_FREE_KB KiB"
echo "  Target:    ${TARGET_NAME:+Process '$TARGET_NAME' (PID $TARGET_PID)}${LAUNCH_CMD:+Binary '$LAUNCH_CMD'}"
echo "  Output:    $TRACE_FILE"
echo "========================================================================"

trap on_signal INT TERM
RECORD_START_SECONDS="$(date +%s)"
TOTAL_TIMEOUT_SECONDS=$((DURATION_SECONDS + FINALIZE_TIMEOUT_SECONDS + STARTUP_TIMEOUT_SECONDS))
if [[ -n "$TARGET_PID" ]]; then
  "$XCTRACE_BIN" record \
    --template "$TEMPLATE" \
    --time-limit "$DURATION" \
    --output "$TRACE_FILE" \
    --attach "$TARGET_PID" &
else
  "$XCTRACE_BIN" record \
    --template "$TEMPLATE" \
    --time-limit "$DURATION" \
    --output "$TRACE_FILE" \
    --launch -- $LAUNCH_CMD &
fi
XCTRACE_PID=$!

LAST_REPORT_SECONDS=0
STOP_REASON=""
while recorder_running; do
  NOW_SECONDS="$(date +%s)"
  ELAPSED_SECONDS=$((NOW_SECONDS - RECORD_START_SECONDS))
  if (( ELAPSED_SECONDS > TOTAL_TIMEOUT_SECONDS )); then
    STOP_REASON="xctrace exceeded the duration plus startup/finalization deadline"
    break
  fi

  TMP_FREE_KB="$(available_kb "$TMP_ROOT")"
  OUTPUT_FREE_KB="$(available_kb "$OUTPUT_DIR")"
  if [[ ! "$TMP_FREE_KB" =~ ^[0-9]+$ || ! "$OUTPUT_FREE_KB" =~ ^[0-9]+$ ]]; then
    STOP_REASON="could not continue checking free space"
    break
  fi
  if (( TMP_FREE_KB < MIN_FREE_KB || OUTPUT_FREE_KB < MIN_FREE_KB )); then
    STOP_REASON="a monitored volume fell below the ${MIN_FREE_SPACE_GB} GB free-space reserve"
    break
  fi

  if (( ELAPSED_SECONDS - LAST_REPORT_SECONDS >= 10 )); then
    TRACE_KB="$(du -sk "$TRACE_FILE" 2>/dev/null | awk 'NR == 1 { print $1 }')"
    echo "[INFO] Recording monitor: elapsed ${ELAPSED_SECONDS}s; trace ${TRACE_KB:-not yet available} KiB; TMPDIR free $((TMP_FREE_KB / 1024 / 1024)) GB; output free $((OUTPUT_FREE_KB / 1024 / 1024)) GB"
    LAST_REPORT_SECONDS="$ELAPSED_SECONDS"
  fi
  sleep 2
done

if [[ -n "$STOP_REASON" ]]; then
  echo "[ERROR] $STOP_REASON; stopping xctrace PID $XCTRACE_PID." >&2
  stop_recorder
  report_storage_state
  report_unlinked_ktraces || true
  echo "[ERROR] The trace may be incomplete. Inspect lsof +L1 and df before another run; do not delete shared temp files." >&2
  exit 124
fi

RECORD_STATUS=0
if wait "$XCTRACE_PID"; then
  RECORD_STATUS=0
else
  RECORD_STATUS=$?
fi
XCTRACE_PID=""
trap - INT TERM
if (( RECORD_STATUS != 0 )); then
  report_storage_state
  report_unlinked_ktraces || true
  echo "[ERROR] xctrace exited with status $RECORD_STATUS; inspect storage state before retrying." >&2
  exit "$RECORD_STATUS"
fi
if ! report_unlinked_ktraces; then
  AUTO_ANALYZE=0
  echo "[WARN] Skipping automatic export until the deleted-open trace handle is resolved." >&2
fi
report_storage_state

echo ""
echo "[INFO] Trace recorded: $TRACE_FILE"

# Post-processing / analysis
if [[ $AUTO_ANALYZE -eq 1 ]]; then
  if [[ "$TEMPLATE" == "Power Profiler" ]]; then
    XML_FILE="${OUTPUT_DIR}/${LABEL}-${TIMESTAMP}-power.xml"
    echo "[INFO] Exporting ProcessSubsystemPowerImpact table to XML..."
    xcrun xctrace export \
      --input "$TRACE_FILE" \
      --xpath "/trace-toc/run[@number='1']/data/table[@schema='ProcessSubsystemPowerImpact']" \
      > "$XML_FILE" 2>/dev/null || {
        echo "[WARN] ProcessSubsystemPowerImpact table not present or export returned non-zero."
      }

    if [[ -f "$XML_FILE" && -s "$XML_FILE" && $(grep -c '<row>' "$XML_FILE" 2>/dev/null || echo 0) -gt 0 ]]; then
      echo "[INFO] Parsing Power Impact metrics..."
      python3 "${SCRIPT_DIR}/parse_power.py" "$XML_FILE" "$LABEL"
    else
      echo "[WARN] Power Profiler produced no data rows (requires Apple Silicon)."
    fi

  elif [[ "$TEMPLATE" == "Time Profiler" ]]; then
    XML_FILE="${OUTPUT_DIR}/${LABEL}-${TIMESTAMP}-time.xml"
    echo "[INFO] Exporting time-profile table to XML..."
    xcrun xctrace export \
      --input "$TRACE_FILE" \
      --xpath "/trace-toc/run[@number='1']/data/table[@schema='time-profile']" \
      > "$XML_FILE" 2>/dev/null || {
        echo "[WARN] time-profile table not present or export returned non-zero."
      }

    if [[ -f "$XML_FILE" && -s "$XML_FILE" && $(grep -c '<row>' "$XML_FILE" 2>/dev/null || echo 0) -gt 0 ]]; then
      echo "[INFO] Parsing top CPU functions (top 25, leaf-attributed)..."
      python3 "${SCRIPT_DIR}/top_time.py" "$XML_FILE" 25 --leaf
    else
      echo "[WARN] Time Profiler produced no data rows."
    fi

  elif [[ "$TEMPLATE" == "Activity Monitor" ]]; then
    XML_FILE="${OUTPUT_DIR}/${LABEL}-${TIMESTAMP}-actmon.xml"
    echo "[INFO] Exporting activity-monitor-process-live table to XML..."
    xcrun xctrace export \
      --input "$TRACE_FILE" \
      --xpath "/trace-toc/run[@number='1']/data/table[@schema='activity-monitor-process-live']" \
      > "$XML_FILE" 2>/dev/null || {
        echo "[WARN] activity-monitor-process-live table not present or export returned non-zero."
      }

    if [[ -f "$XML_FILE" && -s "$XML_FILE" && $(grep -c '<row>' "$XML_FILE" 2>/dev/null || echo 0) -gt 0 ]]; then
      echo "[INFO] Parsing per-process CPU (ms/s)..."
      if [[ -n "$TARGET_NAME" && ! "$TARGET_NAME" =~ ^pid ]]; then
        python3 "${SCRIPT_DIR}/activity_cpu.py" "$XML_FILE" "$TARGET_NAME"
      else
        python3 "${SCRIPT_DIR}/activity_cpu.py" "$XML_FILE"
      fi
    else
      echo "[WARN] Activity Monitor produced no data rows."
    fi

  elif [[ "$TEMPLATE" == "Allocations" ]]; then
    XML_FILE="${OUTPUT_DIR}/${LABEL}-${TIMESTAMP}-alloc.xml"
    echo "[INFO] Exporting all-allocations-summary table to XML..."
    xcrun xctrace export \
      --input "$TRACE_FILE" \
      --xpath "/trace-toc/run[@number='1']/data/table[@schema='all-allocations-summary']" \
      > "$XML_FILE" 2>/dev/null || {
        echo "[WARN] all-allocations-summary table not present or export returned non-zero."
      }

    DURATION_SEC=$(echo "$DURATION" | sed 's/[^0-9]//g')
    if [[ -z "$DURATION_SEC" ]]; then DURATION_SEC=60; fi

    if [[ -f "$XML_FILE" && -s "$XML_FILE" && $(grep -c '<row>' "$XML_FILE" 2>/dev/null || echo 0) -gt 0 ]]; then
      echo "[INFO] Parsing allocation categories..."
      python3 "${SCRIPT_DIR}/top_categories.py" "$XML_FILE" "$DURATION_SEC" 10.0
    else
      echo "[WARN] Allocations produced no data rows."
    fi
  fi
fi

echo "[INFO] Profiling session complete."
