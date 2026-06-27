---
tags: [devops, monitoring, prometheus, grafana]
aliases: [Prometheus & Grafana]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #none
---

# MON-01 Prometheus and Grafana

> [!abstract] Overview
> If your server crashes in the middle of the night and no one is awake to see it, how do you know what happened? You don't. Monitoring is the sensory nervous system of DevOps. Prometheus (for collecting metrics) and Grafana (for visualizing them) form the undisputed open-source standard for monitoring modern infrastructure, especially in Kubernetes environments. Without them, you are flying blind.

---

## Concept Overview

- **What it is** — **Prometheus** is a time-series database (TSDB) that pulls (scrapes) metrics from your servers. **Grafana** is a dashboarding tool that reads data from Prometheus and turns it into beautiful, human-readable graphs.
- **Why DevOps engineers use it** — To gain visibility. Instead of waiting for a customer to complain that the website is slow, you look at a Grafana dashboard and instantly see that the database CPU is at 99%.
- **Where you encounter this in a real job** — Setting up `node_exporter` on a fleet of EC2 instances, writing PromQL queries to calculate the 95th percentile latency of a Node.js API, or building a Grafana dashboard for the CEO showing active user sessions.
- **Responsibility Split:**
  - **Junior DevOps**: Checks dashboards during an incident and looks for spikes/dips.
  - **Mid DevOps**: Installs exporters, modifies `prometheus.yml` to scrape new targets, and builds custom Grafana dashboards.
  - **Senior/SRE**: Writes complex PromQL aggregations, manages Prometheus data retention/storage scaling (using Thanos/Cortex), and defines strict alerting rules.

*Seedha simple mein: Prometheus ek reporter hai jo har 15 second mein har server ke paas jaata hai aur poochta hai "Bhai tera CPU kitna hai? RAM kitna bacha hai?". Grafana ek TV screen hai jo is reporter ke data ko graph banake dikhata hai taaki hume asani se samajh aaye.*

---

## Technical Deep Dive

### 1. The Pull Model and Architecture
Most legacy monitoring tools (like Datadog/NewRelic agents) use a **Push** model: the server sends data to the central hub. Prometheus uses a **Pull** model. The central Prometheus server makes an HTTP GET request to `/metrics` on your application every 15 seconds.
**Architecture:**
- **Prometheus Server**: Scrapes metrics, stores them in its Time Series Database (TSDB).
- **Exporters**: Small agents running on target servers that expose metrics on a `/metrics` HTTP endpoint (e.g., `node_exporter` for Linux OS metrics, `blackbox_exporter` for website uptime).
- **Alertmanager**: Receives alerts from Prometheus and routes them to Slack/Email/PagerDuty.

### 2. Metric Types
Prometheus categorizes data into 4 core types:
- **Counter**: A number that ONLY goes up (e.g., total HTTP requests). If the server restarts, it resets to 0. (Always use the `rate()` function with counters).
- **Gauge**: A number that can go up and down (e.g., current CPU usage, active memory).
- **Histogram**: Samples observations and counts them into configurable "buckets" (e.g., request durations: 10 requests took < 0.1s, 50 took < 0.5s). Used for percentiles.
- **Summary**: Similar to histogram but calculates percentiles (quantiles) on the client side.

### 3. PromQL Essentials
Prometheus Query Language is highly mathematical.
- `http_requests_total` returns the raw, ever-increasing number. This is useless for a graph.
- `rate(http_requests_total[5m])` calculates the per-second rate of requests over the last 5 minutes. This is what you actually graph.
- You can filter by labels: `rate(http_requests_total{status="500", app="frontend"}[5m])`.

---

## Step-by-Step Lab

> [!warning] Pre-requisites
> - Docker and Docker Compose installed

### Step 1: Create the Prometheus Configuration
```yaml
# Create prometheus.yml
global:
  scrape_interval: 15s # How often to scrape targets

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node_exporter:9100']
```

### Step 2: Create the Docker Compose Stack
```yaml
# Create docker-compose.yml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  node_exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
```

### Step 3: Spin Up and Verify
```bash
# Bring up the stack
docker compose up -d

# Expected output:
# Container node_exporter  Started
# Container prometheus  Started
# Container grafana  Started
```

### Step 4: Explore Prometheus
1. Go to `http://localhost:9090` in your browser.
2. Go to **Status -> Targets**. You should see `node_exporter` showing as UP (Green).
3. In the main PromQL search bar, type: `node_cpu_seconds_total` and click Execute. You will see raw metrics.
4. Now type: `100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`. This calculates actual CPU usage percentage!

### Step 5: Connect Grafana
1. Go to `http://localhost:3000` (Login: admin / admin).
2. Go to **Connections -> Data Sources** -> Add Prometheus.
3. Set the URL to `http://prometheus:9090` (using Docker DNS) and click Save & Test.
4. Go to Dashboards -> Import. Type `1860` (The ID for the official Node Exporter Full dashboard) and click Load. Select your Prometheus data source.
5. Boom! You now have a gorgeous, professional dashboard showing CPU, RAM, and Disk usage of your local machine.

> [!tip] Pro Tip
> Never use `irate()` for graphing long-term trends; it only looks at the last two data points and creates wildly spiky, unreadable graphs. Use `rate()` for graphing, and `irate()` only for high-resolution alerting rules where you need instantly react to a micro-burst in traffic.

---

## Common Commands Cheat Sheet

