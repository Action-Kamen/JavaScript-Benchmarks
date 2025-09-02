/*
 * Copyright (c) 2003-2005  Tom Wu
 * All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS-IS" AND WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS, IMPLIED OR OTHERWISE, INCLUDING WITHOUT LIMITATION, ANY
 * WARRANTY of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * IN NO EVENT SHALL TOM WU BE LIABLE FOR ANY SPECIAL, INCIDENTAL,
 * INDIRECT OR CONSEQUENTIAL DAMAGES OF ANY, OR ANY DAMAGES WHATSOEVER
 * RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER OR NOT ADVISED OF
 * THE POSSIBILITY OF DAMAGE, AND ON ANY THEORY OF LIABILITY, ARISING OUT
 * OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 * In addition, the following condition applies:
 *
 * All redistributions must retain an intact copy of this copyright notice
 * and disclaimer.
 */
// =============================================================================
// OCTANE STANDALONE TRANSFORMATION HEADER
// =============================================================================
var performance = performance || {};
performance.now = (function() {
  return performance.now       ||
         performance.mozNow    ||
         performance.msNow     ||
         performance.oNow      ||
         performance.webkitNow ||
         Date.now;
})();

function Benchmark(name, doWarmup, doDeterministic, deterministicIterations,
                   run, setup, tearDown, rmsResult, minIterations) {
  this.name = name;
  this.doWarmup = doWarmup;
  this.doDeterministic = doDeterministic;
  this.deterministicIterations = deterministicIterations;
  this.run = run;
  this.Setup = setup ? setup : function() { };
  this.TearDown = tearDown ? tearDown : function() { };
  this.rmsResult = rmsResult ? rmsResult : null;
  this.minIterations = minIterations ? minIterations : 32;
}
function BenchmarkResult(benchmark, time, latency) {
  this.benchmark = benchmark;
  this.time = time;
  this.latency = latency;
}
BenchmarkResult.prototype.valueOf = function() {
  return this.time;
}
function BenchmarkSuite(name, reference, benchmarks) {
  this.name = name;
  this.reference = reference;
  this.benchmarks = benchmarks;
  BenchmarkSuite.suites.push(this);
}
BenchmarkSuite.suites = [];
BenchmarkSuite.version = '9';
BenchmarkSuite.config = {
  doWarmup: undefined,
  doDeterministic: undefined
};
// The alert function has been removed as requested.
BenchmarkSuite.ResetRNG = function() {
  Math.random = (function() {
    var seed = 49734321;
    return function() {
      seed = ((seed + 0x7ed55d16) + (seed << 12))  & 0xffffffff;
      seed = ((seed ^ 0xc761c23c) ^ (seed >>> 19)) & 0xffffffff;
      seed = ((seed + 0x165667b1) + (seed << 5))   & 0xffffffff;
      seed = ((seed + 0xd3a2646c) ^ (seed << 9))   & 0xffffffff;
      seed = ((seed + 0xfd7046c5) + (seed << 3))   & 0xffffffff;
      seed = ((seed ^ 0xb55a4f09) ^ (seed >>> 16)) & 0xffffffff;
      return (seed & 0xfffffff) / 0x10000000;
    };
  })();
}
BenchmarkSuite.RunSuites = function(runner, skipBenchmarks) {
  skipBenchmarks = typeof skipBenchmarks === 'undefined' ? [] : skipBenchmarks;
  var continuation = null;
  var suites = BenchmarkSuite.suites;
  var length = suites.length;
  BenchmarkSuite.scores = [];
  var index = 0;
  function RunStep() {
    while (continuation || index < length) {
      if (continuation) {
        continuation = continuation();
      } else {
        var suite = suites[index++];
        if (runner.NotifyStart) runner.NotifyStart(suite.name);
        if (skipBenchmarks.indexOf(suite.name) > -1) {
          suite.NotifySkipped(runner);
        } else {
          continuation = suite.RunStep(runner);
        }
      }
    }
    if (runner.NotifyScore) {
      runner.NotifyScore(0); // Pass a dummy score
    }
  }
  RunStep();
}
BenchmarkSuite.GeometricMean = function(numbers) {
  var log = 0;
  for (var i = 0; i < numbers.length; i++) {
    log += Math.log(numbers[i]);
  }
  return Math.pow(Math.E, log / numbers.length);
}
BenchmarkSuite.GeometricMeanTime = function(measurements) {
  var log = 0;
  for (var i = 0; i < measurements.length; i++) {
    log += Math.log(measurements[i].time);
  }
  return Math.pow(Math.E, log / measurements.length);
}
BenchmarkSuite.FormatScore = function(value) {
  if (value > 100) {
    return value.toFixed(0);
  } else {
    return value.toPrecision(3);
  }
}
BenchmarkSuite.prototype.NotifyStep = function(result) {
  this.results.push(result);
  if (this.runner.NotifyStep) this.runner.NotifyStep(result.benchmark.name);
}
BenchmarkSuite.prototype.NotifyResult = function() {
  if (this.runner.NotifyResult) {
    this.runner.NotifyResult(this.name, "Success");
  }
}
BenchmarkSuite.prototype.NotifyError = function(error) {
  if (this.runner.NotifyError) {
    this.runner.NotifyError(this.name, error);
  }
  if (this.runner.NotifyStep) {
    this.runner.NotifyStep(this.name);
  }
}
BenchmarkSuite.prototype.RunSingleBenchmark = function(benchmark, data) {
  function Measure(data) {
    var elapsed = 0;
    var start = new Date();
    for (var i = 0; elapsed < 1000; i++) {
      benchmark.run();
      elapsed = new Date() - start;
    }
  }
  Measure(null);
  this.NotifyStep(new BenchmarkResult(benchmark, 0, 0)); // Dummy result
  return null;
}
BenchmarkSuite.prototype.RunStep = function(runner) {
  BenchmarkSuite.ResetRNG();
  this.results = [];
  this.runner = runner;
  var length = this.benchmarks.length;
  var index = 0;
  var suite = this;

  function RunNextSetup() {
    if (index < length) {
      try {
        suite.benchmarks[index].Setup();
      } catch (e) {
        suite.NotifyError(e);
        return null;
      }
      return RunNextBenchmark;
    }
    suite.NotifyResult();
    return null;
  }
  function RunNextBenchmark() {
    try {
      suite.RunSingleBenchmark(suite.benchmarks[index], null);
    } catch (e) {
      suite.NotifyError(e);
      return null;
    }
    return RunNextTearDown;
  }
  function RunNextTearDown() {
    try {
      suite.benchmarks[index++].TearDown();
    } catch (e) {
      suite.NotifyError(e);
      return null;
    }
    return RunNextSetup;
  }
  return RunNextSetup();
}
// =============================================================================
// STANDALONE RUNNER (MODIFIED FOR SIMPLE PASS/FAIL)
// =============================================================================
function benchmark_printf(str) {
    // This function is now empty to prevent any console output.
}

function runStandalone() {
    benchmark_printf("--- Running Benchmarks ---");
    BenchmarkSuite.RunSuites({
      NotifyResult: function(name, result) {
        benchmark_printf("✅ " + name + ": Benchmark completed successfully.");
      },
      NotifyError: function(name, error) {
        benchmark_printf("❌ ERROR in " + name + ": " + error);
        if (error.stack) {
            benchmark_printf(error.stack);
        }
      },
      NotifyScore: function(score) {
        benchmark_printf("\n--- All benchmarks finished. ---");
      }
    });
}
// =============================================================================
// ORIGINAL BENCHMARK CODE STARTS BELOW
// =============================================================================