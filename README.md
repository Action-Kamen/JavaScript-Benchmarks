# JavaScript Engine Benchmark Suite

A comprehensive benchmarking framework for comparing JavaScript engine performance across multiple benchmark suites including Kraken, SunSpider, Octane, and V8 benchmarks.

## 📁 Project Structure

```
benchmarks/
├── benchmark_suites/          # Benchmark test suites
│   ├── kraken-1.0/           # Kraken 1.0 benchmark suite
│   ├── kraken-1.1/           # Kraken 1.1 benchmark suite  
│   ├── sunspider-1.0/        # SunSpider 1.0 benchmark suite
│   └── octane/               # Google Octane benchmark suite
├── engines/                   # JavaScript engines to test
│   ├── quickjs/              # QuickJS engine
│   ├── v8/                   # V8 engine
│   └── hermes/               # Hermes engine (optional)
├── Results/                   # Generated benchmark results
│   └── [Engine Name]/        # Results per engine
├── comparison_plots/          # Generated comparison charts
├── run_all.sh                # Main benchmark runner script
├── bench_engine.sh           # Individual engine benchmark script
├── run_octane.c              # C runner for Octane benchmarks
├── run_octane.js             # JavaScript runner for Octane
├── compare_plots.py          # Plot generation script
└── README.md                 # This file
```

## 🔧 File Descriptions

### Core Scripts

- **`run_all.sh`** - Main orchestrator script that runs all benchmarks across all engines multiple times
- **`bench_engine.sh`** - Individual engine benchmark runner that handles different benchmark types
- **`compare_plots.py`** - Python script for generating performance comparison charts

### Octane-Specific Files

- **`run_octane.c`** - C-based runner for Octane benchmarks (requires QuickJS headers)
- **`run_octane.js`** - JavaScript-based runner for Octane benchmark suite execution

### Benchmark Suites

- **`benchmark_suites/kraken-1.0/`** - Mozilla Kraken 1.0 JavaScript benchmarks
- **`benchmark_suites/kraken-1.1/`** - Mozilla Kraken 1.1 JavaScript benchmarks  
- **`benchmark_suites/sunspider-1.0/`** - WebKit SunSpider 1.0 JavaScript benchmarks
- **`benchmark_suites/octane/`** - Google Octane JavaScript benchmarks

## ⚙️ Configuration & Setup

### 1. Directory Structure Setup

**IMPORTANT**: Before using this benchmark suite, you need to configure the paths for your environment.

#### Primary Configuration Locations:

**In `run_all.sh`** (Lines 8-20):
```bash
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
```

**In `bench_engine.sh`** (Lines 8-15):
```bash
# =============================================================================
# CONFIGURABLE PATHS - Edit these for your environment  
# =============================================================================

# Base directory (auto-detected, but can be overridden)
BASE="$(cd "$(dirname "$0")" && pwd)"

# Default benchmark suites directory (can be overridden by full path argument)
DEFAULT_BENCHMARK_SUITES_DIR="$BASE/benchmark_suites"
```

**In `run_octane.c`** (Lines 12-25):
```c
// =============================================================================
// CONFIGURABLE PATHS - Edit these for your environment
// =============================================================================

// Base directory for benchmarks (can be overridden by environment variable BENCHMARK_BASE)
#define DEFAULT_BENCHMARK_BASE "/home/anirudh/Desktop/CS492/benchmarks"

// QuickJS include paths (relative to benchmark base)
#define QUICKJS_HEADER_PATH "/engines/quickjs/quickjs.h"
#define QUICKJS_LIBC_HEADER_PATH "/engines/quickjs/quickjs-libc.h"

// Benchmark suites subdirectory
#define BENCHMARK_SUITES_SUBDIR "/benchmark_suites"

// Results directory (relative to benchmark base)
#define RESULTS_SUBDIR "/Results"
```

### 2. Engine Configuration

**In `run_all.sh`** (Lines 35-45):
```bash
# Engines: format "Name:::Command" (use ::: as separator)
ENGINES=(
  # "JerryScript:::./engines/jerryscript/build/bin/jerry"
  # "Hermes:::./engines/hermes/hermes"
  # "V8-JIT:::./engines/v8/out.gn/x64.release/d8"
  # "V8-NoJIT:::./engines/v8/out.gn/x64.release/d8 --jitless"
  # "QuickJS:::./engines/quickjs/build/qjs"
  "NodeJS:::node"
  "NodeJS-NoJIT:::node --jitless"
)
```

### 3. Benchmark Suite Configuration

**In `run_all.sh`** (Lines 30-32):
```bash
# Bench folders to run (must include trailing slash in their names here)
BENCH_LIST=( "kraken-1.0/" "kraken-1.1/" "sunspider-1.0/" "octane/" )
```

## 🚀 Usage

### Prerequisites

1. **System Requirements:**
   - Linux/Unix environment
   - `/usr/bin/time` command (GNU time)
   - Python 3.x with matplotlib and pandas
   - Bash shell

