# Porting a Python Lambda to Rust

The existing Python function is the specification, and its tests are the acceptance
criteria. The goal is a drop-in replacement: same event in, same response out, same
side effects, same environment variables, same IAM permissions.

## 1. Inventory before writing code

Read the Python function and write down, in a short `PORTING.md` at the project root:

- **Trigger and response shape**: event source (SQS, API Gateway, EventBridge...), what the
  handler returns, and whether SQS uses partial batch failures (`batchItemFailures`).
- **Environment variables** and their defaults.
- **AWS calls** (every `boto3` client and operation) and other network calls.
- **Dependencies** from `requirements.txt` / `pyproject.toml`, mapped to crates:

| Python | Rust |
|---|---|
| `boto3` client `x` | `aws-sdk-x` + `aws-config` |
| `json` | `serde_json` |
| `pydantic`, `dataclasses` | `serde` structs with `#[derive(Deserialize, Serialize)]` |
| `requests`, `httpx` | `reqwest` (with `rustls`) |
| `logging`, Powertools Logger | `tracing` (already re-exported by `lambda_runtime`) |
| `decimal.Decimal` | `rust_decimal` |
| `datetime` | `chrono` or `jiff` |
| `boto3.dynamodb.types` (de)serialisation | `serde_dynamo` |
| `pytest` + `moto` / botocore `Stubber` | `#[test]` / `#[tokio::test]` + `aws-smithy-mocks` |

Use `cargo add` to add each crate. Do not add crates the Python code does not need.

## 2. Freeze the behaviour as fixtures

1. Run the Python test suite first (`pytest -q`) and record that it passes. If it fails,
   stop and tell the user: you cannot port against a broken spec.
2. Copy every event payload used by the tests into `events/` as JSON files.
3. If coverage is thin, record golden outputs by running the Python handler on real events
   captured from CloudWatch or from `cargo lambda invoke --data-example <name>`:

```python
# scripts/golden.py: run from the Python project, writes events/<name>.expected.json
import json, pathlib, sys
from app import handler  # adjust to the real module

for path in sorted(pathlib.Path(sys.argv[1]).glob("*.json")):
    if path.name.endswith(".expected.json"):
        continue
    result = handler(json.loads(path.read_text()), None)
    path.with_suffix(".expected.json").write_text(json.dumps(result, indent=2, sort_keys=True))
```

Stub or point AWS calls at test resources while doing this; never record against production.

## 3. Translate the tests before the code

For each Python test, write a Rust test with the same name and the same fixture, then write
the code until it passes. Keep the expected values identical; never edit an expectation to
make a Rust test pass. If a Python test looks wrong, flag it to the user instead of
"fixing" it silently.

```rust
#[test]
fn test_rejects_negative_amount() {
    let event: SqsEvent =
        serde_json::from_str(include_str!("../events/negative_amount.json")).expect("valid fixture");
    // ...call the pure function and assert the same outcome as the Python test
}
```

For golden files, compare JSON values, not strings, so key order and spacing do not matter:

```rust
let expected: serde_json::Value =
    serde_json::from_str(include_str!("../events/order.expected.json")).expect("valid golden file");
assert_eq!(serde_json::to_value(&actual).expect("serialisable output"), expected);
```

Where the Python tests used `moto` or `Stubber`, mock the SDK with `aws-smithy-mocks`
(dev-dependency, plus the `test-util` feature on the SDK crate):

```toml
[dev-dependencies]
aws-smithy-mocks = "0.3"
aws-sdk-dynamodb = { version = "1", features = ["test-util"] }
```

```rust
use aws_sdk_dynamodb::operation::put_item::PutItemOutput;
use aws_smithy_mocks::{mock, mock_client};

let put = mock!(aws_sdk_dynamodb::Client::put_item)
    .match_requests(|req| req.table_name() == Some("orders"))
    .then_output(|| PutItemOutput::builder().build());
let client = mock_client!(aws_sdk_dynamodb, [&put]);

store_order(&client, "orders", &order).await.expect("put_item should succeed");
assert_eq!(put.num_calls(), 1);
```

## 4. Semantic traps when moving from Python

- **Missing vs null vs empty**: Python `dict.get` returns `None` for both a missing key and
  `null`. Model optional fields as `Option<T>` with `#[serde(default)]`, and use
  `#[serde(skip_serializing_if = "Option::is_none")]` when the Python output omitted the key.
- **Truthiness**: `if value:` is false for `""`, `0`, `[]`, `{}` and `None`. Write the explicit
  Rust check that matches, for example `!s.is_empty()`.
- **Numbers**: Python ints never overflow and boto3 returns DynamoDB numbers as `Decimal`.
  Pick explicit types (`u64`, `i64`, `rust_decimal::Decimal`) and never use `f64` for money.
- **Strings**: Python slices by code point, Rust by byte. Use `.chars()` when slicing text
  that can contain non-ASCII characters.
- **Exceptions become `Result`**: every `raise` and every `except` maps to an error variant.
  An uncaught Python exception fails the invocation; in Rust, return `Err` for the same cases,
  not `panic!`.
- **Field names**: Python JSON is often camelCase or snake_case inconsistently. Use
  `#[serde(rename_all = "camelCase")]` or per-field `#[serde(rename = "...")]` to match exactly.
- **Dates**: naive `datetime` objects have no time zone. Decide on UTC explicitly and keep
  the Python string format in the output.
- **HTTP responses**: keep the same status codes, headers and error body shape for API Gateway.
- **Global state**: module-level clients in Python become values created in `main` and
  borrowed by the handler.

## 5. Ship it safely

1. Run the quality gate (`scripts/preflight.sh`) and the Python-derived tests.
2. Deploy the Rust function under a new name, with the same IAM role and environment variables.
3. Invoke both functions with the same captured events and diff the outputs:
   `cargo lambda invoke <rust-fn> --remote --data-file events/x.json` against
   `aws lambda invoke --function-name <python-fn> --payload fileb://events/x.json out.json`.
4. Switch the trigger (event source mapping, API Gateway integration or alias) only after the
   user approves, and keep the Python function deployed for rollback.
5. Compare duration, init duration, memory and cost after the switch (see `cold-start.md`).
