// run_octane.js - Compatible with original QuickJS
// Remove ES6 import and use global std if available

(function() {
  // Check if BenchmarkSuite is available (loaded from previous scripts)
  if (typeof BenchmarkSuite === 'undefined') {
      print("Error: BenchmarkSuite is not defined. Make sure base.js is loaded first.");
      return;
  }

  // Use print function (available in QuickJS) instead of printf
  function printf(str) {
      if (typeof print !== 'undefined') {
          print(str.replace(/\n$/, '')); // Remove trailing newline as print adds one
      } else {
          console.log(str.replace(/\n$/, ''));
      }
  }

  // Configure benchmark suite
  BenchmarkSuite.config.doWarmup = undefined;
  BenchmarkSuite.config.doDeterministic = undefined;
  
  var success = true;

  function PrintResult(name, result) {
      printf((name + "                    ").substr(0, 20) + ": " + result);
  }

  function PrintError(name, error) {
      PrintResult(name, error);
      success = false;
  }

  function PrintScore(score) {
      printf("----");
      printf("Score (version " + BenchmarkSuite.version + "): " + score);
  }

  // Run the benchmark suite
  BenchmarkSuite.RunSuites({
      NotifyResult: PrintResult,
      NotifyError: PrintError,
      NotifyScore: PrintScore,
  });

  // Print final success status
  if (success) {
      printf("All benchmarks completed successfully.");
  } else {
      printf("Some benchmarks failed.");
  }
})();