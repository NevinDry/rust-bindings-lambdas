import { createRequire } from 'node:module'
const require = createRequire(import.meta.url)
const { fib } = require('./index.js')

export const handler = async (event) => {
    const number = parseInt(event.queryStringParameters?.number || "35");
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
            engine: "javascript+rust-napi"
        })
    };
};
