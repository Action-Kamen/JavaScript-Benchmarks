#!/usr/bin/env bash
set -euo pipefail

# bench_engine.sh
# Usage: bench_engine.sh "<engine-name>" "<engine-cmd>" <bench-folder-path> [filter]
# Example:
#   ./bench_engine.sh "QuickJS" "./engines/quickjs/build/qjs" /path/to/kraken-1.1 ai-astar

# =============================================================================
# CONFIGURABLE PATHS - Edit these for your environment
# =============================================================================

# Base directory (auto-detected, but can be overridden)
BASE="$(cd "$(dirname "$0")" && pwd)"

# Default benchmark suites directory (can be overridden by full path argument)
DEFAULT_BENCHMARK_SUITES_DIR="$BASE/benchmark_suites"

# =============================================================================
# SCRIPT ARGUMENTS AND SETUP
# =============================================================================

ENGINE_NAME="$1"
ENGINE_CMD="$2"   # command to run engine, e.g. "/path/to/d8 --jitless" or "./engines/jerry"
BENCH_FOLDER="$3" # can be absolute path or relative to benchmark_suites_dir
FILTER="${4:-}"

RESULTS_DIR="$BASE/Results/$ENGINE_NAME"
mkdir -p "$RESULTS_DIR"

# =============================================================================
# BENCHMARK FOLDER RESOLUTION
# =============================================================================

# Determine the actual benchmark directory path
if [[ "$BENCH_FOLDER" = /* ]]; then
  # Absolute path provided
  BENCH_DIR="$BENCH_FOLDER"
  BENCH_FOLDER_NAME="$(basename "$BENCH_DIR")"
else
  # Relative path - could be with or without trailing slash
  BENCH_FOLDER_CLEAN="${BENCH_FOLDER%/}"
  
  # Try to find in benchmark suites directory
  if [ -d "$DEFAULT_BENCHMARK_SUITES_DIR/$BENCH_FOLDER_CLEAN" ]; then
    BENCH_DIR="$DEFAULT_BENCHMARK_SUITES_DIR/$BENCH_FOLDER_CLEAN"
  elif [ -d "$BASE/$BENCH_FOLDER_CLEAN" ]; then
    # Fallback: look in base directory (backward compatibility)
    BENCH_DIR="$BASE/$BENCH_FOLDER_CLEAN"
  else
    echo "ERROR: Benchmark folder not found at:"
    echo "  - $DEFAULT_BENCHMARK_SUITES_DIR/$BENCH_FOLDER_CLEAN"
    echo "  - $BASE/$BENCH_FOLDER_CLEAN"
    exit 1
  fi
  
  BENCH_FOLDER_NAME="$BENCH_FOLDER_CLEAN"
fi

# Verify benchmark directory exists
if [ ! -d "$BENCH_DIR" ]; then
  echo "ERROR: Benchmark directory not found: $BENCH_DIR"
  exit 1
fi

echo "Using benchmark directory: $BENCH_DIR"

# =============================================================================
# ENGINE EXECUTABLE RESOLUTION
# =============================================================================

# Resolve engine executable to absolute path when it is a relative path
# (so we can cd into BENCH_DIR to run tests but still launch the engine binary correctly)
# We split ENGINE_CMD into an array, resolve the first token if it contains a slash
# or starts with ./, and then rebuild ENGINE_CMD.

read -r -a _cmdarr <<< "$ENGINE_CMD"
_exe="${_cmdarr[0]}"

if [[ "$_exe" == /* ]]; then
  # absolute path already
  _exe_resolved="$_exe"
elif [[ "$_exe" == .* || "$_exe" == */* ]]; then
  # relative path or path-with-slash: make it relative to repo BASE
  # remove leading ./ if present
  _exe_no_prefix="${_exe#./}"
  _exe_resolved="$BASE/$_exe_no_prefix"
else
  # bare command (in PATH) — leave as-is
  _exe_resolved="$_exe"
fi

# if resolved executable doesn't exist and is not a PATH command, warn (but continue)
if [[ "$_exe_resolved" != "$_exe" && ! -x "$_exe_resolved" ]]; then
  echo "Warning: resolved engine executable not found or not executable: $_exe_resolved"
fi

# replace first token with resolved path
_cmdarr[0]="$_exe_resolved"

# Rebuild ENGINE_CMD preserving flags/args (join with spaces)
ENGINE_CMD="${_cmdarr[*]}"

# =============================================================================
# OUTPUT FILE SETUP
# =============================================================================

# Use stable filenames (no timestamp)
CSV_PATH="$RESULTS_DIR/${BENCH_FOLDER_NAME}_results.csv"
SUMMARY_PATH="$RESULTS_DIR/${BENCH_FOLDER_NAME}_summary.txt"

# CSV header (overwrite existing file)
echo 'test,type,wall_time_s,user_time_s,sys_time_s,peak_mem_kb' > "$CSV_PATH"

LIST_PATH="$BENCH_DIR/LIST"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# helper to execute the engine command safely with a file argument
_exec_engine_with_file() {
  local file="$1"
  bash -c "$ENGINE_CMD '$file'"
}

