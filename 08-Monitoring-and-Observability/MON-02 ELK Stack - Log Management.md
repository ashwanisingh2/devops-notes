---
tags: [devops, logging, elk, observability]
aliases: [ELK Stack & Logging]
created: 2025-06-27
status: #complete
difficulty: #advanced
cert-relevant: #none
---

# MON-02 ELK Stack — Log Management

> [!abstract] Overview
> Metrics (Prometheus) tell you *that* a problem is occurring (CPU is at 100%). Logs tell you *why* the problem is occurring ("NullPointerException on line 42"). In a microservices architecture with 50 ephemeral containers, manually SSHing to read `/var/log` files is impossible. Centralized Log Management solves this. The ELK stack (Elasticsearch, Logstash, Kibana) ingests, parses, indexes, and visualizes millions of log lines per second, allowing you to search terabytes of data instantly like Google.

---

## Concept Overview

- **What it is** — **E**lasticsearch (the NoSQL search engine/database), **L**ogstash (the data processing pipeline that parses logs), and **K**ibana (the UI/Dashboard). Often replaced with **EFK** (using Fluentd/Fluentbit instead of Logstash for lighter resource usage).
- **Why DevOps engineers use it** — Centralization and Searchability. When an error occurs, you need to correlate logs from the Nginx proxy, the Node.js API, and the database simultaneously. ELK aggregates them all into one searchable database.
- **Where you encounter this in a real job** — Configuring Filebeat on K8s worker nodes to scrape container logs, writing Grok patterns to extract the IP address from a custom log string, or building a Kibana dashboard showing 404 errors geographically.
- **Responsibility Split:**
  - **Junior DevOps**: Uses the Kibana "Discover" tab to write KQL queries and find errors for developers.
  - **Mid DevOps**: Configures Filebeat/Logstash pipelines to ship logs, and writes Grok filters.
  - **Senior/SRE**: Manages Elasticsearch cluster scaling (shards/replicas), implements Index Lifecycle Management (ILM) to automatically delete logs older than 30 days, and tunes JVM heaps.

*Seedha simple mein: ELK ek library system hai. Beats (agents) saari kitabein (logs) alag-alag servers se collect karte hain. Logstash un kitabon ko padh ke index (title, author) lagata hai. Elasticsearch unko almari mein store karta hai. Aur Kibana wo librarian hai jisko aap bolte ho "Mujhe ERROR word wali sabhi kitabein dikhao", aur wo 1 second mein dhoond ke de deta hai.*

---

## Technical Deep Dive

### 1. The Data Ingestion Pipeline
Logs are fundamentally just unstructured strings of text.
1. **Beats (Filebeat)**: A lightweight agent installed on edge servers. It reads `/var/log/syslog` or Docker container logs line-by-line and ships them.
2. **Logstash**: The heavy processor. It receives the raw string: `192.168.1.1 - [10/Oct/2023] "GET / HTTP/1.1" 404`. It uses **Grok patterns** (advanced Regex) to break it down into JSON: `{"ip": "192.168.1.1", "method": "GET", "status": 404}`.
3. **Elasticsearch**: Receives the JSON and indexes every single word so it can be searched in milliseconds.

### 2. Elasticsearch Architecture
Elasticsearch is a distributed NoSQL database.
- **Index**: Like a database table (e.g., `nginx-logs-2023.10`).
- **Document**: A single row/log entry in JSON format.
- **Shards**: An index is cut into pieces (shards) and distributed across multiple EC2 servers (Nodes). This allows you to search 1TB of logs incredibly fast because 10 servers are searching 100GB in parallel.
- **Replicas**: Copies of shards. If a server dies, no logs are lost.

### 3. Index Lifecycle Management (ILM)
Logs generate massive amounts of data (often 100GB+ per day). You cannot keep them forever.
**ILM Policies** automate the lifecycle:
- **Hot Phase**: Today's logs. Stored on expensive, ultra-fast SSDs.
- **Warm Phase**: 7-day old logs. Moved to cheaper HDDs. Searchable, but slower.
- **Cold Phase**: 30-day old logs. Frozen and archived.
- **Delete Phase**: 90-day old logs. Automatically deleted to save disk space.

