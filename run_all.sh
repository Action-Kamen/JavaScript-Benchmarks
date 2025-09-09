#!/usr/bin/env bash
set -euo pipefail

# run_all.sh
# Usage: ./run_all.sh
# Put this script in the same folder as bench_engine.sh

# =============================================================================
# CONFIGURABLE PATHS - Edit these for your environment
# =============================================================================

# Base directory (auto-detected, but can be overridden)
BASE="$(cd "$(dirname "$0")" && pwd)"

# Benchmark suites directory
BENCHMARK_SUITES_DIR="$BASE/benchmark_suites"

# Path to bench_engine.sh script
BENCH_SCRIPT="$BASE/bench_engine.sh"

# Output folder for combined plots (created by Python script)
PLOTS_DIR="$BASE/comparison_plots"

# Python script for generating plots
PYTHON_PLOT_SCRIPT="$BASE/compare_plots.py"

# =============================================================================
# BENCHMARK CONFIGURATION
# =============================================================================

# Number of benchmark runs
RUNS=3   # change this to run benchmarks more/fewer times

# Bench folders to run (must include trailing slash in their names here)
BENCH_LIST=( "kraken-1.0" "kraken-1.1" "sunspider-1.0" "standalone" "ML" )

# Engines: format "Name:::Command" (use ::: as separator)
ENGINES=(
  "JerryScript:::./engines/jerryscript/build/bin/jerry"
  "Hermes:::./engines/hermes/hermes"
  "V8-JIT:::./engines/v8/out.gn/x64.release/d8"
  "V8-NoJIT:::./engines/v8/out.gn/x64.release/d8 --jitless"
  "QuickJS:::./engines/quickjs/build/qjs"
  "NodeJS:::node"
  "NodeJS-NoJIT:::node --jitless"
)

# =============================================================================
# SCRIPT LOGIC - DO NOT MODIFY BELOW THIS LINE UNLESS NECESSARY
# =============================================================================

if [ ! -x "$BENCH_SCRIPT" ]; then
  echo "ERROR: bench_engine.sh not found or not executable at $BENCH_SCRIPT"
  exit 1
fi

if [ ! -d "$BENCHMARK_SUITES_DIR" ]; then
  echo "ERROR: Benchmark suites directory not found at $BENCHMARK_SUITES_DIR"
  echo "Please create the directory and place your benchmark suites inside it."
  exit 1
fi

echo "Starting benchmark runs. RUNS=$RUNS"
echo "Base dir: $BASE"
echo "Benchmark suites dir: $BENCHMARK_SUITES_DIR"
echo ""

# helper to find the CSV/summary produced by bench_engine.sh and move to run-specific name
save_run_outputs() {
  local engine_dir="$1"   # Results/<Engine>
  local bench_name="$2"   # kraken-1.0/ (with trailing slash)
  local run_idx="$3"

  mkdir -p "$engine_dir"

  BENCH_KEY="${bench_name%/}"   # strip trailing slash

  # Candidate CSV names in order of preference
  CANDIDATE_CSVS=(
    "$engine_dir/${BENCH_KEY}_results.csv"
    "$engine_dir/octane_results.csv"
    "$engine_dir/${BENCH_KEY}-results.csv"
  )

  CSV_SRC=""
  for c in "${CANDIDATE_CSVS[@]}"; do
    if [ -f "$c" ]; then CSV_SRC="$c"; break; fi
  done

  # fallback: pick newest CSV in engine_dir matching "*results*.csv"
  if [ -z "$CSV_SRC" ]; then
    CSV_SRC=$(ls -t "$engine_dir"/*results*.csv 2>/dev/null | head -n 1 || true)
  fi

  if [ -n "$CSV_SRC" ] && [ -f "$CSV_SRC" ]; then
    CSV_DEST="$engine_dir/${BENCH_KEY}_results_run${run_idx}.csv"
    if [ -f "$CSV_DEST" ]; then
      echo "Warning: $CSV_DEST already exists — renaming with .bak"
      mv -f "$CSV_DEST" "${CSV_DEST}.bak"
    fi
    mv -f "$CSV_SRC" "$CSV_DEST"
    echo "Saved CSV -> $(basename "$CSV_DEST")"
  else
    echo "Warning: No CSV found in $engine_dir after run (bench: $bench_name)"
  fi

  # SUMMARY: try similar approach
  CANDIDATE_SUMS=(
    "$engine_dir/${BENCH_KEY}_summary.txt"
    "$engine_dir/octane_summary.txt"
    "$engine_dir/${BENCH_KEY}-summary.txt"
  )
  SUM_SRC=""
  for c in "${CANDIDATE_SUMS[@]}"; do
    if [ -f "$c" ]; then SUM_SRC="$c"; break; fi
  done
  if [ -z "$SUM_SRC" ]; then
    SUM_SRC=$(ls -t "$engine_dir"/*summary*.txt 2>/dev/null | head -n 1 || true)
  fi
  if [ -n "$SUM_SRC" ] && [ -f "$SUM_SRC" ]; then
    SUM_DEST="$engine_dir/${BENCH_KEY}_summary_run${run_idx}.txt"
    if [ -f "$SUM_DEST" ]; then
      mv -f "$SUM_DEST" "${SUM_DEST}.bak"
    fi
    mv -f "$SUM_SRC" "$SUM_DEST"
    echo "Saved summary -> $(basename "$SUM_DEST")"
  else
    echo "No summary file found (okay for some runners)."
  fi
}

# small preflight: show engines and resolved exe check (does not stop)
echo "Engine preflight:"
for pair in "${ENGINES[@]}"; do
  # safe split on literal ':::'
  engine_name="${pair%%:::*}"
  engine_cmd="${pair#*:::}"
  echo "  - $engine_name -> $engine_cmd"
  # try to find first token exe
  first_tok="${engine_cmd%% *}"
  if [[ "$first_tok" == .* || "$first_tok" == */* ]]; then
    exe_path="$BASE/${first_tok#./}"
    if [ ! -x "$exe_path" ]; then
      echo "    Warning: executable not found or not executable at: $exe_path"
    fi
  else
    # bare command; check in PATH
    if ! command -v "$first_tok" >/dev/null 2>&1; then
      echo "    Warning: command '$first_tok' not found in PATH"
    fi
  fi
