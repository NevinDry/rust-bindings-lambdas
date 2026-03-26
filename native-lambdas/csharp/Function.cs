using System;
using System.Diagnostics;
using System.Text.Json;
using Amazon.Lambda.Core;

[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

public class Function
{
    private static long Fib(long n)
    {
        if (n <= 1) return n;
        return Fib(n - 1) + Fib(n - 2);
    }

    public object Handler(JsonElement input, ILambdaContext context)
    {
        var queryParams = input.GetProperty("queryStringParameters");
        long number = long.Parse(queryParams.GetProperty("number").GetString() ?? "33");

        context.Logger.LogLine($"Starting fib({number})");

        var sw = Stopwatch.StartNew();
        var result = Fib(number);
        sw.Stop();
        var elapsedMs = sw.Elapsed.TotalMilliseconds;

        context.Logger.LogLine("Done");

        return new
        {
            statusCode = 200,
            body = JsonSerializer.Serialize(new
            {
                result = result,
                elapsed_ms = Math.Round(elapsedMs, 2),
                engine = "csharp-native"
            })
        };
    }
}
