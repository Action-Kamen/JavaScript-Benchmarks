(function() {
    // =============================================================================
    // CONFIGURATION - Adjust these settings if needed
    // =============================================================================
    
    // Benchmark suite configuration
    var config = {
        doWarmup: undefined,           // Let benchmark suite decide
        doDeterministic: undefined,    // Let benchmark suite decide
        verbose: true                  // Set to false for less verbose output
    };
    
    // =============================================================================
    // COMPATIBILITY AND INITIALIZATION
    // =============================================================================
    
    // Check if BenchmarkSuite is available (loaded from previous scripts)
    if (typeof BenchmarkSuite === 'undefined') {
        print("Error: BenchmarkSuite is not defined. Make sure base.js is loaded first.");
        return;
    }
    
    // Enhanced print function with better compatibility
    function printf(str) {
        // Remove trailing newline as print() adds one automatically
        var cleanStr = str.replace(/\n$/, '');
        
        if (typeof print !== 'undefined') {
            print(cleanStr);
        } else if (typeof console !== 'undefined' && console.log) {
            console.log(cleanStr);
        } else {
            // Fallback - should not happen in QuickJS
            throw new Error("No output method available");
        }
    }
    
    // =============================================================================
    // BENCHMARK EXECUTION SETUP
    // =============================================================================
    
    // Configure benchmark suite with our settings
    if (BenchmarkSuite.config) {
        BenchmarkSuite.config.doWarmup = config.doWarmup;
        BenchmarkSuite.config.doDeterministic = config.doDeterministic;
    }
    
    // Global success tracking
    var success = true;
    var results = [];
    var errors = [];
    
    // Result handlers
    function PrintResult(name, result) {
        var resultLine = (name + " ").substr(0, 20) + ": " + result;
        printf(resultLine);
        
        // Store result for summary
        results.push({
            name: name,
            result: result,
            success: true
        });
        
        if (config.verbose) {
            printf("  ✓ " + name + " completed successfully");
        }
    }
    
    function PrintError(name, error) {
        var errorLine = (name + " ").substr(0, 20) + ": ERROR - " + error;
        printf(errorLine);
        
        // Store error for summary
        errors.push({
            name: name,
            error: error
        });
        
        results.push({
            name: name,
            result: error,
            success: false
        });
        
        success = false;
        printf("  ✗ " + name + " failed: " + error);
    }
    
    function PrintScore(score) {
        printf("----");
        printf("Score (version " + BenchmarkSuite.version + "): " + score);
        printf("----");
    }
    
    // =============================================================================
    // BENCHMARK EXECUTION
    // =============================================================================
    
    printf("=== Octane Benchmark Suite Runner ===");
    printf("QuickJS Compatible Version");
    printf("BenchmarkSuite version: " + (BenchmarkSuite.version || "unknown"));
    printf("");
    
    // Verify BenchmarkSuite is properly initialized
    if (!BenchmarkSuite.RunSuites || typeof BenchmarkSuite.RunSuites !== 'function') {
        printf("Error: BenchmarkSuite.RunSuites is not available");
        return;
    }
    
    printf("Starting benchmark execution...");
    printf("");
    
    try {
        // Run the benchmark suite with our handlers
        BenchmarkSuite.RunSuites({
            NotifyResult: PrintResult,
            NotifyError: PrintError,
            NotifyScore: PrintScore
        });
    } catch (e) {
        printf("Fatal error during benchmark execution: " + e);
        if (e.stack) {
            printf("Stack trace: " + e.stack);
        }
        success = false;
    }
    
    // =============================================================================
    // RESULTS SUMMARY
    // =============================================================================
    
    printf("");
    printf("=== BENCHMARK SUMMARY ===");
    
    if (results.length > 0) {
        printf("Total benchmarks run: " + results.length);
        
        var successful = results.filter(function(r) { return r.success; }).length;
        var failed = results.length - successful;
        
        printf("Successful: " + successful);
        printf("Failed: " + failed);
        
        if (failed > 0) {
            printf("");
            printf("Failed benchmarks:");
            errors.forEach(function(err) {
                printf("  - " + err.name + ": " + err.error);
            });
        }
    } else {
        printf("No benchmark results recorded");
    }
    
    printf("");
    
    // Print final success status
    if (success) {
        printf("✓ All benchmarks completed successfully.");
    } else {
        printf("✗ Some benchmarks failed.");
    }
    
    // Additional diagnostics for debugging
    if (config.verbose) {
        printf("");
        printf("=== DIAGNOSTICS ===");
        printf("BenchmarkSuite object available: " + (typeof BenchmarkSuite !== 'undefined'));
        printf("BenchmarkSuite.RunSuites available: " + (typeof BenchmarkSuite.RunSuites === 'function'));
        
        if (typeof BenchmarkSuite !== 'undefined' && BenchmarkSuite.suites) {
            printf("Available benchmark suites: " + BenchmarkSuite.suites.length);
            BenchmarkSuite.suites.forEach(function(suite, index) {
                printf("  " + (index + 1) + ". " + suite.name);
            });
        }
        
        printf("JavaScript engine: QuickJS");
        printf("Global objects available: " + Object.getOwnPropertyNames(this).length);
    }
    
    printf("");
    printf("=== END OCTANE RUNNER ===");
    
})();