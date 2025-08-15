// trial.js

// Polyfill console.log if not present
if (typeof console === "undefined") {
    var console = { log: print };
}

function fib(n) {
    return n < 2 ? n : fib(n - 1) + fib(n - 2);
}

console.log("Fib(10) =", fib(10));
console.log("Sum 1..5 =", [1, 2, 3, 4, 5].reduce((a, b) => a + b, 0));
