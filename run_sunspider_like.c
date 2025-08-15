#define _POSIX_C_SOURCE 199309L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <errno.h>

#include "engines/quickjs/quickjs.h"

double total_wall = 0.0;
double total_user = 0.0;
double total_sys  = 0.0;
long peak_mem_kb = 0;

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

int ExecuteAndRecord(JSRuntime *rt, JSContext *ctx, const char *filename, int eval_flags, FILE *csv) {
    static char buf[8 << 20];
    FILE *file = fopen(filename, "r");
    if (!file) {
        /* many suites have optional -data.js; just skip silently */
        return -1;
    }
    size_t nread = fread(buf, 1, sizeof(buf), file);
    fclose(file);
    if (nread == 0 || nread == sizeof(buf)) {
        return -1;
    }
    buf[nread] = '\0';

    // Force GC before measurement to get clean baseline
    JS_RunGC(rt);
    
    double t0 = now_sec();
    double user0, sys0;
    get_cpu_times(&user0, &sys0);
    size_t js_mem_before = get_js_memory_usage(rt);
    long rss_before = get_rss_kb();

    JSValue val = JS_Eval(ctx, buf, nread, filename, eval_flags);

    double t1 = now_sec();
    double user1, sys1;
    get_cpu_times(&user1, &sys1);
    size_t js_mem_after = get_js_memory_usage(rt);
    long rss_after = get_rss_kb();

    double wall = t1 - t0;
    double user = user1 - user0;
    double sys  = sys1 - sys0;
    long js_mem_change = (long)js_mem_after - (long)js_mem_before;
    long rss_peak = (rss_after > rss_before) ? rss_after : rss_before;

    total_wall += wall;
    total_user += user;
    total_sys  += sys;
    if (rss_peak > peak_mem_kb) {
        peak_mem_kb = rss_peak;
    }

    const char *type = (strstr(filename, "-data.js") ? "data" : "main");
    printf("%s (%s): wall=%.4fs, user=%.4fs, sys=%.4fs, js_mem_change=%ld bytes, rss_peak=%ld KB\n",
           filename, type, wall, user, sys, js_mem_change, rss_peak);

    if (csv) {
        fprintf(csv, "\"%s\",%s,%.6f,%.6f,%.6f,%zu,%zu,%ld,%ld\n",
                filename, type, wall, user, sys, js_mem_before, js_mem_after, js_mem_change, rss_peak);
        fflush(csv);
    }

    if (JS_IsException(val)) {
        JSValue exc = JS_GetException(ctx);
        if (JS_IsError(ctx, exc)) {
            JSValue stack = JS_GetPropertyStr(ctx, exc, "stack");
            if (!JS_IsUndefined(stack)) {
                const char *s = JS_ToCString(ctx, stack);
                if (s) {
                    fprintf(stderr, "Exception stack: %s\n", s);
                    JS_FreeCString(ctx, s);
                }
            }
            JS_FreeValue(ctx, stack);
        }
        JS_FreeValue(ctx, exc);
        JS_FreeValue(ctx, val);
        return -1;
    }
    JS_FreeValue(ctx, val);
    return 0;
}

void RunTestFromList(JSRuntime *rt, JSContext *ctx, const char *path, const char *testname, FILE *csv) {
    char p[512];
    /* try the -data.js first (some suites require it) */
    snprintf(p, sizeof(p), "%s%s-data.js", path, testname);
    ExecuteAndRecord(rt, ctx, p, JS_EVAL_TYPE_GLOBAL, csv);
    /* then the main test */
    snprintf(p, sizeof(p), "%s%s.js", path, testname);
    ExecuteAndRecord(rt, ctx, p, JS_EVAL_TYPE_GLOBAL, csv);
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <benchmark-folder/> [optional: filter] [optional: vm_name]\n", argv[0]);
        return 1;
    }

    const char *bench_folder = argv[1];
    const char *filter = NULL;
    const char *vm_name = "QuickJS";

    if (argc >= 3) filter = argv[2];
    if (argc >= 4) vm_name = argv[3];

    /* prepare results dir */
    const char *base_results = "/home/anirudh/Desktop/CS492/benchmarks/Results";
    char vm_dir[512];
    snprintf(vm_dir, sizeof(vm_dir), "%s/%s", base_results, vm_name);

    if (ensure_dir(base_results) != 0) return 1;
    if (ensure_dir(vm_dir) != 0) return 1;

    /* open LIST file */
    char listpath[512];
    snprintf(listpath, sizeof(listpath), "%sLIST", bench_folder);
    FILE *listFile = fopen(listpath, "r");
    if (!listFile) {
        fprintf(stderr, "Cannot open LIST file: %s\n", listpath);
        return 1;
    }

    /* prepare timestamped output files */
    time_t now = time(NULL);
    char timestr[64];
    strftime(timestr, sizeof(timestr), "%Y%m%d-%H%M%S", localtime(&now));

    char csvpath[1024], summarypath[1024];
    snprintf(csvpath, sizeof(csvpath), "%s/%s_results_%s.csv", vm_dir, "sunspider_kraken", timestr);
    snprintf(summarypath, sizeof(summarypath), "%s/%s_summary_%s.txt", vm_dir, "sunspider_kraken", timestr);
    FILE *csv = fopen(csvpath, "w");
    if (!csv) {
        fprintf(stderr, "Cannot open CSV file: %s\n", csvpath);
        fclose(listFile);
        return 1;
    }
    write_csv_header(csv);

    /* start runtime/context */
    JSRuntime *rt = JS_NewRuntime();
    JSContext *ctx = JS_NewContext(rt);
    JS_SetMaxStackSize(rt, 0);

    char line[256];
    while (fgets(line, sizeof(line), listFile)) {
        line[strcspn(line, "\n")] = '\0';
        if (filter && strlen(filter) > 0 && strcmp(filter, line) != 0) {
            printf("Skipping %s\n", line);
            continue;
        }
        RunTestFromList(rt, ctx, bench_folder, line, csv);
        /* give the runtime a chance to clean up */
        JS_RunGC(rt);
    }

    fclose(csv);
    fclose(listFile);

    /* write summary */
    FILE *summary = fopen(summarypath, "w");
    if (!summary) {
        fprintf(stderr, "Cannot open summary file: %s\n", summarypath);
        JS_FreeContext(ctx);
        return 1;
    }
    fprintf(summary, "VM: %s\n", vm_name);
    fprintf(summary, "Benchmark folder: %s\n", bench_folder);
    fprintf(summary, "Timestamp: %s\n\n", timestr);
    fprintf(summary, "Total wall time (s): %.6f\n", total_wall);
    fprintf(summary, "Total user CPU time (s): %.6f\n", total_user);
    fprintf(summary, "Total sys CPU time (s): %.6f\n", total_sys);
    fprintf(summary, "Peak memory usage (KB): %ld\n", peak_mem_kb);
    fclose(summary);

    printf("\nWrote CSV: %s\n", csvpath);
    printf("Wrote summary: %s\n", summarypath);
    printf("\n[Summary] Time=%.6fs, User=%.6fs, Sys=%.6fs, Peak mem=%ld KB\n",
           total_wall, total_user, total_sys, peak_mem_kb);

    JS_FreeContext(ctx);
    return 0;
}