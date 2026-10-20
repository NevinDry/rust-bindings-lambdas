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
└── csharp/                     ← C# native (.NET 10)

python-binding/                 ← Python + Rust (PyO3 / Maturin)
javascript-binding/             ← JavaScript + Rust (napi-rs)
java-binding/                   ← Java + Rust (JNI)
csharp-binding/                 ← C# + Rust (csbindgen / FFI)

.agents/skills/                 ← Agent skills for coding agents (see below)
.claude/skills/                 ← Symlinks so Claude Code picks up the same skills
```

All binding projects reference `rust-lib/` via a Cargo path dependency — there is **no duplicated Rust code**.

## Technologies

| Binding | Language | FFI Technology | Build Tool |
|---------|----------|----------------|------------|
| `python-binding` | Python 3.14 | [PyO3](https://pyo3.rs) | [Maturin](https://www.maturin.rs) |
| `javascript-binding` | Node.js 24 | [napi-rs](https://napi.rs) | [@napi-rs/cli](https://www.npmjs.com/package/@napi-rs/cli) |
| `java-binding` | Java 25 | [JNI](https://docs.rs/jni) | Cargo + Maven |
| `csharp-binding` | .NET 10 | [csbindgen](https://github.com/Cysharp/csbindgen) | Cargo + dotnet |

## Prerequisites

| Requirement | Version | Install guide |
|-------------|---------|---------------|
| Rust | stable | [rustup.rs](https://rustup.rs) |
| cargo-lambda | latest | [cargo-lambda.info](https://www.cargo-lambda.info/guide/installation.html) |
| Python | 3.14 | [python.org](https://www.python.org/downloads/) |
| Maturin | latest | [maturin.rs](https://www.maturin.rs/installation) |
| Node.js | 24+ | [nodejs.org](https://nodejs.org/) |
| Java JDK | 21+ (25 recommended) | [adoptium.net](https://adoptium.net/) |
| Maven | 3.9+ | [maven.apache.org](https://maven.apache.org/install.html) |
| .NET SDK | 10.0+ | [dotnet.microsoft.com](https://dotnet.microsoft.com/download/dotnet/10.0) |
| AWS CLI | v2 | [docs.aws.amazon.com](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) |

After installing Rust, install the additional tooling:

```bash
cargo install cargo-lambda
pipx install maturin        # or: pip install maturin
npm install -g @napi-rs/cli
rustup target add x86_64-unknown-linux-gnu   # cross-compile the Python binding for Lambda
```

## Lambda runtimes

| Function | Runtime |
|----------|---------|
| Rust native | `provided.al2023` |
| Python native / Python + Rust | `python3.14` |
| JavaScript native / JavaScript + Rust | `nodejs24.x` |
| Java native / Java + Rust | `java25` (bytecode compiled for Java 21, runs unchanged on 25) |
| C# native / C# + Rust | `dotnet10` |

All runtimes are on Amazon Linux 2023 and supported until at least 2028 (see the [AWS Lambda runtimes table](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html)). `make deploy-*` without `CREATE=1` only updates code: to move an existing function to a new runtime, run `aws lambda update-function-configuration --function-name <name> --runtime <runtime>`.

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

## Agent skills

This repo ships [Agent Skills](https://agentskills.io) so coding agents (Claude Code, Codex, GitHub Copilot, Cursor, Kiro…) know how to work on it:

| Skill | What it brings | Source |
|-------|----------------|--------|
| `aws-serverless` | AWS's official serverless guidance: Lambda, API Gateway, Step Functions, SAM / CDK, cold starts, troubleshooting | [aws/agent-toolkit-for-aws](https://github.com/aws/agent-toolkit-for-aws) @ `592c235`, Apache-2.0 |
| `rust-skills` | 265 rules for idiomatic, fast and safe Rust | [leonardomso/rust-skills](https://github.com/leonardomso/rust-skills) @ `fd2a861`, MIT |

The skills live in [`.agents/skills/`](.agents/skills); [`.claude/skills/`](.claude/skills) holds symlinks to them for Claude Code. Each folder keeps its upstream license. To refresh them, copy the folders again from the upstream repos.

### Rust × Lambda plugin (Claude Code)

[Emil Lindfors' `rust-lambda` plugin](https://github.com/EmilLindfors/claude-marketplace/tree/main/plugins/rust-lambda) adds cargo-lambda commands (new, build, deploy, cost and cold-start optimization) and a `rust-lambda-expert` agent. Its repository has no license file, so it is not copied here; install it in Claude Code:

```
/plugin marketplace add EmilLindfors/claude-marketplace
/plugin install rust-lambda@lf-marketplace
```
