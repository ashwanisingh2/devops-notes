---
tags: [devops, monitoring, tracing, observability]
aliases: [Distributed Tracing]
created: 2025-06-27
status: #complete
difficulty: #advanced
cert-relevant: #none
---

# MON-04 Distributed Tracing

> [!abstract] Overview
> In a monolithic application, debugging a slow request is easy: you look at a single log file and read the function timings from top to bottom. In a modern microservices architecture, a single user click might trigger a journey across an API Gateway, an Auth Service, an Inventory Service, and a Database, jumping across 5 different servers. When that request takes 10 seconds, which service caused the delay? Metrics and Logs cannot easily answer this. Distributed Tracing (the 3rd pillar of observability) maps the entire lifecycle of a request as it traverses the network, allowing you to pinpoint the exact bottleneck in milliseconds.

---

## Concept Overview

- **What it is** — A method to track a single request as it flows through a distributed system. It uses **OpenTelemetry** standards to inject and propagate a unique Trace ID through HTTP headers. Tools like Jaeger or Grafana Tempo collect and visualize this data as a timeline (Gantt chart).
- **Why DevOps engineers use it** — Microservice debugging. It visually exposes the critical path of a request. You can instantly see if a 5-second delay was caused by a slow database query, network latency between two pods, or a bottlenecked third-party API.
- **Where you encounter this in a real job** — Instrumenting a Python backend with the OpenTelemetry SDK, configuring an Nginx Ingress Controller to generate Trace IDs, or using Jaeger UI to prove to the database team that their query is the root cause of a latency spike.
- **Responsibility Split:**
  - **Junior DevOps**: Views traces in Jaeger/Tempo UI to find out which service threw a 500 error.
  - **Mid DevOps**: Configures the OpenTelemetry Collector in Kubernetes and manages backend storage (Elasticsearch/S3) for trace data.
  - **Senior/SRE**: Enforces W3C TraceContext standards across polyglot teams (Java/Node/Go), implements smart sampling strategies (so you don't overwhelm storage with 100% of traces), and integrates trace IDs into standard application logs.

*Seedha simple mein: Tracing ek GPS tracker jaisa hai. Jab customer order place karta hai, us request pe ek GPS tag (Trace ID) lag jata hai. Jaise-jaise wo request alag-alag departments (microservices) mein jati hai, GPS location aur time note karta rehta hai. End mein aap map pe dekh sakte ho ki courier traffic mein kahan phasa tha.*

---

## Technical Deep Dive

### 1. The Anatomy of a Trace
- **Trace**: The entire journey of a single request (e.g., "Checkout Cart"). Represented by a globally unique `Trace ID`.
- **Span**: A single logical unit of work within a trace (e.g., "Authenticate User", "Query Database"). Each span has a `Span ID`, a start time, duration, and a Parent Span ID (to build the tree structure).
- **Context Propagation**: The mechanism of passing the Trace ID from Service A to Service B. Usually done by injecting standard HTTP headers (like the W3C standard `traceparent` header).

### 2. OpenTelemetry (OTel)
Historically, tracing was a mess of competing vendor SDKs (Zipkin vs Jaeger vs Datadog). **OpenTelemetry** is the CNCF standard that unified this.
- Developers use OTel SDKs to instrument their code. (Many languages support *auto-instrumentation*, where you don't even have to change your code; the SDK wraps HTTP and DB libraries automatically).
- The code sends the spans to the **OpenTelemetry Collector** (a vendor-agnostic proxy).
- The Collector processes the spans and exports them to your backend of choice (Jaeger, Tempo, Datadog, NewRelic).

### 3. Sampling Strategies
A high-traffic API might process 10,000 requests per second. Saving tracing data for all of them would require petabytes of storage and bankrupt the company.
- **Head-based Sampling**: A random decision made at the start of the request (e.g., "Only trace 1% of all requests"). Simple, but you might miss the 1% of traces that contain rare errors.
- **Tail-based Sampling**: Traces are held in memory temporarily. The Collector waits until the trace is finished, then decides: "Did this trace contain an error or take > 5 seconds? If yes, keep it. If it was a normal, fast request, throw it away." This ensures you keep 100% of the *interesting* traces while saving disk space.

---

## Step-by-Step Lab (Mental Architecture)

> [!warning] Pre-requisites
> - Understanding of Docker Compose and Microservices

### Step 1: The Code (Auto-Instrumentation)
Imagine a simple Node.js Express API calling a downstream Python service. You don't rewrite the code. You simply run it with the OpenTelemetry wrapper:
```bash
# Node.js
export OTEL_EXPORTER_OTLP_ENDPOINT="http://otel-collector:4317"
export OTEL_SERVICE_NAME="frontend-node"
node --require @opentelemetry/auto-instrumentations-node app.js

# Python
export OTEL_EXPORTER_OTLP_ENDPOINT="http://otel-collector:4317"
export OTEL_SERVICE_NAME="backend-python"
opentelemetry-instrument python app.py
```

### Step 2: Configure the OpenTelemetry Collector
The Collector receives data, processes it, and sends it to Jaeger for visualization.
```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc: # Receives traces from the SDKs

processors:
  batch: # Batches spans for better performance

exporters:
  jaeger:
    endpoint: "jaeger-all-in-one:14250"
    tls:
      insecure: true
  logging:
    loglevel: debug

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [jaeger, logging]
```

### Step 3: Visualize in Jaeger UI
1. The user makes an HTTP request to the Node.js frontend.
2. The Node.js auto-instrumentation generates a `Trace ID` and a `Span ID`, records the start time, and sends the request to the Python backend, injecting the `traceparent` HTTP header.
3. The Python backend reads the header, creates a child `Span ID`, runs a Database query, finishes, and replies.
4. Both SDKs send their spans to the OTel Collector, which forwards them to Jaeger.
5. You open the **Jaeger UI** (`http://localhost:16686`), search for the `frontend-node` service.
6. You see a beautiful waterfall Gantt chart:
   - `frontend-node: HTTP GET /checkout` (Total: 2.5s)
     - `backend-python: HTTP POST /process` (Duration: 2.4s)
       - `backend-python: SQL SELECT * FROM users` (Duration: 2.3s)
7. **Conclusion**: The bottleneck is undeniably the SQL database query.

> [!tip] Pro Tip
> Tracing is useless if you can't tie it to your logs. Always configure your application's logger (like Logback in Java or Winston in Node) to inject the `Trace ID` into every single log line. That way, when you find an error in Kibana, you can copy the Trace ID, paste it into Jaeger, and instantly see the full network context of that exact request.

---

## Common Commands Cheat Sheet
*(Tracing is mostly code/config, but here are key concepts)*

| Concept / Header | What It Does | Real Example |
|------------------|-------------|--------------|
| `traceparent:` | W3C Standard HTTP header for propagation | `traceparent: 00-4bf92f...-00` |
| `OTEL_SERVICE_NAME` | Environment var defining the app's name in UI | `export OTEL_SERVICE_NAME="auth-api"` |
| `B3 Headers` | Legacy Zipkin headers (X-B3-TraceId) | `X-B3-TraceId: 463ac35c9f6413ad` |
| `Span` | A single operation with start/end times | SQL Query execution |
| `Baggage` | Key/Value pairs passed down the entire trace | `baggage: userId=123,tier=premium` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| Traces are broken into multiple disconnected pieces in UI | Context Propagation Failure | Service B is not reading the HTTP headers sent by Service A, or Service B is not passing them to Service C. Ensure all services use the same propagation format (e.g., W3C). |
| Jaeger UI is empty | Collector exporter failure | Check the OTel Collector logs. It might be failing to reach Jaeger due to network issues or wrong gRPC ports (usually 4317 or 14250). |
| High CPU on application servers | 100% Trace Sampling | Generating and exporting spans for every single request adds latency and CPU overhead. Implement Head-based sampling in the SDK (e.g., `OTEL_TRACES_SAMPLER="traceidratio"`, `OTEL_TRACES_SAMPLER_ARG="0.1"` for 10%). |
| Database calls don't show up in trace | Missing DB instrumentation | Auto-instrumentation libraries must explicitly support the specific DB driver (e.g., `pg` for Postgres, `mongoose` for Mongo). If unsupported, you must write manual spans in the code. |
| OTel Collector running out of memory | Unbounded processing | Always use the `memory_limiter` processor in the OTel Collector config to drop spans if memory hits 90%, preventing the Collector pod from being OOMKilled by Kubernetes. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A user submits a payment. The API Gateway takes 10 seconds to respond, resulting in a timeout. The Payment API logs show it processed the request in 100ms. The Gateway logs show it waited 10 seconds. Both teams blame each other, or the network."

**What Junior DevOps Does:**
Looks at the CPU metrics of both pods, sees they are normal. Pings the network IP, sees latency is 1ms. Is completely stuck and escalates.

**Escalation Trigger:**
Inter-team finger-pointing. Without observability into the network transit, resolving the bug is impossible.

**Senior Engineer Resolution:**
1. Opens Jaeger and searches for traces with a duration > 9 seconds.
2. Finds the specific Trace ID for the failed payment.
3. Examines the span waterfall:
   - `Gateway Span`: Starts at 0.0s, ends at 10.0s.
   - `Auth Service Span`: Starts at 0.1s, ends at 9.8s. (WAIT. Auth service? The devs didn't mention this!)
   - `Auth DB Span`: Starts at 0.2s, ends at 9.7s.
   - `Payment API Span`: Starts at 9.8s, ends at 9.9s.
4. The Senior shows the trace to the developers. The trace visually proves that the Gateway called the Auth Service *before* calling the Payment Service, and the Auth Database was locked, causing a 9-second delay.
5. The Database team optimizes the Auth DB lock, and latency drops back to 200ms.

**Lesson Learned:**
In complex systems, developers often don't even know the exact path their requests take. Distributed Tracing acts as the ultimate source of truth for architectural flow.

---

## Interview Questions

**Q1 (Conceptual):** What are the "Three Pillars of Observability"?
**A:** 1. **Metrics** (Prometheus): Highly aggregated numerical data showing the overall health and trends (Is there a problem?). 2. **Logs** (ELK): Discrete, timestamped text records of events (What exactly went wrong?). 3. **Traces** (Jaeger): The context of a single request flowing through a distributed system (Where exactly did the delay/error occur in the chain?).

**Q2 (Practical):** Your company wants to switch from Datadog to Jaeger for tracing. Currently, all developers have hardcoded Datadog SDKs in their Python applications. How does OpenTelemetry solve this for the future?
**A:** OpenTelemetry (OTel) provides a vendor-neutral standard. If the developers replace the Datadog SDK with the OTel SDK, the application will just emit standard OTel spans to an OTel Collector. In the Collector's YAML configuration, I can simply change the "exporter" from Datadog to Jaeger, without requiring the developers to rewrite a single line of code ever again.

**Q3 (Scenario-based):** You notice that your Jaeger database is filling up with terabytes of data, but 99.9% of those traces are perfectly fast, successful HTTP 200 requests that nobody will ever look at. How do you fix this?
**A:** I need to implement **Tail-based Sampling** at the OpenTelemetry Collector level. The Collector will hold traces in memory and evaluate them after they finish. I configure a policy to drop all fast, successful requests, and ONLY export traces to Jaeger if they contain an HTTP 5xx error or if their total duration exceeded a specific threshold.

**Q4 (Deep dive):** Explain the mechanism of "Context Propagation" in distributed tracing.
**A:** When Service A receives a request, it generates a unique Trace ID. When Service A makes an HTTP call to Service B, it must pass this ID along, otherwise Service B will generate a new, disconnected Trace ID. It does this by injecting standard HTTP headers (like `traceparent`) into the outbound HTTP request. Service B's tracing SDK extracts this header, adopts the Trace ID, and creates a child Span ID, linking the two services together in the final visualization.

**Q5 (Trick/Gotcha):** Can you implement Distributed Tracing if you do not have control over the application code (e.g., closed-source legacy software)?
**A:** Yes, partially. You can use a Service Mesh (like Istio or Linkerd) or an Ingress Controller (like Nginx). These network proxies can intercept the incoming/outgoing traffic, automatically generate Trace IDs, and emit spans showing the network transit time between components, even if the application inside the container is completely unaware of tracing.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[08-Monitoring-and-Observability/MON-01 Prometheus and Grafana|Metrics]]
[[08-Monitoring-and-Observability/MON-02 ELK Stack - Log Management|Logging]]
