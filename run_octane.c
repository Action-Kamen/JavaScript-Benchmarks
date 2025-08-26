#define _POSIX_C_SOURCE 199309L
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <errno.h>
#include <string.h>

// =============================================================================
// CONFIGURABLE PATHS - Edit these for your environment
// =============================================================================

// Base benchmarks directory
#define BASE_BENCHMARKS_DIR "/home/anirudh/Desktop/CS492/benchmarks"

// QuickJS include paths (adjust these based on your QuickJS installation)
#define QUICKJS_INCLUDE_DIR BASE_BENCHMARKS_DIR "/engines/quickjs"

// Results directory
#define BASE_RESULTS_DIR BASE_BENCHMARKS_DIR "/Results"

// Benchmark suites directory
#define BENCHMARK_SUITES_DIR BASE_BENCHMARKS_DIR "/benchmark_suites"

// Octane benchmark directory
#define OCTANE_DIR BENCHMARK_SUITES_DIR "/octane"

// =============================================================================
// INCLUDES - Using configured paths
// =============================================================================

// Construct include paths dynamically
#define STRINGIFY(x) #x
#define EXPAND_AND_STRINGIFY(x) STRINGIFY(x)

// Include QuickJS headers
#include EXPAND_AND_STRINGIFY(/home/anirudh/Desktop/CS492/benchmarks/quickjs/quickjs.h)
#include EXPAND_AND_STRINGIFY(/home/anirudh/Desktop/CS492/benchmarks/quickjs/quickjs-libc.h)

// =============================================================================
// GLOBAL VARIABLES AND UTILITIES
// =============================================================================

static double total_time = 0.0;
static double total_user = 0.0;
static double total_sys = 0.0;
static long peak_mem_kb = 0;

static double now_sec() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

static void get_cpu_times(double *user_out, double *sys_out) {
    struct rusage ru;
    getrusage(RUSAGE_SELF, &ru);
    *user_out = ru.ru_utime.tv_sec + ru.ru_utime.tv_usec / 1e6;
    *sys_out  = ru.ru_stime.tv_sec + ru.ru_stime.tv_usec / 1e6;
}

/* ru_maxrss is in kilobytes on Linux */
static long get_rss_kb() {
    struct rusage usage;
    getrusage(RUSAGE_SELF, &usage);
    return usage.ru_maxrss;
}

// Get QuickJS memory usage
static size_t get_js_memory_usage(JSRuntime *rt) {
    JSMemoryUsage usage;
    JS_ComputeMemoryUsage(rt, &usage);
    return usage.memory_used_size;
}

static int ensure_dir(const char *path) {
    struct stat st = {0};
    if (stat(path, &st) == -1) {
        if (mkdir(path, 0755) != 0) {
            fprintf(stderr, "mkdir(%s) failed: %s\n", path, strerror(errno));
            return -1;
        }
    }
    return 0;
}

void write_csv_header(FILE *f) {
    fprintf(f, "test,type,wall_time_s,user_time_s,sys_time_s,js_mem_before_bytes,js_mem_after_bytes,js_mem_change_bytes,rss_peak_kb\n");
}

// Helper function to construct full script path
static char* construct_script_path(const char* script_name) {
    static char path_buffer[1024];
    snprintf(path_buffer, sizeof(path_buffer), "%s/%s", OCTANE_DIR, script_name);
    return path_buffer;
}

