# Cold starts, binary size and cost

A cold start is the Init phase: Lambda downloads the package, starts the `bootstrap`
binary and runs `main` until the runtime asks for the first event. Rust has no interpreter
or JIT to warm up, so most of the remaining Init time is binary size and whatever your
`main` does. Measure before and after every change; do not tune blind.

## 1. Measure init duration

Each cold invocation's `REPORT` log line has an `Init Duration`. In CloudWatch Logs Insights,
on the function's log group:

```
filter @type = "REPORT" and ispresent(@initDuration)
| stats count() as coldStarts,
        avg(@initDuration) as avgInitMs,
        pct(@initDuration, 99) as p99InitMs,
        avg(@duration) as avgDurationMs,
        max(@maxMemoryUsed) / 1000 / 1000 as maxMemoryMB
  by bin(1h)
```

To force a cold start while testing, change the function configuration (redeploying with
`cargo lambda deploy` does it), then invoke once with
`cargo lambda invoke <name> --remote --data-file events/x.json`.

Check the artifact size too:

```bash
cargo lambda build --release --arm64 --output-format zip
ls -lh target/lambda/*/bootstrap target/lambda/*/bootstrap.zip
```

## 2. Release profile

`cargo lambda build --release` already applies, unless `Cargo.toml` overrides them:
symbols stripped, `lto = "thin"`, `codegen-units = 1`, `panic = "abort"`, and a CPU target
of Neoverse N1 on ARM64 (Haswell on x86_64). `--disable-optimizations` turns these off.

To go further, set the profile explicitly in `Cargo.toml` and measure:

```toml
[profile.release]
opt-level = 3        # Rust default: fastest code. Try "s" or "z" only if a smaller binary
                     # measurably improves init without slowing invocations.
lto = "fat"          # Whole-program LTO: smaller and often faster, longer compile.
codegen-units = 1    # Better optimisation, slower compile.
strip = true         # No symbols in the shipped binary.
panic = "abort"      # Smaller binary. A panic kills the execution environment, and the
                     # next request pays a cold start: one more reason for no unwrap().
```

Keep `.cargo/config.toml` `rustflags` as an array (`rustflags = ["--cfg", "x"]`), so
cargo-lambda can merge its own `target-cpu` flag with yours.

## 3. Build for ARM64

```bash
cargo lambda build --release --arm64
```

Graviton (arm64) is billed lower per GB-second than x86_64 and Rust compiles natively for it.
`cargo lambda deploy` detects the architecture from the binary. If you deploy with SAM,
CDK or Terraform, set the function's architecture to `arm64` there as well.

## 4. Keep dependencies lean

- Turn off default features you do not need, starting with
  `aws_lambda_events = { version = "1", default-features = false, features = ["sqs"] }`.
- Use one TLS stack. Check for duplicates with `cargo tree -d` and `cargo tree -e features -i openssl`
  (or `-i native-tls`); prefer `rustls` everywhere.
- One async runtime: `tokio`, already required by `lambda_runtime`. Do not add another.
- Only the AWS SDK crates you call (`aws-sdk-dynamodb`, not a meta crate).
- Before adding a crate for one function, check whether the standard library already does it.
- Optional: `cargo install cargo-bloat` then `cargo bloat --release --crates` shows which
  crates take the most space.

## 5. Keep `main` cheap, and the handler cheaper

- Build `aws_config` and SDK clients once in `main`. Creating them is cheap; recreating them
  per invocation throws away connection pools and TLS sessions.
- Do not make network calls in `main` that not every invocation needs (for example loading
  a large config from S3). If a secret is needed on every request, fetching it once in
  `main` is right; if only on some paths, fetch lazily with `tokio::sync::OnceCell`.
- Do not parse large embedded files at start-up unless every invocation uses them.

## 6. Memory and CPU

Lambda allocates CPU in proportion to memory. Rust functions often run well at 128 to 256 MB,
but CPU-bound handlers can be cheaper overall at higher memory because they finish faster.
Compare duration and cost at several sizes (`cargo lambda deploy --memory 256`), or use the
open-source AWS Lambda Power Tuning tool to sweep memory settings automatically.

## Checklist

- [ ] `Init Duration` and `Duration` measured before the change
- [ ] Built with `--release --arm64`
- [ ] No duplicate TLS or async runtime in `cargo tree -d`
- [ ] SDK clients created once in `main`
- [ ] No network call in `main` that only some requests need
- [ ] Memory size chosen from measurements
- [ ] `Init Duration` and `Duration` measured after the change