| PromQL Query | What It Does | Real Example |
|--------------|-------------|--------------|
| `up` | Returns 1 if target is reachable, 0 if down | `up{job="node_exporter"}` |
| `rate()` | Per-second average rate of increase of a counter | `rate(http_requests_total[5m])` |
| `sum()` | Aggregates metrics across multiple instances | `sum(rate(http_requests_total[5m]))` |
| `avg by (label)` | Averages metrics grouped by a specific label | `avg by (instance) (node_memory_MemFree_bytes)` |
| `increase()` | Total absolute increase of a counter over time | `increase(http_requests_total[1h])` |
| `histogram_quantile()`| Calculates percentiles (like P99 latency) | `histogram_quantile(0.99, sum(rate(http_req_duration_bucket[5m])) by (le))` |
| `time() - process_start_time_seconds` | Calculates uptime of an application | `time() - process_start_time_seconds{app="web"}` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| Target shows as DOWN in Prometheus | Firewall/Network issue | Run `curl http://<target-ip>:9100/metrics` from the Prometheus server. If it times out, open port 9100 on the target's firewall/Security Group. |
| Grafana says "Data source connection error" | Wrong URL or DNS | In Docker/K8s, you must use the internal service name (e.g., `http://prometheus:9090`), not `localhost`, because localhost inside the Grafana container means Grafana itself. |
| PromQL `rate()` returns empty or nothing | Range too small | If scrape interval is 15s, `rate(...[10s])` will fail because it needs at least 2 data points. Always use a range of at least `[1m]`. |
| `node_filesystem_free_bytes` shows wrong size in Docker | Container isolation | Node exporter running in Docker sees the container's virtual filesystem, not the host's. You must mount the host's `/` and `/sys` to the container as read-only volumes. |
| Graph drops to 0 when app restarts | Counter reset | Counters reset to 0 on restart. `rate()` automatically handles this mathematically, which is why you MUST use `rate()` on counters. Don't graph raw counter values. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A Java application keeps crashing every 3 hours due to 'Out of Memory' (OOM) errors. The developers say the app is fine and blame DevOps for not provisioning enough RAM."

**What Junior DevOps Does:**
Increases the EC2 instance size from 4GB to 8GB. The app stays up for 6 hours, then crashes again. They increase it to 16GB. It crashes after 12 hours.

**Escalation Trigger:**
The AWS bill is skyrocketing, and the app is still crashing, just taking longer to do so.

**Senior Engineer Resolution:**
1. Installs the **JMX Exporter** on the Java application to expose internal JVM metrics.
2. Updates `prometheus.yml` to scrape this new endpoint.
3. Builds a Grafana dashboard targeting the JVM Heap Memory metrics.
4. Analyzes the graph over 24 hours. The graph shows a perfect "sawtooth" pattern (memory slowly climbs, garbage collection fires, but the baseline memory keeps creeping higher and higher).
5. The Senior proves mathematically via the dashboard that the application has a **Memory Leak** in the code.
6. The developers fix the code, the memory graph flatlines beautifully, and the EC2 instance is safely downgraded back to 4GB.

**Lesson Learned:**
Without metrics, you are just guessing. Observability ends the "blame game" between Dev and Ops by providing undeniable mathematical proof of system behavior.

---

## Interview Questions

**Q1 (Conceptual):** What is the fundamental difference between the Pull model of Prometheus and the Push model of traditional monitoring tools?
**A:** In a Push model, servers actively send their metrics to a central hub, which can overwhelm the hub and requires configuring hub credentials on every single server. In a Pull model (Prometheus), the central server reaches out and scrapes metrics from the targets. This prevents the server from being overwhelmed, makes local testing easier, and centralizes the configuration logic.

**Q2 (Practical):** Your Prometheus server ran out of disk space after 30 days. How do you configure it to only keep 15 days of metrics?
**A:** I would pass a startup flag to the Prometheus binary (or modify the Docker command/Kubernetes manifest). Specifically, I would set `--storage.tsdb.retention.time=15d`.

**Q3 (Scenario-based):** A developer wrote a PromQL query: `http_requests_total{status="500"}` to graph error rates, but the graph is an ever-increasing slope that is completely unreadable. How do you fix it?
**A:** `http_requests_total` is a Counter, meaning it only goes up. Graphing it directly just shows a climbing mountain. To see the actual error *rate* (errors per second) at any given moment, I must wrap it in a rate function: `rate(http_requests_total{status="500"}[5m])`.

**Q4 (Deep dive):** Explain what the 99th Percentile (P99) latency means, and why it is vastly superior to tracking "Average" latency.
**A:** Averages hide outliers. If 9 requests take 10ms, and 1 request takes 900ms, the average is ~99ms, making the system look fine. P99 latency means "99% of requests are faster than this number." If your P99 is 900ms, you instantly know that 1 out of 100 users is having a terrible experience. P99 ensures you are monitoring the worst-case user experience.

**Q5 (Trick/Gotcha):** Can Prometheus natively monitor a Lambda function or a short-lived Cron job that only runs for 3 seconds?
**A:** No, not natively. Because Prometheus uses a Pull model (scraping every 15s), it will completely miss a job that starts and finishes in 3 seconds. To monitor short-lived jobs, you must use the **Prometheus Pushgateway**. The short-lived job pushes its metrics to the Pushgateway, and Prometheus scrapes the Pushgateway at its normal 15s interval.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[08-Monitoring-and-Observability/MON-03 Alerting and SLO-SLA-SLI|Alerting and SLOs]]
[[04-Orchestration/K8S-01 Kubernetes Architecture|Kubernetes Architecture]] (Where Prometheus is typically deployed)
