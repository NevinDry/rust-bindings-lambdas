use napi_derive::napi;

#[napi]
fn fib(n: i64) -> i64 {
    fib_core::fib(n)
}