void ExecuteAndRecord(JSRuntime *rt, JSContext *ctx, const char *filename, int eval_flags, FILE *csv) {
    static char buf[8 << 20];
    
    // Construct full path to script
    char* full_path = construct_script_path(filename);
    
    FILE *file = fopen(full_path, "r");
    if (!file) {
        fprintf(stderr, "Cannot open file: %s\n", full_path);
        return;
    }
    
    size_t nread = fread(buf, 1, sizeof(buf), file);
    fclose(file);
    
    if (nread == 0 || nread == sizeof(buf)) {
        fprintf(stderr, "read error or file too large: %s\n", full_path);
        return;
    }
    buf[nread] = '\0';

    // Force GC before measurement to get clean baseline
    JS_RunGC(rt);
    
    double t0 = now_sec();
    double user0, sys0;
    get_cpu_times(&user0, &sys0);
    size_t js_mem_before = get_js_memory_usage(rt);

    printf("Executing %s...\n", filename);
    JSValue val = JS_Eval(ctx, buf, nread, filename, eval_flags);

    // Check for exceptions immediately after execution
    if (JS_IsException(val)) {
        printf("Exception occurred in %s\n", filename);
        JSValue exc = JS_GetException(ctx);
        if (JS_IsError(ctx, exc)) {
            JSValue stack = JS_GetPropertyStr(ctx, exc, "stack");
            if (!JS_IsUndefined(stack)) {
                const char *s = JS_ToCString(ctx, stack);
                if (s) {
                    fprintf(stderr, "Exception in %s: %s\n", filename, s);
                    JS_FreeCString(ctx, s);
                }
            }
            JS_FreeValue(ctx, stack);
        }
        JS_FreeValue(ctx, exc);
        JS_FreeValue(ctx, val);
        return; // Skip timing measurements on error
    }

    double t1 = now_sec();
    double user1, sys1;
    get_cpu_times(&user1, &sys1);
    size_t js_mem_after = get_js_memory_usage(rt);
    long rss_current = get_rss_kb();

    double wall = t1 - t0;
    double user = user1 - user0;
    double sys  = sys1 - sys0;
    long js_mem_change = (long)js_mem_after - (long)js_mem_before;

    total_time += wall;
    total_user += user;
    total_sys += sys;
    if (rss_current > peak_mem_kb) {
        peak_mem_kb = rss_current;
    }

    /* try to pick a type string from the filename */
    const char *type = strstr(filename, "-data.js") ? "data" : "main";
    if (strstr(filename, "base.js")) type = "base";
    else if (strstr(filename, "run_octane.js")) type = "runner";

    printf("%s (%s): wall=%.4fs, user=%.4fs, sys=%.4fs, js_mem_change=%ld bytes, rss_peak=%ld KB\n",
           filename, type, wall, user, sys, js_mem_change, rss_current);

    if (csv) {
        fprintf(csv, "\"%s\",%s,%.6f,%.6f,%.6f,%zu,%zu,%ld,%ld\n",
                filename, type, wall, user, sys, js_mem_before, js_mem_after, js_mem_change, rss_current);
        fflush(csv);
    }

    JS_FreeValue(ctx, val);
}