2. **Install Dependencies:**
   ```bash
   # Install Python dependencies
   pip3 install matplotlib pandas

   # Install GNU time (if not already present)
   sudo apt-get install time  # Ubuntu/Debian
   sudo yum install time      # RHEL/CentOS
   ```

### Running Benchmarks

1. **Quick Start** (default configuration):
   ```bash
   ./run_all.sh
   ```

2. **Custom Configuration:**
   ```bash
   # Edit the configuration sections in the files above
   # Then run:
   ./run_all.sh
   ```

3. **Single Engine Test:**
   ```bash
   ./bench_engine.sh "NodeJS" "node" "kraken-1.0/"
   ```

4. **Environment Variable Override:**
   ```bash
   BENCHMARK_BASE=/custom/path ./run_octane NodeJS
   ```

### Understanding Output

The benchmark suite generates:

- **CSV Files**: Detailed timing data in `Results/[Engine]/[benchmark]_results.csv`
- **Summary Files**: Human-readable summaries in `Results/[Engine]/[benchmark]_summary.txt`  
- **Comparison Plots**: Visual charts in `comparison_plots/[benchmark]/[test].png`

#### CSV Format:
```csv
test,type,wall_time_s,user_time_s,sys_time_s,peak_mem_kb
"test-name.js","main",0.123456,0.100000,0.020000,1024
```

#### Summary Format:
```
Engine: NodeJS
Command: node
Bench folder: /path/to/kraken-1.0

Total wall time (s): 2.345678
Total user time (s): 2.100000  
Total sys time (s): 0.245678
Peak memory usage (KB): 8192
```

## 🔧 Advanced Configuration

### Custom Benchmark Suites

To add a new benchmark suite:

1. Place suite in `benchmark_suites/[suite-name]/`
2. Add to `BENCH_LIST` in `run_all.sh`
3. Ensure suite has a `LIST` file or `combined.js`

### Custom Engines

To add a new engine:

1. Build/install engine in `engines/[engine-name]/`
2. Add entry to `ENGINES` array in format: `"Name:::./path/to/engine"`
3. Test with single benchmark first

### Environment Variables

- **`BENCHMARK_BASE`**: Override base directory path
- **`RUNS`**: Override number of benchmark runs (in script)

## 📊 Plot Generation

The `compare_plots.py` script generates performance comparison charts:

```bash
python3 compare_plots.py --results-root Results --out-dir comparison_plots --runs 3
```

### Plot Configuration Options:

- **`--results-root`**: Directory containing Results folders
- **`--out-dir`**: Output directory for generated plots  
- **`--runs`**: Number of benchmark runs to expect
- **`--metric`**: Metric to plot (default: wall_time_s)

### Supported Metrics:
- `wall_time_s` - Total execution time
- `user_time_s` - User CPU time
- `sys_time_s` - System CPU time  
- `peak_mem_kb` - Peak memory usage

## 🛠️ Compilation Instructions

### For Octane C Runner:

```bash
# Basic compilation
gcc -I./engines/quickjs run_octane.c -o run_octane -lquickjs

# With custom paths
gcc -I${BENCHMARK_BASE}/engines/quickjs run_octane.c -o run_octane -lquickjs

# Full compilation with CMake (if using CMakeLists.txt)
mkdir build
cd build
cmake ..
cmake --build .
```

## 🐛 Troubleshooting

### Common Issues:

1. **"bench_engine.sh not found"**
   - Ensure `BENCH_SCRIPT` path is correct in `run_all.sh`

2. **"Benchmark suites directory not found"**
   - Check `BENCHMARK_SUITES_DIR` path in configuration
   - Ensure benchmark suites are properly extracted

3. **"No CSV found after run"**
   - Check engine command is correct and executable
   - Verify benchmark suite structure (LIST file, etc.)

4. **Python plot generation fails**
   - Install required dependencies: `pip3 install matplotlib pandas`
   - Check Results directory exists and contains CSV files

### Debug Mode:

Enable verbose output:
```bash
set -x  # Add to top of shell scripts
CONFIG.verboseLogging = true  # In run_octane.js
```

## 📈 Performance Analysis

### Interpreting Results:

- **Wall Time**: Total execution time (includes I/O waits)
- **User Time**: CPU time spent in user mode
- **System Time**: CPU time spent in kernel mode  
- **Peak Memory**: Maximum RSS (Resident Set Size) in KB

### Comparing Engines:

1. Look at wall time for overall performance
2. Check user/sys time ratio for CPU efficiency
3. Monitor memory usage for resource consumption
4. Use plots to identify performance trends across runs

## 🤝 Contributing

To contribute to this benchmark suite:

1. Fork the repository
2. Make changes in feature branch
3. Test with multiple engines/suites
4. Update documentation
5. Submit pull request

### Adding New Features:

- New benchmark suites: Update `BENCH_LIST` and add detection logic
- New engines: Add to `ENGINES` array and test compatibility
- New metrics: Update CSV headers and plot script
- New analysis: Extend `compare_plots.py` functionality

## 📄 License

This benchmark suite is provided as-is for performance testing and comparison purposes. Individual benchmark suites may have their own licensing terms.

---

**Note**: Remember to update all configuration paths before running benchmarks in your environment!