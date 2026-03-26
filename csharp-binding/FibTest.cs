using System;
using System.Runtime.InteropServices;

long n = args.Length > 0 ? long.Parse(args[0]) : 33;
long result = NativeFib.fib(n);
Console.WriteLine($"fib({n}) = {result}");

static class NativeFib
{
    [DllImport("libfib_ffi", EntryPoint = "fib", CallingConvention = CallingConvention.Cdecl)]
    internal static extern long fib(long n);
}