---

## Step-by-Step Lab

> [!warning] Pre-requisites
> - Docker and Docker Compose installed
> - At least 4GB of RAM free (Elasticsearch is heavy)

### Step 1: Create the Docker Compose Stack
```yaml
# Create docker-compose.yml
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.8.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false # Disabled for local lab only!
      - ES_JAVA_OPTS=-Xms512m -Xmx512m
    ports:
      - "9200:9200"

  kibana:
    image: docker.elastic.co/kibana/kibana:8.8.0
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch
```

### Step 2: Bring Up the Stack
```bash
# Start the ELK stack
docker compose up -d

# Wait about 60 seconds for Kibana to fully boot. Check logs:
docker compose logs -f kibana
```

### Step 3: Insert a Log Manually (Simulating Logstash)
```bash
# We will use curl to POST a JSON document directly to Elasticsearch
curl -X POST "http://localhost:9200/app-logs/_doc/1" \
     -H 'Content-Type: application/json' \
     -d '{
           "@timestamp": "2023-10-25T14:12:12",
           "level": "ERROR",
           "message": "Database connection failed",
           "user_id": 4021
         }'

# Expected output: {"_index":"app-logs","_id":"1","_version":1,"result":"created"...}
```

### Step 4: Search the Log in Kibana
1. Go to `http://localhost:5601` in your browser.
2. Open the left menu, go to **Stack Management** -> **Data Views** (or Index Patterns).
3. Click **Create data view**. Name it `app-logs*` and set the Timestamp field to `@timestamp`.
4. Open the left menu, go to **Discover**.
5. Select your `app-logs*` data view.
6. In the search bar (KQL), type: `level: "ERROR"`. You will see your log entry appear!

### Step 5: Test a Grok Pattern (Mental/UI Check)
1. Go to **Dev Tools** in the Kibana menu.
2. In the console, you can test Grok patterns. This is how Logstash turns raw strings into JSON.
```json
// Example of what Grok does under the hood:
// Raw text: "55.3.244.1 GET /index.html 15824"
// Grok Pattern: "%{IP:client} %{WORD:method} %{URIPATHPARAM:request} %{NUMBER:bytes}"
```

> [!tip] Pro Tip
> Never log raw JSON or multiline stack traces directly into standard `/var/log` files without configuring Filebeat properly. Multiline Java stack traces (where one error spans 20 lines) will be ingested as 20 separate, meaningless log entries in Elasticsearch. Always configure the `multiline.pattern` in Filebeat to group stack traces into a single document!

---

## Common Commands Cheat Sheet

| Command / Query | What It Does | Real Example |
|-----------------|-------------|--------------|
| `curl -X GET :9200/_cat/indices` | Lists all indices in Elasticsearch and their sizes | `curl localhost:9200/_cat/indices?v` |
| `curl -X GET :9200/_cat/health` | Shows cluster health (Green, Yellow, Red) | `curl localhost:9200/_cat/health?v` |
| `KQL: field: "value"` | Kibana Query Language - Exact match | `status: 500` |
| `KQL: field: value*` | KQL - Wildcard match | `message: *Timeout*` |
| `KQL: field > 100` | KQL - Range query | `response_time_ms > 2000` |
| `KQL: A AND B` | KQL - Boolean logic | `status: 500 AND env: "prod"` |
| `GET /index/_search` | REST API to search directly | `GET /app-logs/_search?q=ERROR` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| Elasticsearch crashes instantly (OOMKilled) | Max virtual memory areas is too low | On Linux, Elasticsearch requires a high `vm.max_map_count`. Run `sudo sysctl -w vm.max_map_count=262144` on the host machine. |
| Cluster status is YELLOW | Unassigned replicas | In a single-node setup, ES creates a primary shard and tries to create a replica. Since there's no second node, the replica sits "unassigned". Set `index.number_of_replicas: 0`. |
| Cluster status is RED | Missing primary shards | A node died and took primary data with it. Look at `_cat/shards` to see which indices are broken. You may need to restore from a snapshot. |
| Logs are delayed by several minutes | Logstash bottleneck | Logstash is CPU heavy. Check Logstash queue sizes. Consider swapping Logstash for Fluent-Bit (EFK stack), which is much faster and lighter. |
| Disk Watermark \[95%\] exceeded | Elasticsearch ran out of disk space | When ES hits 95% disk, it puts all indices into "Read-Only" mode. You must delete old indices to free space, then manually remove the read-only block via API. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "Black Friday sale. The website goes down. Customers are seeing blank screens. The CPU and Memory dashboards look perfectly normal. No one knows what is breaking."

