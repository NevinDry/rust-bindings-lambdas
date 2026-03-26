#[no_mangle]
pub extern "C" fn fib(n: i64) -> i64 {
    fib_core::fib(n)
}
