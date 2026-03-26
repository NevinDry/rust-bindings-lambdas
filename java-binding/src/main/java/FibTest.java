public class FibTest {
    static {
        System.loadLibrary("fib_jni");
    }

    private static native long fib(long n);

    public static void main(String[] args) {
        long n = args.length > 0 ? Long.parseLong(args[0]) : 33;
        long result = fib(n);
        System.out.println("fib(" + n + ") = " + result);
    }
}
