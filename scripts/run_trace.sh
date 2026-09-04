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
  --no-analyze                Skip automatic XML export and Python analysis

Examples:
  # Profile running app for 60s with Power Profiler and parse results:
  $(basename "$0") --process MyApp --template power --duration 60s

  # Profile allocations for 45s:
  $(basename "$0") --process MyApp --template alloc --duration 45s

  # Profile UI animation hitches during scrolling:
  $(basename "$0") --process MyApp --template hitches --duration 30s

  # Cold-launch binary under Time Profiler for 20s:
  $(basename "$0") --launch /path/to/MyApp.app/Contents/MacOS/MyApp --template time --duration 20s
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

# Check prerequisites
if ! command -v xcrun &>/dev/null; then
  echo "[ERROR] 'xcrun' not found. Install Xcode Command Line Tools via: xcode-select --install" >&2
  exit 1
fi

if ! xcrun xctrace version &>/dev/null; then
  echo "[ERROR] 'xctrace' is not functional. Ensure Xcode or Command Line Tools are active." >&2
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

echo "========================================================================"
echo " macOS-Trace Profiling Run"
echo "========================================================================"
echo "  Template:  $TEMPLATE"
echo "  Duration:  $DURATION"
echo "  Target:    ${TARGET_NAME:+Process '$TARGET_NAME' (PID $TARGET_PID)}${LAUNCH_CMD:+Binary '$LAUNCH_CMD'}"
echo "  Output:    $TRACE_FILE"
echo "========================================================================"

if [[ -n "$TARGET_PID" ]]; then
  xcrun xctrace record \
    --template "$TEMPLATE" \
    --time-limit "$DURATION" \
    --output "$TRACE_FILE" \
    --attach "$TARGET_PID"
else
  xcrun xctrace record \
    --template "$TEMPLATE" \
    --time-limit "$DURATION" \
    --output "$TRACE_FILE" \
    --launch -- $LAUNCH_CMD
fi

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

    if [[ -f "$XML_FILE" && -s "$XML_FILE" ]]; then
      echo "[INFO] Parsing Power Impact metrics..."
      python3 "${SCRIPT_DIR}/parse_power.py" "$XML_FILE" "$LABEL"
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

    if [[ -f "$XML_FILE" && -s "$XML_FILE" ]]; then
      echo "[INFO] Parsing allocation categories..."
      python3 "${SCRIPT_DIR}/top_categories.py" "$XML_FILE" "$DURATION_SEC" 10.0
    fi
  fi
fi

echo "[INFO] Profiling session complete."