int main(int argc, char **argv) {
    const char *vm_name = "QuickJS";
    if (argc >= 2) {
        /* optional: first arg can be vm_name */
        vm_name = argv[1];
    }

    printf("Octane C Runner Configuration:\n");
    printf("Base benchmarks dir: %s\n", BASE_BENCHMARKS_DIR);
    printf("Results dir: %s\n", BASE_RESULTS_DIR);
    printf("Octane dir: %s\n", OCTANE_DIR);
    printf("VM name: %s\n\n", vm_name);

    /* prepare results dir using configured paths */
    char vm_dir[512];
    snprintf(vm_dir, sizeof(vm_dir), "%s/%s", BASE_RESULTS_DIR, vm_name);

    if (ensure_dir(BASE_RESULTS_DIR) != 0) return 1;
    if (ensure_dir(vm_dir) != 0) return 1;

    /* Generate timestamp for summary content (not filenames) */
    time_t now = time(NULL);
    char timestr[64];
    strftime(timestr, sizeof(timestr), "%Y%m%d-%H%M%S", localtime(&now));

    /* Use consistent filenames without timestamps */
    char csvpath[1024], summarypath[1024];
    snprintf(csvpath, sizeof(csvpath), "%s/octane_results.csv", vm_dir);
    snprintf(summarypath, sizeof(summarypath), "%s/octane_summary.txt", vm_dir);

    FILE *csv = fopen(csvpath, "w");
    if (!csv) {
        fprintf(stderr, "Cannot open CSV file for writing: %s\n", csvpath);
        return 1;
    }
    write_csv_header(csv);

    /* Start QuickJS runtime/context */
    JSRuntime *rt = JS_NewRuntime();
    if (!rt) {
        fprintf(stderr, "Failed to create QuickJS runtime\n");
        fclose(csv);
        return 1;
    }
    
    JSContext *ctx = JS_NewContext(rt);
    if (!ctx) {
        fprintf(stderr, "Failed to create QuickJS context\n");
        JS_FreeRuntime(rt);
        fclose(csv);
        return 1;
    }

    // Initialize standard modules first
    js_init_module_std(ctx, "std");
    js_init_module_os(ctx, "os");
    
    // Set stack size
    JS_SetMaxStackSize(rt, 0);

    // Script list - now just filenames, paths constructed dynamically
    const char *scripts[] = {
        "base.js",
        "richards.js",
        "deltablue.js",
        "crypto.js",
        "raytrace.js",
        "earley-boyer.js",
        "regexp.js",
        "splay.js",
        "navier-stokes.js",
        "pdfjs.js",
        "mandreel.js",
        "gbemu-part1.js",
        "gbemu-part2.js",
        "code-load.js",
        "box2d.js",
        "zlib.js",
        "zlib-data.js",
        "typescript.js",
        "typescript-input.js",
        "typescript-compiler.js"
    };

    size_t n_scripts = sizeof(scripts) / sizeof(scripts[0]);
    
    printf("Loading %zu Octane benchmark scripts...\n", n_scripts);
    for (size_t i = 0; i < n_scripts; ++i) {
        const char *s = scripts[i];
        // All benchmark scripts should be loaded as global scripts
        int eval_flags = JS_EVAL_TYPE_GLOBAL;
        ExecuteAndRecord(rt, ctx, s, eval_flags, csv);
        /* allow GC between tests to clean up and get accurate measurements */
        JS_RunGC(rt);
    }
    
    // Try to run the final runner script separately with better error handling
    printf("\nAttempting to run octane runner...\n");
    ExecuteAndRecord(rt, ctx, "run_octane.js", JS_EVAL_TYPE_GLOBAL, csv);

    fclose(csv);

    /* write summary */
    FILE *summary = fopen(summarypath, "w");
    if (!summary) {
        fprintf(stderr, "Cannot open summary file: %s\n", summarypath);
        JS_FreeContext(ctx);
        JS_FreeRuntime(rt);
        return 1;
    }
    fprintf(summary, "VM: %s\n", vm_name);
    fprintf(summary, "Benchmark: Octane\n");
    fprintf(summary, "Timestamp: %s\n\n", timestr);
    fprintf(summary, "Configuration:\n");
    fprintf(summary, "  Base benchmarks dir: %s\n", BASE_BENCHMARKS_DIR);
    fprintf(summary, "  Octane dir: %s\n", OCTANE_DIR);
    fprintf(summary, "  Results dir: %s\n\n", BASE_RESULTS_DIR);
    fprintf(summary, "Results:\n");
    fprintf(summary, "  Total scripts: %zu\n", n_scripts + 1); // +1 for run_octane.js
    fprintf(summary, "  Total wall time (s): %.6f\n", total_time);
    fprintf(summary, "  Total user CPU time (s): %.6f\n", total_user);
    fprintf(summary, "  Total sys CPU time (s): %.6f\n", total_sys);
    fprintf(summary, "  Peak memory usage (KB): %ld\n", peak_mem_kb);
    fclose(summary);

    printf("\nWrote CSV: %s\n", csvpath);
    printf("Wrote summary: %s\n", summarypath);
    printf("\n[Summary] Time=%.6fs, User=%.6fs, Sys=%.6fs, Peak mem=%ld KB\n",
           total_time, total_user, total_sys, peak_mem_kb);

    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);
    return 0;
}