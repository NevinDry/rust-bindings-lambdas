use jni::JNIEnv;
use jni::objects::JClass;
use jni::sys::jlong;

#[no_mangle]
pub extern "system" fn Java_FibHandler_fib(
    _env: JNIEnv,
    _class: JClass,
    n: jlong,
) -> jlong {
    fib_core::fib(n)
}

#[no_mangle]
pub extern "system" fn Java_FibTest_fib(
    _env: JNIEnv,
    _class: JClass,
    n: jlong,
) -> jlong {
    fib_core::fib(n)
}
