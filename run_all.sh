#!/bin/bash
echo "Running SunSpider benchmarks on all engines..."

./bench_engine.sh "JerryScript" "./engines/jerryscript/build/bin/jerry" kraken-1.0/
./bench_engine.sh "Hermes" "./engines/hermes/hermes" kraken-1.0/
./bench_engine.sh "V8-JIT" "./engines/v8/out.gn/x64.release/d8" kraken-1.0/
./bench_engine.sh "V8-NoJIT" "./engines/v8/out.gn/x64.release/d8 --jitless" kraken-1.0/
./bench_engine.sh "QuickJS" "./engines/quickjs/build/qjs" kraken-1.0/
./bench_engine.sh "NodeJS" "node" kraken-1.0/
./bench_engine.sh "NodeJS-NoJIT" "node --jitless" kraken-1.0/

echo "All benchmarks completed! Results are in the Results/ directory."