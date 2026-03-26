# Disable AWS CLI pager globally
export AWS_PAGER  =

# ─── Function names ──────────────────────────────────────
FN_RUST           = rust-native
FN_PYTHON_BINDING = python-binding
FN_JS_BINDING     = js-binding
FN_JAVA_BINDING   = java-binding
FN_CSHARP_BINDING = csharp-binding
FN_NATIVE_RUST    = rust-lambda-native
FN_NATIVE_PYTHON  = python-native
FN_NATIVE_JS      = js-native
FN_NATIVE_JAVA    = java-native
FN_NATIVE_CSHARP  = csharp-native
ROLE              = arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/lambda-basic-execution-role
PAYLOAD_FILE      = payload.json
ROLE_NAME         = lambda-basic-execution-role
FN_LAMBDA_NATIVE  = rust-lambda-native
# ─── Deploy ──────────────────────────────────────────────
# Usage: make deploy-xxx CREATE=1   → create new function
#        make deploy-xxx            → update existing function code

deploy-lambda-native:
	cd native-lambdas/rust && \
	cargo lambda build --release --output-format zip && \
	if [ "$(CREATE)" = "1" ]; then \
		aws lambda create-function \
			--function-name $(FN_LAMBDA_NATIVE) \
			--role $(ROLE) \
			--runtime provided.al2023 \
			--handler bootstrap \
			--zip-file fileb://target/lambda/rust-lambda-native/bootstrap.zip \
			--timeout 60 --memory-size 256; \
	else \
		aws lambda update-function-code \
			--function-name $(FN_LAMBDA_NATIVE) \
			--zip-file fileb://target/lambda/rust-lambda-native/bootstrap.zip; \
	fi

