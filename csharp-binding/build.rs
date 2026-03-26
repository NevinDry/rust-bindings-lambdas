fn main() {
    csbindgen::Builder::default()
        .input_extern_file("src/lib.rs")
        .csharp_dll_name("libfib_ffi")
        .csharp_class_name("NativeMethods")
        .csharp_namespace("FibBindings")
        .generate_csharp_file("NativeMethods.g.cs")
        .unwrap();
}
