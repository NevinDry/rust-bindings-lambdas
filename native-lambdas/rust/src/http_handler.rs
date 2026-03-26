use lambda_http::{Body, Error, Request, RequestExt, Response};
use std::time::Instant;

pub(crate) async fn function_handler(event: Request) -> Result<Response<Body>, Error> {
    let number: i64 = event
        .query_string_parameters_ref()
        .and_then(|params| params.first("number"))
        .unwrap_or("35")
        .parse()
        .unwrap_or(35);

    let start = Instant::now();
    let result = fib_core::fib(number);
    let elapsed_ms = start.elapsed().as_secs_f64() * 1000.0;

    let body = serde_json::json!({
        "result": result,
        "elapsed_ms": (elapsed_ms * 100.0).round() / 100.0,
        "engine": "rust-native"
    });

    let resp = Response::builder()
        .status(200)
        .header("content-type", "application/json")
        .body(body.to_string().into())
        .map_err(Box::new)?;
    Ok(resp)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;
    use lambda_http::{Request, RequestExt};

    #[tokio::test]
    async fn test_default_number() {
        let request = Request::default();
        let response = function_handler(request).await.unwrap();
        assert_eq!(response.status(), 200);

        let body: serde_json::Value =
            serde_json::from_slice(response.body()).unwrap();
        assert_eq!(body["result"], 9227465); // fib(35)
        assert_eq!(body["engine"], "rust-native");
        assert!(body["elapsed_ms"].as_f64().unwrap() >= 0.0);
    }

    #[tokio::test]
    async fn test_with_number_param() {
        let mut params: HashMap<String, String> = HashMap::new();
        params.insert("number".into(), "10".into());

        let request = Request::default()
            .with_query_string_parameters(params);

        let response = function_handler(request).await.unwrap();
        assert_eq!(response.status(), 200);

        let body: serde_json::Value =
            serde_json::from_slice(response.body()).unwrap();
        assert_eq!(body["result"], 55); // fib(10)
    }
}
