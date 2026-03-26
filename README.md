# Rust Fibonacci — Multi-Language Lambda Bindings

This project demonstrates how a **single Rust function** can be shared across multiple programming languages using AWS Lambda. A recursive Fibonacci function written in Rust is exposed to **Python**, **JavaScript**, **Java**, and **C#** via their respective FFI binding technologies — and compared against each language's pure native implementation.

## Architecture

```
rust-lib/                       ← Shared pure Rust library (fib-core)
├── Cargo.toml
└── src/lib.rs                  ← pub fn fib(n: i64) -> i64

native-lambdas/                 ← Pure native implementations (no Rust)
├── rust/                       ← Rust native (cargo-lambda)
├── python/                     ← Python native
├── javascript/                 ← JavaScript native (ESM)
├── java/                       ← Java native (Maven)
└── csharp/                     ← C# native (.NET 8)

python-binding/                 ← Python + Rust (PyO3 / Maturin)
javascript-binding/             ← JavaScript + Rust (napi-rs)
java-binding/                   ← Java + Rust (JNI)
csharp-binding/                 ← C# + Rust (csbindgen / FFI)
```

All binding projects reference `rust-lib/` via a Cargo path dependency — there is **no duplicated Rust code**.

## Technologies

| Binding | Language | FFI Technology | Build Tool |
|---------|----------|----------------|------------|
| `python-binding` | Python 3.12 | [PyO3](https://pyo3.rs) | [Maturin](https://www.maturin.rs) |
| `javascript-binding` | Node.js 20 | [napi-rs](https://napi.rs) | [@napi-rs/cli](https://www.npmjs.com/package/@napi-rs/cli) |
| `java-binding` | Java 21 | [JNI](https://docs.rs/jni) | Cargo + Maven |
| `csharp-binding` | .NET 8 | [csbindgen](https://github.com/Cysharp/csbindgen) | Cargo + dotnet |

## Prerequisites

| Requirement | Version | Install guide |
|-------------|---------|---------------|
| Rust | stable | [rustup.rs](https://rustup.rs) |
| cargo-lambda | latest | [cargo-lambda.info](https://www.cargo-lambda.info/guide/installation.html) |
| Python | 3.12+ | [python.org](https://www.python.org/downloads/) |
| Maturin | latest | [maturin.rs](https://www.maturin.rs/installation) |
| Node.js | 20+ | [nodejs.org](https://nodejs.org/) |
| Java JDK | 21+ | [adoptium.net](https://adoptium.net/) |
| Maven | 3.9+ | [maven.apache.org](https://maven.apache.org/install.html) |
| .NET SDK | 8.0+ | [dotnet.microsoft.com](https://dotnet.microsoft.com/download/dotnet/8.0) |
| AWS CLI | v2 | [docs.aws.amazon.com](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) |

After installing Rust, install the additional tooling:

```bash
cargo install cargo-lambda
pipx install maturin        # or: pip install maturin
npm install -g @napi-rs/cli
```

## AWS Setup

### 1. Configure AWS credentials

```bash
aws configure
```

### 2. Set your AWS Account ID

Edit `Makefile` and update:

```makefile
ROLE = arn:aws:iam::YOUR_ACCOUNT_ID:role/lambda-basic-execution-role
```

### 3. Create the Lambda execution role

```bash
make create-role
```

## Deploying to AWS Lambda

### First-time creation (all functions)

```bash
make deploy-all CREATE=1
```

### Individual deployments

| Command | Description |
|---------|-------------|
| `make deploy-lambda-native CREATE=1` | Rust native Lambda |
| `make deploy-python-binding CREATE=1` | Python + Rust binding |
| `make deploy-js-binding CREATE=1` | JavaScript + Rust binding |
| `make deploy-java-binding CREATE=1` | Java + Rust binding |
| `make deploy-csharp-binding CREATE=1` | C# + Rust binding |
| `make deploy-native-python CREATE=1` | Python native Lambda |
| `make deploy-native-js CREATE=1` | JavaScript native Lambda |
| `make deploy-native-java CREATE=1` | Java native Lambda |
| `make deploy-native-csharp CREATE=1` | C# native Lambda |

Drop `CREATE=1` to update an already-deployed function.

## Invoking & Benchmarking

```bash
# Invoke all lambdas (natives + bindings) and display benchmark table
make invoke-all

# Only native language lambdas
make invoke-all-natives

# Only Rust-binding lambdas
make invoke-all-bindings

# Individual invocations
make invoke-lambda-native
make invoke-python-binding
make invoke-js-binding
make invoke-java-binding
make invoke-csharp-binding
make invoke-native-python
make invoke-native-js
make invoke-native-java
make invoke-native-csharp
```

The benchmark table shows two timing columns:
- **invocation ms** — wall-clock time client-side (includes network + runtime startup)
- **fib only ms** — pure computation time measured inside the Lambda function

## Payload

All Lambda functions expect an API Gateway v2 event with a `queryStringParameters.number` field (see [payload.json](payload.json)):

```json
{
  "queryStringParameters": {
    "number": "33"
  }
}
```

## Cleanup

```bash
make clean
```