# helper: run one file via engine with /usr/bin/time capturing metrics
# This version runs the engine with CWD set to the bench folder (BENCH_DIR)
run_one() {
  local file="$1"
  local type="$2"   # "data" or "main"

  # Check if time command exists
  if ! command -v /usr/bin/time >/dev/null 2>&1; then
    echo "ERROR: /usr/bin/time not found. Install GNU time package."
    exit 1
  fi

  local time_out
  time_out=$(mktemp)
  local error_out
  error_out=$(mktemp)

  # compute a "relative" filename for engine when running from bench dir
  local relfile="$file"
  if [[ "$file" == "$BENCH_DIR"* ]]; then
    relfile="${file#$BENCH_DIR/}"
  fi

  # Run engine with time measurement in subshell with CWD set to BENCH_DIR.
  # engine stdout -> /dev/null, engine/stderr -> error_out, time writes to time_out
  if ( cd "$BENCH_DIR" && /usr/bin/time -f "%e %U %S %M" -o "$time_out" bash -c "$ENGINE_CMD '$relfile' > /dev/null 2> '$error_out'" ); then
    local wall user sys peak_mem_kb
    read -r wall user sys peak_mem_kb < "$time_out"

    # Validate numeric values (fallback to 0 on unexpected output)
    if ! [[ "$wall" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then wall=0; fi
    if ! [[ "$user" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then user=0; fi
    if ! [[ "$sys" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then sys=0; fi
    if ! [[ "$peak_mem_kb" =~ ^[0-9]+$ ]]; then peak_mem_kb=0; fi

    # Write to CSV
    printf '"%s",%s,%.6f,%.6f,%.6f,%s\n' "$file" "$type" "$wall" "$user" "$sys" "$peak_mem_kb" >> "$CSV_PATH"

    # Echo to screen
    printf "%s (%s): wall=%.4fs user=%.4fs sys=%.4fs peak_mem=%s KB\n" "$file" "$type" "$wall" "$user" "$sys" "$peak_mem_kb"
  else
    echo "ERROR: Failed to execute $file with $ENGINE_CMD"
    if [ -s "$error_out" ]; then
      echo "Error details: $(head -n 5 "$error_out")"
    fi
    # Write error line to CSV (zeros)
    printf '"%s",%s,0,0,0,0\n' "$file" "$type" >> "$CSV_PATH"
  fi

  rm -f "$time_out" "$error_out"
}

# helper: run combined data+main files for Kraken benchmarks (with no shim)
# create combined file inside BENCH_DIR so relative requires/loads succeed
run_kraken_test() {
  local testname="$1"
  local datafile="$BENCH_DIR/${testname}-data.js"
  local mainfile="$BENCH_DIR/${testname}.js"

  # Check if both files exist
  if [ ! -f "$datafile" ] || [ ! -f "$mainfile" ]; then
    echo "Skipping $testname - missing files"
    return
  fi

  local combined_file
  combined_file=$(mktemp --tmpdir="$BENCH_DIR" --suffix=.js)
  # combine data then main (some benchmarks rely on data first)
  cat "$datafile" "$mainfile" > "$combined_file"

  local time_out
  time_out=$(mktemp)
  local error_out
  error_out=$(mktemp)

  local combined_basename
  combined_basename="$(basename "$combined_file")"

  if ( cd "$BENCH_DIR" && /usr/bin/time -f "%e %U %S %M" -o "$time_out" bash -c "$ENGINE_CMD '$combined_basename' > /dev/null 2> '$error_out'" ); then
    local wall user sys peak_mem_kb
    read -r wall user sys peak_mem_kb < "$time_out"

    # Validate numeric values
    if ! [[ "$wall" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then wall=0; fi
    if ! [[ "$user" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then user=0; fi
    if ! [[ "$sys" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then sys=0; fi
    if ! [[ "$peak_mem_kb" =~ ^[0-9]+$ ]]; then peak_mem_kb=0; fi

    # Write to CSV (combined test)
    printf '"%s",%s,%.6f,%.6f,%.6f,%s\n' "$testname" "combined" "$wall" "$user" "$sys" "$peak_mem_kb" >> "$CSV_PATH"

    # Echo to screen
    printf "%s (combined): wall=%.4fs user=%.4fs sys=%.4fs peak_mem=%s KB\n" "$testname" "$wall" "$user" "$sys" "$peak_mem_kb"
  else
    echo "ERROR: Failed to execute combined $testname with $ENGINE_CMD"
    if [ -s "$error_out" ]; then
      echo "Error details: $(head -n 5 "$error_out")"
    fi
    printf '"%s",%s,0,0,0,0\n' "$testname" "combined" >> "$CSV_PATH"
  fi

  rm -f "$combined_file" "$time_out" "$error_out"
}

# =============================================================================
# BENCHMARK TYPE DETECTION AND EXECUTION
# =============================================================================

# Detect benchmark type
BENCH_TYPE="unknown"
if [[ "$BENCH_FOLDER_NAME" == *"kraken"* ]]; then
  BENCH_TYPE="kraken"
elif [[ "$BENCH_FOLDER_NAME" == *"sunspider"* ]]; then
  BENCH_TYPE="sunspider"
elif [[ "$BENCH_FOLDER_NAME" == *"octane"* ]]; then
  BENCH_TYPE="octane"
elif [[ "$BENCH_FOLDER_NAME" == *"v8"* ]]; then
  BENCH_TYPE="v8"
fi

echo "Detected benchmark type: $BENCH_TYPE"

# ----- special-case handlers for V8 -----
# NOTE: The special-case handler for Octane has been removed to allow it
#       to run using the generic list-driven method below.

if [ "$BENCH_TYPE" = "v8" ]; then
  echo "Detected V8 benchmark folder. Attempting to use Node runner if present..."

  V8_RUNNER_CANDIDATES=(
    "$BENCH_DIR/benchmark.js"
    "$BENCH_DIR/tools/benchmark.js"
    "./v8/benchmark.js"
    "./benchmark.js"
  )

  V8_RUNNER=""
  for r in "${V8_RUNNER_CANDIDATES[@]}"; do
    if [ -f "$r" ]; then
      V8_RUNNER="$r"
      break
    fi
  done

  if [ -n "$V8_RUNNER" ]; then
    echo "Found V8 node runner: $V8_RUNNER"
    echo "Running: node \"$V8_RUNNER\" \"$ENGINE_NAME\" \"$ENGINE_CMD\""
    (
      cd "$BENCH_DIR" || exit 1
      echo "Invoking node runner from $(pwd)"
      node "$V8_RUNNER" "$ENGINE_NAME" "$ENGINE_CMD"
    )
    echo "V8 runner finished. Check its output for a Markdown table / Results."
    exit 0
  else
    echo "No V8 benchmark.js runner found at expected locations. Falling back to generic test runner if available."
  fi
fi

# =============================================================================
# GENERIC LIST-DRIVEN BENCHMARK EXECUTION
# =============================================================================

# ----- generic list-driven behavior for sunspider/kraken/others -----
if [ -f "$LIST_PATH" ]; then
  echo "Found LIST file at: $LIST_PATH"
  while IFS= read -r testname || [ -n "$testname" ]; do
    testname="${testname//$'\r'/}"
    [ -z "$testname" ] && continue

    if [ -n "$FILTER" ] && [ "$FILTER" != "$testname" ]; then
      echo "Skipping $testname (filtered)"
      continue
    fi

    echo "Running test: $testname"

    if [ "$BENCH_TYPE" = "kraken" ]; then
      run_kraken_test "$testname"
    else
      datafile="$BENCH_DIR/${testname}-data.js"
      mainfile="$BENCH_DIR/${testname}.js"

      if [ -f "$datafile" ]; then
        run_one "$datafile" "data"
      fi
      if [ -f "$mainfile" ]; then
        run_one "$mainfile" "main"
      else
        echo "Warning: main file missing for $testname ($mainfile)"
      fi
    fi
  done < "$LIST_PATH"
else
  echo "No LIST file found at: $LIST_PATH"
  if [ -f "$BENCH_DIR/combined.js" ]; then
    echo "Running combined.js"
    run_one "$BENCH_DIR/combined.js" "combined"
  else
    echo "No LIST file found and no combined.js; nothing to run for $BENCH_DIR"
  fi
fi

# =============================================================================
# RESULTS SUMMARY GENERATION
# =============================================================================

# Compute totals from CSV
TOTALS=$(awk -F, '
  NR>1 {
    wall += $3;
    user += $4;
    sys  += $5;
    if ($6+0 > peak_mem+0) peak_mem = $6+0;
  }
  END {
    printf "%.6f %.6f %.6f %d", (wall+0), (user+0), (sys+0), (peak_mem+0);
  }' "$CSV_PATH" || true)

if [ -z "$TOTALS" ]; then
  TOTALS="0.000000 0.000000 0.000000 0"
fi

read -r TOTAL_WALL TOTAL_USER TOTAL_SYS PEAK_MEM <<< "$TOTALS"

# write summary
{
  echo "Engine: $ENGINE_NAME"
  echo "Command: $ENGINE_CMD"
  echo "Bench folder: $BENCH_DIR"
  echo ""
  echo "CSV: $CSV_PATH"
  echo ""
  echo "Total wall time (s): $TOTAL_WALL"
  echo "Total user time (s): $TOTAL_USER"
  echo "Total sys time (s): $TOTAL_SYS"
  echo "Peak memory usage (KB): $PEAK_MEM"
} > "$SUMMARY_PATH"

echo ""
echo "Wrote CSV: $CSV_PATH"
echo "Wrote summary: $SUMMARY_PATH"
echo ""
echo "[Summary] Engine: $ENGINE_NAME"
echo "Total wall time: ${TOTAL_WALL}s"
echo "Total user time: ${TOTAL_USER}s"
echo "Total sys time: ${TOTAL_SYS}s"
echo "Peak memory: ${PEAK_MEM} KB"