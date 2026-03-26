import json
import time


def fib(n):
    if n <= 1:
        return n
    return fib(n - 1) + fib(n - 2)


def handler(event, context):
    number = int((event.get("queryStringParameters") or {}).get("number", "33"))
    print(f"Starting fib({number})")

    start = time.perf_counter()
    result = fib(number)
    elapsed_ms = (time.perf_counter() - start) * 1000

    print("Done")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "result": result,
            "elapsed_ms": round(elapsed_ms * 100) / 100,
            "engine": "python-native"
        })
    }