**What Junior DevOps Does:**
Logs into the AWS console, restarts all the EC2 instances blindly hoping it fixes the problem. It doesn't.

**Escalation Trigger:**
The company is losing $10,000 every minute the checkout page is down. Restarting servers didn't fix the underlying code issue.

**Senior Engineer Resolution:**
1. Opens Kibana and goes to the Discover tab.
2. Filters by the last 15 minutes: `@timestamp > now-15m`.
3. Adds a filter for HTTP 500 errors: `status: 500`.
4. Notices a massive spike of errors coming from the `payment-gateway-service`.
5. Clicks into the exact log document and reads the raw message: `Connection timed out to third-party API: stripe.com`.
6. Realizes the internal systems are perfectly fine; the external payment provider (Stripe) is rate-limiting them or down.
7. Instructs the devs to flip a Feature Flag to switch to the backup payment provider (PayPal).
8. The site is back online in 4 minutes.

**Lesson Learned:**
Metrics tell you the system is broken; Logs tell you *exactly* where and why. Centralized logging is the ultimate diagnostic tool for complex architectures.

---

## Interview Questions

**Q1 (Conceptual):** What is the difference between Elasticsearch, Logstash, and Kibana?
**A:** Logstash is the data processing pipeline that ingests, parses, and transforms unstructured log data. Elasticsearch is the distributed database and search engine that indexes and stores that structured data. Kibana is the frontend web interface that queries Elasticsearch to visualize the data through dashboards.

**Q2 (Practical):** Your Elasticsearch cluster state just turned from Green to Yellow. What does this mean, and should you panic?
**A:** Yellow status means that all Primary shards are safely allocated (no data is lost, everything is functioning), but one or more Replica shards are unassigned. This usually happens if a node drops out of the cluster. I wouldn't panic, but I would investigate why the node dropped, because if another node dies, data *will* be lost (turning the cluster Red).

**Q3 (Scenario-based):** Developers are logging JSON objects directly from their Node.js app, but when they search in Kibana, the JSON is just treated as one massive string, making it impossible to filter by nested fields (like `user.id`). How do you fix this?
**A:** The logs are being ingested as raw text. If using Filebeat to ship the logs, I would enable the `json.keys_under_root: true` setting in the `filebeat.yml` configuration. This tells Filebeat to natively parse the JSON string and send it to Elasticsearch as properly structured fields, allowing Kibana to index and query them individually.

**Q4 (Deep dive):** Explain what a Grok pattern is and why it is CPU-intensive.
**A:** Grok is a Logstash plugin that uses advanced Regular Expressions (Regex) to extract structured fields (like IPs, timestamps, URLs) from unstructured text logs. It is CPU-intensive because evaluating hundreds of complex Regex patterns against millions of log lines per second requires massive computational power, which is why poorly written Grok patterns can easily bottleneck an entire ELK pipeline.

**Q5 (Trick/Gotcha):** Can you use Elasticsearch as a primary relational database (like MySQL) for your application?
**A:** Absolutely not. While Elasticsearch is a database, it is not ACID compliant (no transactional integrity), lacks proper relational joins, and prioritizes search speed over strict data consistency. It should only be used as a secondary datastore specifically for search, logging, or analytical workloads.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[08-Monitoring-and-Observability/MON-01 Prometheus and Grafana|Metrics vs Logs]]
[[08-Monitoring-and-Observability/MON-04 Distributed Tracing|Distributed Tracing (The 3rd Pillar)]]
