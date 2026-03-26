import json
import logging
import time
from fib_rust import fib

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    number = int(event["queryStringParameters"]["number"])
    logger.info(f"Starting fib({number})")

    start = time.time()
    result = fib(number)
    elapsed_ms = (time.time() - start) * 1000

    logger.info("Done")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "result": result,
            "elapsed_ms": round(elapsed_ms, 2),
            "engine": "python+rust-pyo3"
        })
    }