done
echo ""

# Verify benchmark suites exist
echo "Benchmark suite preflight:"
for bench in "${BENCH_LIST[@]}"; do
  bench_path="$BENCHMARK_SUITES_DIR/${bench%/}"
  if [ -d "$bench_path" ]; then
    echo "  ✓ Found: $bench_path"
  else
    echo "  ✗ Missing: $bench_path"
  fi
done
echo ""

# main loop
for bench in "${BENCH_LIST[@]}"; do
  echo ""
  echo "=== BENCH: $bench ==="
  
  # Use the benchmark suites directory
  bench_full_path="$BENCHMARK_SUITES_DIR/$bench"
  
  if [ ! -d "$bench_full_path" ]; then
    echo "ERROR: Benchmark suite not found at $bench_full_path"
    echo "Skipping $bench"
    continue
  fi
  
  for engine_pair in "${ENGINES[@]}"; do
    # Proper safe split on the literal ':::'
    engine_name="${engine_pair%%:::*}"
    engine_cmd="${engine_pair#*:::}"

    echo ""
    echo "--- Engine: $engine_name  Command: $engine_cmd ---"

    # ensure Results/<Engine> directory exists
    engine_results_dir="$BASE/Results/$engine_name"
    mkdir -p "$engine_results_dir"

    # run RUNS times
    for (( r=1; r<=RUNS; r++ )); do
      echo ""
      echo "Run #$r for $engine_name on $bench"

      # invoke bench_engine.sh from repo root so relative paths resolve consistently
      (
        cd "$BASE"
        bash "$BENCH_SCRIPT" "$engine_name" "$engine_cmd" "$bench_full_path"
      )

      # save (rename/move) produced CSV/summary to a run-specific file
      save_run_outputs "$engine_results_dir" "$bench" "$r"

      echo "Completed run $r for $engine_name on $bench"
      echo "---------------------------------------------"
    done
  done
done

echo ""
echo "All runs complete. Creating comparison plots..."

# Fixed Python command - removed extra quotes and fixed path reference
if [ -f "$PYTHON_PLOT_SCRIPT" ]; then
  echo "Running: python3 $PYTHON_PLOT_SCRIPT --results-root $BASE/Results --out-dir $PLOTS_DIR --runs $RUNS"
  python3 "$PYTHON_PLOT_SCRIPT" --results-root "$BASE/Results" --out-dir "$PLOTS_DIR" --runs "$RUNS"
  echo "Plots saved to: $PLOTS_DIR"
else
  echo "Warning: Python plot script not found at $PYTHON_PLOT_SCRIPT"
  echo "Plots not generated. You can run manually with:"
  echo "python3 compare_plots.py --results-root \"$BASE/Results\" --out-dir \"$PLOTS_DIR\" --runs $RUNS"
fi

echo ""
echo "Benchmark run completed successfully!"