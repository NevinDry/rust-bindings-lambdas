import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.google.gson.Gson;
import java.util.Map;

public class FibHandler implements RequestHandler<Map<String, Object>, Map<String, Object>> {

    private static final Gson gson = new Gson();

    private static long fib(long n) {
        if (n <= 1) return n;
        return fib(n - 1) + fib(n - 2);
    }

    @Override
    @SuppressWarnings("unchecked")
    public Map<String, Object> handleRequest(Map<String, Object> event, Context context) {
        Map<String, String> queryStringParameters =
            (Map<String, String>) event.get("queryStringParameters");
        long number = Long.parseLong(queryStringParameters.getOrDefault("number", "33"));

        context.getLogger().log("Starting fib(" + number + ")");

        long start = System.nanoTime();
        long result = fib(number);
        double elapsedMs = (System.nanoTime() - start) / 1_000_000.0;

        context.getLogger().log("Done");

        return Map.of(
            "statusCode", 200,
            "body", gson.toJson(Map.of(
                "result", result,
                "elapsed_ms", Math.round(elapsedMs * 100.0) / 100.0,
                "engine", "java-native"
            ))
        );
    }
}
