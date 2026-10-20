---
name: rust-lambda
description: Build, test and deploy AWS Lambda functions in Rust with cargo-lambda, lambda_runtime, lambda_http and aws_lambda_events. Use when writing or changing a Lambda or serverless function in Rust, porting a Python or Node.js Lambda to Rust, running cargo lambda commands, or tuning cold starts, ARM64/Graviton builds and binary size of a Rust Lambda.
compatibility: Needs a Rust toolchain and cargo-lambda (https://www.cargo-lambda.info). Deploying needs AWS credentials.
metadata:
  author: Etienne Puissant
  version: "1.0"
---

# Rust on AWS Lambda with cargo-lambda

Follow the workflow in order. The Rust compiler and clippy are your reviewers:
when they complain, fix the code, never silence them.

## 0. Check the tools

```bash
cargo lambda --version
```

If it is missing, ask the user to install it (`brew install cargo-lambda/tap/cargo-lambda`,
`pip3 install cargo-lambda` or `cargo binstall cargo-lambda`; see https://www.cargo-lambda.info/guide/installation.html).
cargo-lambda cross-compiles to Linux with Zig, so no Docker is needed.

## 1. Scaffold

```bash
cargo lambda new my-function --event-type sqs::SqsEvent -y   # event-driven function
cargo lambda new my-api --http -y                             # API Gateway, ALB or function URL
cargo lambda init --event-type s3::S3Event -y                 # inside an existing directory
```

`--event-type` takes any `module::Type` from `aws_lambda_events` (`s3::S3Event`,
`sqs::SqsEvent`, `eventbridge::EventBridgeEvent`, `dynamodb::Event`, `kinesis::KinesisEvent`...).
`-y` skips the interactive prompts, which an agent cannot answer.

## 2. Write the handler

Pick the crate by trigger:

| Trigger | Crate | Handler signature |
|---|---|---|
| SQS, S3, EventBridge, DynamoDB Streams, Kinesis, SNS, custom JSON | `lambda_runtime` + `aws_lambda_events` | `async fn(LambdaEvent<E>) -> Result<R, Error>` |
| API Gateway (REST/HTTP), ALB, function URL, VPC Lattice | `lambda_http` | `async fn(Request) -> Result<Response<Body>, Error>` |

Enable only the event features you use, for example
`aws_lambda_events = { version = "1", default-features = false, features = ["sqs"] }`.
Add crates with `cargo add`, never by guessing versions.

Reference shape (SQS → DynamoDB with partial batch failures). Copy the structure, not the domain:

```rust
use aws_lambda_events::event::sqs::{SqsBatchResponse, SqsEvent, SqsMessage};
use aws_sdk_dynamodb::types::AttributeValue;
use lambda_runtime::{run, service_fn, tracing, Error, LambdaEvent};
use serde::Deserialize;

#[derive(Debug, Deserialize)]
struct Order {
    id: String,
    amount_cents: u64,
}

#[derive(Debug, thiserror::Error)]
enum OrderError {
    #[error("message has no body")]
    MissingBody,
    #[error("invalid order payload: {0}")]
    InvalidPayload(#[from] serde_json::Error),
    #[error("amount must be positive")]
    ZeroAmount,
    // Boxed: SDK errors are large, and clippy::result_large_err flags them.
    #[error("dynamodb put_item failed: {0}")]
    Store(#[from] Box<aws_sdk_dynamodb::Error>),
}

/// Pure parsing and validation: no I/O, so it is unit-tested directly.
fn parse_order(message: &SqsMessage) -> Result<Order, OrderError> {
    let body = message.body.as_deref().ok_or(OrderError::MissingBody)?;
    let order: Order = serde_json::from_str(body)?;
    if order.amount_cents == 0 {
        return Err(OrderError::ZeroAmount);
    }
    Ok(order)
}

async fn store_order(
    client: &aws_sdk_dynamodb::Client,
    table: &str,
    order: &Order,
) -> Result<(), OrderError> {
    client
        .put_item()
        .table_name(table)
        .item("id", AttributeValue::S(order.id.clone()))
        .item("amount_cents", AttributeValue::N(order.amount_cents.to_string()))
        .send()
        .await
        .map_err(|err| Box::new(aws_sdk_dynamodb::Error::from(err)))?;
    Ok(())
}

async fn function_handler(
    client: &aws_sdk_dynamodb::Client,
    table: &str,
    event: LambdaEvent<SqsEvent>,
) -> Result<SqsBatchResponse, Error> {
    let mut response = SqsBatchResponse::default();
    for message in &event.payload.records {
        let message_id = message.message_id.as_deref().unwrap_or_default();
        let result = match parse_order(message) {
            Ok(order) => store_order(client, table, &order).await,
            Err(err) => Err(err),
        };
        if let Err(err) = result {
            tracing::warn!(message_id, error = %err, "order rejected");
            response.add_failure(message_id);
        }
    }
    Ok(response)
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    tracing::init_default_subscriber();

    // Init phase: runs once per execution environment, reused by every invocation.
    let config = aws_config::load_from_env().await;
    let client = aws_sdk_dynamodb::Client::new(&config);
    let table = std::env::var("TABLE_NAME")?;

    run(service_fn(|event: LambdaEvent<SqsEvent>| {
        function_handler(&client, &table, event)
    }))
    .await
}
```

Dependencies for it: `cargo add aws-config --features behavior-version-latest`,
`cargo add aws-sdk-dynamodb serde --features serde/derive`, `cargo add serde_json thiserror`.
`SqsBatchResponse` only works if the event source mapping has `ReportBatchItemFailures`
enabled; otherwise return `Err` and the whole batch is retried.

For HTTP, the same pattern holds: build state in `main`, borrow it in the closure.

```rust
run(service_fn(|event: Request| function_handler(&state, event))).await
```

## 3. Local test loop

```bash
cargo lambda watch                                   # terminal 1: emulator on :9000, hot reload
cargo lambda invoke my-function --data-example sqs-event        # terminal 2: AWS sample payload
cargo lambda invoke my-function --data-file events/order.json   # your own fixture
curl "http://localhost:9000/lambda-url/my-api/?name=demo"       # lambda_http functions
```

- Pass environment variables with `cargo lambda watch --env-var TABLE_NAME=orders`
  or `[package.metadata.lambda.env]` in `Cargo.toml`.
- Keep real payloads captured from CloudWatch in `events/` and reuse them in tests.
- Run `cargo lambda watch` in the background and stop it when you are done.

## 4. Quality gate (must pass before any build for deployment)

```bash
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
```

Or run `scripts/preflight.sh`, which runs the three and then the release build.
Do not deploy while any of them fails. Do not add `#[allow(...)]` to get past clippy
unless the user agrees and the reason is written next to it.

## 5. Build

```bash
cargo lambda build --release --arm64                       # target/lambda/<name>/bootstrap
cargo lambda build --release --arm64 --output-format zip   # bootstrap.zip for SAM/CDK/Terraform
```

Default to `--arm64` (Graviton: cheaper per GB-second, usually faster for Rust).
cargo-lambda already strips symbols and sets `lto = "thin"`, `codegen-units = 1` and
`panic = "abort"` in release mode. See [references/cold-start.md](references/cold-start.md)
before tuning anything further.

## 6. Deploy (ask the user first)

Deploying changes a real AWS account. Confirm the account, region and function name
with the user before running:

```bash
cargo lambda deploy my-function --iam-role arn:aws:iam::123456789012:role/my-function-role \
  --env-var TABLE_NAME=orders --memory 256 --timeout 10
cargo lambda invoke my-function --remote --data-file events/order.json
```

- `deploy` detects the architecture from the built binary and uses the `provided.al2023` runtime.
- Without `--iam-role`, it creates a role with only `AWSLambdaBasicExecutionRole`.
- If the project uses SAM, CDK, Terraform or CloudFormation, do not use `cargo lambda deploy`:
  build the zip and let the infrastructure code ship it.

## Guardrails

- **No `unwrap()` or `expect()` in handler code paths.** Return errors with `?` and a typed
  error (`thiserror`), or `lambda_runtime::Error`. They are fine in tests and in `main`
  for configuration that must exist at start-up.
- **Create SDK clients and config once, in `main`**, then pass `&Client` into the handler.
  Never call `aws_config::load_from_env()` or `Client::new()` inside the handler.
- **Borrow, do not clone.** Avoid `.clone()` to satisfy the borrow checker; pass references.
  Shared read-only state needs no `Arc<Mutex<_>>`: borrow it from `main` as above. Reach for
  `Arc` or a lock only when state is mutated across concurrent tasks, and say why.
- **Log with `tracing`**, never `println!`. Use structured fields
  (`tracing::info!(order_id = %id, "stored")`), not interpolated strings. `init_default_subscriber()`
  honours `RUST_LOG` and Lambda's JSON log format setting. Never log secrets or whole payloads with PII.
- **Separate pure logic from I/O** so most behaviour is tested without AWS.
- **Respect the timeout.** No unbounded retries or loops; let the SDK's retry config work.
- **Keep dependencies lean**: every crate adds compile time, binary size and init time.

## Reference files

- [references/porting-from-python.md](references/porting-from-python.md): read when the
  task is to rewrite an existing Python Lambda in Rust.
- [references/cold-start.md](references/cold-start.md): read when the user cares about cold
  starts, init duration, binary size or cost.
- `scripts/preflight.sh`: fmt, clippy, tests and the ARM64 release build in one command.