deploy-python-binding:
	cd python-binding && \
	python3 -m venv .venv && . .venv/bin/activate && \
	pip install maturin && \
	maturin build --release && \
	WHEEL=$$(ls target/wheels/*.whl | head -1) && \
	mkdir -p /tmp/py-binding-pkg && rm -rf /tmp/py-binding-pkg/* && \
	pip install "$$WHEEL" -t /tmp/py-binding-pkg && \
	cp lambda_function.py /tmp/py-binding-pkg/ && \
	cd /tmp/py-binding-pkg && rm -f /tmp/fn.zip && zip -r /tmp/fn.zip . && \
	if [ "$(CREATE)" = "1" ]; then \
		aws lambda create-function \
			--function-name $(FN_PYTHON_BINDING) \
			--role $(ROLE) \
			--runtime python3.12 \
			--handler lambda_function.handler \
			--zip-file fileb:///tmp/fn.zip \
			--timeout 60 --memory-size 256; \
	else \
		aws lambda update-function-code \
			--function-name $(FN_PYTHON_BINDING) \
			--zip-file fileb:///tmp/fn.zip; \
	fi

deploy-js-binding:
	cd javascript-binding && \
	npm install && npm run build && \
	rm -f /tmp/fn.zip && zip -j /tmp/fn.zip lambda.mjs index.js fib-napi.linux-x64-gnu.node && \
	if [ "$(CREATE)" = "1" ]; then \
		aws lambda create-function \
			--function-name $(FN_JS_BINDING) \
			--role $(ROLE) \
			--runtime nodejs20.x \
			--handler lambda.handler \
			--zip-file fileb:///tmp/fn.zip \
			--timeout 60 --memory-size 256; \
	else \
		aws lambda update-function-code \
			--function-name $(FN_JS_BINDING) \
			--zip-file fileb:///tmp/fn.zip && \
		aws lambda wait function-updated \
			--function-name $(FN_JS_BINDING) && \
		aws lambda update-function-configuration \
			--function-name $(FN_JS_BINDING) \
			--handler lambda.handler; \
	fi

deploy-java-binding:
	cd java-binding && \
	mvn clean package -q && \
	cargo build --release && \
	rm -rf /tmp/java-binding-pkg && mkdir -p /tmp/java-binding-pkg/lib && \
	cd /tmp/java-binding-pkg && \
	unzip -q $(CURDIR)/java-binding/target/java-rust-binding-1.0.0.jar && \
	cp $(CURDIR)/java-binding/target/release/libfib_jni.so lib/ && \
	rm -f /tmp/fn.zip && zip -qr /tmp/fn.zip . && \
	if [ "$(CREATE)" = "1" ]; then \
		aws lambda create-function \
			--function-name $(FN_JAVA_BINDING) \
			--role $(ROLE) \
			--runtime java21 \
			--handler FibHandler::handleRequest \
			--zip-file fileb:///tmp/fn.zip \
			--timeout 60 --memory-size 256 \
			--environment "Variables={LD_LIBRARY_PATH=/var/task/lib}"; \
	else \
		aws lambda update-function-code \
			--function-name $(FN_JAVA_BINDING) \
			--zip-file fileb:///tmp/fn.zip; \
	fi

deploy-csharp-binding:
	cd csharp-binding && cargo build --release && \
	cp target/release/libfib_ffi.so . && \
	dotnet publish FibHandler.csproj -c Release -o /tmp/csharp-pkg && \
	cd /tmp/csharp-pkg && rm -f /tmp/fn.zip && zip -r /tmp/fn.zip . && \
	if [ "$(CREATE)" = "1" ]; then \
		aws lambda create-function \
			--function-name $(FN_CSHARP_BINDING) \
			--role $(ROLE) \
			--runtime dotnet8 \
			--handler FibHandler::Function::Handler \
			--zip-file fileb:///tmp/fn.zip \
			--timeout 60 --memory-size 256; \
	else \
		aws lambda update-function-code \
			--function-name $(FN_CSHARP_BINDING) \
			--zip-file fileb:///tmp/fn.zip; \
	fi

# ─── Deploy natives ──────────────────────────────────────

deploy-native-python:
	cd native-lambdas/python && \
	rm -f /tmp/fn.zip && zip -j /tmp/fn.zip lambda_function.py && \
	if [ "$(CREATE)" = "1" ]; then \
		aws lambda create-function \
			--function-name $(FN_NATIVE_PYTHON) \
			--role $(ROLE) \
			--runtime python3.12 \
			--handler lambda_function.handler \
			--zip-file fileb:///tmp/fn.zip \
			--timeout 60 --memory-size 256; \
	else \
		aws lambda update-function-code \
			--function-name $(FN_NATIVE_PYTHON) \
			--zip-file fileb:///tmp/fn.zip; \
	fi

deploy-native-js:
	cd native-lambdas/javascript && \
	rm -f /tmp/fn.zip && zip -j /tmp/fn.zip index.mjs && \
	if [ "$(CREATE)" = "1" ]; then \
		aws lambda create-function \
			--function-name $(FN_NATIVE_JS) \
			--role $(ROLE) \
			--runtime nodejs20.x \
			--handler index.handler \
			--zip-file fileb:///tmp/fn.zip \
			--timeout 60 --memory-size 256; \
	else \
		aws lambda update-function-code \
			--function-name $(FN_NATIVE_JS) \
			--zip-file fileb:///tmp/fn.zip; \
	fi

deploy-native-java:
	cd native-lambdas/java && \
	mvn clean package -q && \
	rm -rf /tmp/java-native-pkg && mkdir /tmp/java-native-pkg && \
	cd /tmp/java-native-pkg && \
	unzip -q $(CURDIR)/native-lambdas/java/target/java-native-1.0.0.jar && \
	rm -f /tmp/fn.zip && zip -qr /tmp/fn.zip . && \
	if [ "$(CREATE)" = "1" ]; then \
		aws lambda create-function \
			--function-name $(FN_NATIVE_JAVA) \
			--role $(ROLE) \
			--runtime java21 \
			--handler FibHandler::handleRequest \
			--zip-file fileb:///tmp/fn.zip \
			--timeout 60 --memory-size 256; \
	else \
		aws lambda update-function-code \
			--function-name $(FN_NATIVE_JAVA) \
			--zip-file fileb:///tmp/fn.zip; \
	fi

deploy-native-csharp:
	cd native-lambdas/csharp && \
	dotnet publish FibNative.csproj -c Release -o /tmp/csharp-native-pkg && \
	cd /tmp/csharp-native-pkg && rm -f /tmp/fn.zip && zip -r /tmp/fn.zip . && \
	if [ "$(CREATE)" = "1" ]; then \
		aws lambda create-function \
			--function-name $(FN_NATIVE_CSHARP) \
			--role $(ROLE) \
			--runtime dotnet8 \
			--handler FibNative::Function::Handler \
			--zip-file fileb:///tmp/fn.zip \
			--timeout 60 --memory-size 256; \
	else \
		aws lambda update-function-code \
			--function-name $(FN_NATIVE_CSHARP) \
			--zip-file fileb:///tmp/fn.zip; \
	fi

deploy-all: deploy-lambda-native deploy-python-binding deploy-js-binding deploy-java-binding deploy-csharp-binding deploy-native-python deploy-native-js deploy-native-java deploy-native-csharp

# ─── Invoke ──────────────────────────────────────────────

invoke-lambda-native:
	@bash invoke.sh $(FN_LAMBDA_NATIVE) 🦀 "Rust Native" $(PAYLOAD_FILE)

invoke-python-binding:
	@bash invoke.sh $(FN_PYTHON_BINDING) 🐍🦀 "Python+Rust (PyO3)" $(PAYLOAD_FILE)

invoke-js-binding:
	@bash invoke.sh $(FN_JS_BINDING) 📜🦀 "JS+Rust (napi-rs)" $(PAYLOAD_FILE)

invoke-java-binding:
	@bash invoke.sh $(FN_JAVA_BINDING) ☕🦀 "Java+Rust (JNI)" $(PAYLOAD_FILE)

invoke-csharp-binding:
	@bash invoke.sh $(FN_CSHARP_BINDING) 🟣🦀 "C#+Rust (FFI)" $(PAYLOAD_FILE)

invoke-native-python:
	@bash invoke.sh $(FN_NATIVE_PYTHON) 🐍🐍 "Python Native" $(PAYLOAD_FILE)

invoke-native-js:
	@bash invoke.sh $(FN_NATIVE_JS) 🟨🟨 "JS Native" $(PAYLOAD_FILE)

invoke-native-java:
	@bash invoke.sh $(FN_NATIVE_JAVA) ☕☕ "Java Native" $(PAYLOAD_FILE)

invoke-native-csharp:
	@bash invoke.sh $(FN_NATIVE_CSHARP) 🟣🟣 "C# Native" $(PAYLOAD_FILE)

# ─── Invoke all ──────────────────────────────────────────

BENCHMARK_FILE := /tmp/lambda-benchmark-results.txt

invoke-all-bindings:
	@rm -f $(BENCHMARK_FILE)
	@BENCHMARK_FILE=$(BENCHMARK_FILE) bash invoke.sh $(FN_LAMBDA_NATIVE) 🦀🦀 "Rust Native" $(PAYLOAD_FILE)
	@BENCHMARK_FILE=$(BENCHMARK_FILE) bash invoke.sh $(FN_PYTHON_BINDING) 🐍🦀 "Python+Rust (PyO3)" $(PAYLOAD_FILE)
	@BENCHMARK_FILE=$(BENCHMARK_FILE) bash invoke.sh $(FN_JS_BINDING) 🟨🦀 "JS+Rust (napi-rs)" $(PAYLOAD_FILE)
	@BENCHMARK_FILE=$(BENCHMARK_FILE) bash invoke.sh $(FN_JAVA_BINDING) ☕🦀 "Java+Rust (JNI)" $(PAYLOAD_FILE)
	@BENCHMARK_FILE=$(BENCHMARK_FILE) bash invoke.sh $(FN_CSHARP_BINDING) 🟣🦀 "C#+Rust (FFI)" $(PAYLOAD_FILE)
	@bash benchmark-table.sh $(BENCHMARK_FILE)

invoke-all-natives:
	@rm -f $(BENCHMARK_FILE)
	@BENCHMARK_FILE=$(BENCHMARK_FILE) bash invoke.sh $(FN_LAMBDA_NATIVE) 🦀🦀 "Rust Native" $(PAYLOAD_FILE)
	@BENCHMARK_FILE=$(BENCHMARK_FILE) bash invoke.sh $(FN_NATIVE_PYTHON) 🐍🐍 "Python Native" $(PAYLOAD_FILE)
	@BENCHMARK_FILE=$(BENCHMARK_FILE) bash invoke.sh $(FN_NATIVE_JS) 🟨🟨 "JS Native" $(PAYLOAD_FILE)
	@BENCHMARK_FILE=$(BENCHMARK_FILE) bash invoke.sh $(FN_NATIVE_JAVA) ☕☕ "Java Native" $(PAYLOAD_FILE)
	@BENCHMARK_FILE=$(BENCHMARK_FILE) bash invoke.sh $(FN_NATIVE_CSHARP) 🟣🟣 "C# Native" $(PAYLOAD_FILE)
	@bash benchmark-table.sh $(BENCHMARK_FILE)

invoke-all:
	@rm -f $(BENCHMARK_FILE)
	@BENCHMARK_FILE=$(BENCHMARK_FILE) bash invoke.sh $(FN_LAMBDA_NATIVE) 🦀🦀 "Rust Native" $(PAYLOAD_FILE)
	@BENCHMARK_FILE=$(BENCHMARK_FILE) bash invoke.sh $(FN_NATIVE_PYTHON) 🐍🐍 "Python Native" $(PAYLOAD_FILE)
	@BENCHMARK_FILE=$(BENCHMARK_FILE) bash invoke.sh $(FN_PYTHON_BINDING) 🐍🦀 "Python+Rust" $(PAYLOAD_FILE)
	@BENCHMARK_FILE=$(BENCHMARK_FILE) bash invoke.sh $(FN_NATIVE_JS) 🟨🟨 "JS Native" $(PAYLOAD_FILE)
	@BENCHMARK_FILE=$(BENCHMARK_FILE) bash invoke.sh $(FN_JS_BINDING) 🟨🦀 "JS+Rust" $(PAYLOAD_FILE)
	@BENCHMARK_FILE=$(BENCHMARK_FILE) bash invoke.sh $(FN_NATIVE_JAVA) ☕☕ "Java Native" $(PAYLOAD_FILE)
	@BENCHMARK_FILE=$(BENCHMARK_FILE) bash invoke.sh $(FN_JAVA_BINDING) ☕🦀 "Java+Rust" $(PAYLOAD_FILE)
	@BENCHMARK_FILE=$(BENCHMARK_FILE) bash invoke.sh $(FN_NATIVE_CSHARP) 🟣🟣 "C# Native" $(PAYLOAD_FILE)
	@BENCHMARK_FILE=$(BENCHMARK_FILE) bash invoke.sh $(FN_CSHARP_BINDING) 🟣🦀 "C#+Rust" $(PAYLOAD_FILE)
	@bash benchmark-table.sh $(BENCHMARK_FILE)

# ─── IAM Role ────────────────────────────────────────────

create-role:
	aws iam create-role \
		--role-name $(ROLE_NAME) \
		--assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
		--query 'Role.Arn' --output text
	aws iam attach-role-policy \
		--role-name $(ROLE_NAME) \
		--policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
	@echo "\nWaiting 10 s for IAM propagation…"
	@sleep 10

# ─── Cleanup ─────────────────────────────────────────────

clean:
	-aws lambda delete-function --function-name $(FN_PYTHON)
	-aws lambda delete-function --function-name $(FN_RUST)
	-aws lambda delete-function --function-name $(FN_PYTHON_BINDING)
	-aws lambda delete-function --function-name $(FN_JS_BINDING)
	-aws lambda delete-function --function-name $(FN_JAVA_BINDING)
	-aws lambda delete-function --function-name $(FN_CSHARP_BINDING)
	-aws lambda delete-function --function-name $(FN_LAMBDA_NATIVE)
