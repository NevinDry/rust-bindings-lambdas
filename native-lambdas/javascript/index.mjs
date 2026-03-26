function fib(n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

export const handler = async (event) => {
    const number = parseInt(event.queryStringParameters?.number || "33");
    console.log(`Starting fib(${number})`);

    const start = performance.now();
    const result = fib(number);
    const elapsedMs = performance.now() - start;

    console.log("Done");

    return {
        statusCode: 200,
        body: JSON.stringify({
            result: result,
            elapsed_ms: Math.round(elapsedMs * 100) / 100,
            engine: "javascript-native"
        })
    };
};
