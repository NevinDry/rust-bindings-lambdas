use pyo3::prelude::*;

#[pymodule]
mod fib_rust {
    use pyo3::prelude::*;

    #[pyfunction]
    fn fib(n: i64) -> i64 {
        fib_core::fib(n)
    }
}
