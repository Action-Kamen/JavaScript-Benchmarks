Done with the executable for each of the engines.

anirudh@anirudh-ROG-Zephyrus-G15-GA503RM-GA503RM:~/Desktop/CS492/benchmarks$ ./engines/jerryscript/build/bin/jerry trial.js
Fib(10) = 55
Sum 1..5 = 15
anirudh@anirudh-ROG-Zephyrus-G15-GA503RM-GA503RM:~/Desktop/CS492/benchmarks$ ./engines/hermes/hermes trial.js
Fib(10) = 55
Sum 1..5 = 15
anirudh@anirudh-ROG-Zephyrus-G15-GA503RM-GA503RM:~/Desktop/CS492/benchmarks$ ./engines/v8/out.gn/x64.release/d8 --jitless trial.js
Fib(10) = 55
Sum 1..5 = 15
anirudh@anirudh-ROG-Zephyrus-G15-GA503RM-GA503RM:~/Desktop/CS492/benchmarks$ ./engines/v8/out.gn/x64.release/d8 trial.js
Fib(10) = 55
Sum 1..5 = 15
anirudh@anirudh-ROG-Zephyrus-G15-GA503RM-GA503RM:~/Desktop/CS492/benchmarks$ ./engines/quickjs/build/qjs trial.js
Fib(10) = 55
Sum 1..5 = 15
anirudh@anirudh-ROG-Zephyrus-G15-GA503RM-GA503RM:~/Desktop/CS492/benchmarks$