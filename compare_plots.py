#!/usr/bin/env python3
"""
compare_plots.py

Usage:
  python3 compare_plots.py --results-root Results --out-dir comparison_plots --runs 3

Produces one PNG per test (per benchmark) with one line per engine and x-axis = run index.
"""
import os
import re
import argparse
from collections import defaultdict
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path

# --------------------------
def sanitize_filename(s: str) -> str:
    # make a safe filename
    return re.sub(r'[^A-Za-z0-9._-]', '_', s)[:200]

def find_result_csvs(results_root: str):
    # returns list of tuples (engine_name, csv_path)
    out = []
    for engine_dir in Path(results_root).iterdir():
        if not engine_dir.is_dir():
            continue
        engine_name = engine_dir.name
        # find CSVs in the engine directory
        for f in engine_dir.glob("*results*.csv"):
            out.append((engine_name, str(f)))
    return out

def detect_run_index_from_name(name: str):
    # try to extract run index from filename like *_runN.csv
    m = re.search(r'_run(\d+)', name)
    if m:
        return int(m.group(1))
    # fallback: try trailing digit before .csv
    m2 = re.search(r'(\d+)\.csv$', name)
    if m2:
        return int(m2.group(1))
    return None

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--results-root', default='Results', help='Root Results directory')
    ap.add_argument('--out-dir', default='comparison_plots', help='Output directory for plots')
    ap.add_argument('--runs', type=int, default=3, help='Number of runs expected (x-axis length)')
    ap.add_argument('--metric', default='wall_time_s', help='CSV numeric column to plot')
    args = ap.parse_args()

    results_root = Path(args.results_root)
    out_root = Path(args.out_dir)
    out_root.mkdir(parents=True, exist_ok=True)

    csvs = find_result_csvs(str(results_root))
    if not csvs:
        print("No result CSVs found under", results_root)
        return

    # data structure: data[bench_folder][test_name][engine] = dict(run_index -> metric)
    data = defaultdict(lambda: defaultdict(lambda: defaultdict(dict)))
    engines_seen = set()

    for engine_name, csv_path in csvs:
        engines_seen.add(engine_name)
        # attempt to infer bench folder from filename or from CSV contents (test entries include bench path)
        filename = os.path.basename(csv_path)
        run_index = detect_run_index_from_name(filename) or 0

        try:
            df = pd.read_csv(csv_path)
        except Exception as e:
            print("Failed to read", csv_path, ":", e)
            continue

        # If CSV contains 'test' column with bench prefix like "sunspider-1.0/3d-cube.js"
        tests = df.get('test')
        if tests is None:
            print("CSV missing 'test' column:", csv_path)
            continue

        for idx, row in df.iterrows():
            test_name = str(row['test']).strip()
            # detect bench folder if test_name contains something like "sunspider-1.0/..."
            bench_folder = "misc"
            if '/' in test_name:
                parts = test_name.split('/', 1)
                if re.search(r'\d', parts[0]):  # heuristic: contains a version number
                    bench_folder = parts[0]
                else:
                    # fallback: attempt from file path if available
                    bench_folder = parts[0]
            else:
                # If no slash, try to guess from filename (octane csv usually uses "octane/..." in test column)
                if 'octane' in filename.lower():
                    bench_folder = 'octane'
                elif 'sunspider' in filename.lower():
                    bench_folder = 'sunspider-1.0'
                elif 'kraken' in filename.lower():
                    bench_folder = 'kraken'
                else:
                    bench_folder = 'misc'

            # normalize test key to include bench folder prefix so plots are grouped sensibly
            full_test_key = f"{bench_folder}/{test_name.split('/')[-1]}"

            # metric extraction; be robust about column naming
            metric_col = args.metric
            if metric_col not in df.columns:
                # try alternative column names
                for alt in ('wall_time_s','wall_time','time_s','time'):
                    if alt in df.columns:
                        metric_col = alt
                        break
            try:
                val = float(row.get(metric_col, float('nan')))
            except Exception:
                val = float('nan')

            data[bench_folder][full_test_key][engine_name][run_index] = val

    # Now create plots: for each bench_folder -> test -> plot engines' lines
    for bench_folder, tests_map in data.items():
        out_bench_dir = out_root / bench_folder
        out_bench_dir.mkdir(parents=True, exist_ok=True)
        for test_key, engines_map in tests_map.items():
            plt.figure()
            ax = plt.gca()
            # x axis ticks 1..runs
            xs = list(range(1, args.runs + 1))
            plotted = 0
            for engine_name in sorted(engines_map.keys()):
                # build y values aligned to runs; use NaN if missing
                engine_runs = engines_map[engine_name]
                ys = []
                for r in xs:
                    # find run value; run indices are either r or 0-fallback; accept int keys
                    val = engine_runs.get(r, engine_runs.get(r-1, float('nan')))
                    ys.append(val)
                ax.plot(xs, ys, marker='o', label=engine_name)
                plotted += 1

            if plotted == 0:
                plt.close()
                continue

            ax.set_title(f"{bench_folder} — {test_key}")
            ax.set_xlabel("Run")
            ax.set_ylabel(args.metric)
            ax.set_xticks(xs)
            ax.legend(loc='best', fontsize='small')
            plt.tight_layout()

            outpath = out_bench_dir / f"{sanitize_filename(test_key)}.png"
            plt.savefig(outpath, dpi=150)
            plt.close()
            print("Wrote plot:", outpath)

    print("All plots written to", out_root)

if __name__ == '__main__':
    main()
