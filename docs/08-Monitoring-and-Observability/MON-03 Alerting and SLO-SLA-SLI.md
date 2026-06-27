---
tags: [devops, monitoring, alerting, sre]
aliases: [Alerting & SLOs]
created: 2025-06-27
status: #complete
difficulty: #advanced
cert-relevant: #none
---

# MON-03 Alerting and SLO-SLA-SLI

> [!abstract] Overview
> Having beautiful Grafana dashboards and Elasticsearch logs is useless if nobody is looking at them when a 3 AM outage occurs. Alerting bridges the gap between passive observation and active incident response. However, poorly configured alerts lead to "Alert Fatigue," where engineers ignore critical pages because they receive hundreds of useless emails a day. Mastering Service Level Objectives (SLOs) and intelligent alerting rules is the core of modern Site Reliability Engineering (SRE).

---

## Concept Overview

- **What it is** — **Alerting** is the automated process of sending notifications (PagerDuty, Slack, SMS) when a metric crosses a threshold. **SLI/SLO/SLA** are the frameworks used to decide *what* thresholds actually matter to the business.
- **Why DevOps engineers use it** — To guarantee system reliability without burning out humans. Instead of alerting every time CPU spikes to 90% (which might be normal during a backup), you alert when the *Customer Error Rate* breaches the agreed-upon SLO.
- **Where you encounter this in a real job** — Writing a Prometheus `AlertRule` to trigger PagerDuty if the API latency exceeds 2 seconds for more than 5 minutes, or negotiating an Error Budget with the Product Manager.
- **Responsibility Split:**
  - **Junior DevOps**: Acknowledges alerts in PagerDuty and follows the runbook to mitigate the issue.
  - **Mid DevOps**: Writes Prometheus alerting rules, configures Alertmanager routing (Slack for warnings, PagerDuty for criticals).
  - **Senior/SRE**: Defines SLIs and SLOs with business stakeholders, calculates Error Budgets, and ruthlessly deletes noisy alerts to prevent alert fatigue.

*Seedha simple mein: SLA wo waada (contract) hai jo business customer se karta hai ("99.9% chalega"). SLO wo internal target hai jo tech team set karti hai taaki waada na tute ("Hume 99.95% maintain karna hai"). SLI wo actual metric hai jo hum napte hain ("Aaj kitne error aaye?"). Agar SLI, SLO ke paas pahunch raha hai, tabhi phone ki ghanti (Alert) bajni chahiye, choti-moti baaton pe nahi.*

---

## Technical Deep Dive

### 1. The Three S's (SLI, SLO, SLA)
- **SLI (Service Level Indicator)**: A quantitative measure of some aspect of the level of service that is provided. Typically expressed as a ratio. Example: `(Successful HTTP Requests / Total HTTP Requests) * 100`.
- **SLO (Service Level Objective)**: A target value for the SLI. Example: "Our SLI for HTTP Success Rate will be **99.9%** over a 30-day rolling window." (This allows for 43 minutes of downtime a month).
- **SLA (Service Level Agreement)**: An explicit or implicit contract with your users that includes consequences (financial penalties) if the SLO is missed. Engineers care about SLOs; Lawyers care about SLAs.

### 2. Error Budgets
If your SLO is 99.9% availability, that leaves 0.1% for failure. This 0.1% is your **Error Budget**.
Error budgets bridge the gap between Devs (who want to push new features fast) and Ops (who want stability). If the Error Budget is full, developers can push risky code. If the Error Budget is empty (you had too many outages this month), all feature deployments are frozen, and the team must solely work on reliability and bug fixes until the budget recovers.

### 3. Alerting Rules and The Four Golden Signals
Google SRE dictates that you should alert on symptoms (what the user feels), not causes (what the server feels). You measure symptoms using the **Four Golden Signals**:
1. **Latency**: Time it takes to serve a request.
2. **Traffic**: Demand placed on the system (requests per second).
3. **Errors**: Rate of requests that fail.
4. **Saturation**: How "full" the service is (e.g., Disk 95% full).
*Bad Alert*: CPU is > 90%. (Who cares? If latency is fine, the CPU is just doing its job efficiently).
*Good Alert*: High Error Rate > 5% for 5 minutes. (Users are actively failing to checkout, wake someone up).

---

## Step-by-Step Lab (Mental/Configuration Logic)

> [!warning] Pre-requisites
> - Understanding of Prometheus and PromQL

### Step 1: Define the SLI
We want to measure API Reliability.
**SLI Equation:** `(Count of HTTP 2xx + 3xx) / (Total HTTP Requests)`
**PromQL Implementation:**
```promql
sum(rate(http_requests_total{status=~"2..|3.."}[5m])) 
/ 
sum(rate(http_requests_total[5m]))
```

### Step 2: Write the Prometheus Alerting Rule
We will create an alert that fires if the Error Rate (the inverse of our SLI) exceeds 5% for 5 consecutive minutes.
```yaml
# rules.yml (Loaded by Prometheus)
groups:
- name: SRE-SLO-Alerts
  rules:
  - alert: HighErrorRate
    # The mathematical condition
    expr: |
      sum(rate(http_requests_total{status=~"5.."}[5m])) 
      / 
      sum(rate(http_requests_total[5m])) > 0.05
    # How long the condition must be true before firing
    for: 5m
    labels:
      severity: critical
      team: backend-squad
    annotations:
      summary: "High 5xx error rate detected"
      description: "Error rate is {{ $value | humanizePercentage }} over 5m."
      runbook_url: "https://wiki.company.com/runbooks/high-error-rate"
```

### Step 3: Configure Alertmanager Routing
Prometheus evaluates the rule and generates the alert. It sends it to **Alertmanager**, which decides *who* gets notified based on the labels.
```yaml
# alertmanager.yml
route:
  group_by: ['alertname', 'team']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  # Default receiver
  receiver: 'slack-general'
  
  routes:
    # Route CRITICAL alerts to PagerDuty to wake someone up
    - match:
        severity: critical
      receiver: 'pagerduty-oncall'
    
    # Route WARNING alerts to Slack (no waking up)
    - match:
        severity: warning
      receiver: 'slack-warnings'

receivers:
- name: 'pagerduty-oncall'
  pagerduty_configs:
  - service_key: <PAGERDUTY_API_KEY>
- name: 'slack-warnings'
  slack_configs:
  - api_url: <SLACK_WEBHOOK_URL>
```

### Step 4: Validate the `for` Clause (Dumb vs Smart Alerts)
Notice the `for: 5m` in Step 2. This is crucial for preventing Alert Fatigue. 
If there is a brief network blip and 10 requests fail in 5 seconds, the threshold is breached. But if the system auto-recovers immediately, the human shouldn't be woken up at 3 AM. The `for: 5m` tells Prometheus: "Wait 5 minutes. If it fixes itself, cancel the alert. Only page the human if the system is completely stuck and requires manual intervention."

> [!tip] Pro Tip
> Every single critical alert MUST have a `runbook_url` in its annotations. When an engineer is woken up at 3 AM, their brain is barely functioning. They should be able to click the link and follow a simple, step-by-step guide to mitigate the issue, rather than trying to invent a solution while half-asleep.

---

## Common Commands Cheat Sheet
*(Concepts translated to tool-specific CLI/UI actions)*

| Action / Concept | What It Does | Tool Used |
|------------------|-------------|-----------|
| `promtool check rules` | Validates YAML syntax of Prometheus rules | Prometheus CLI |
| `amtool silence add` | Temporarily mutes an alert during maintenance | Alertmanager CLI |
| `expr: up == 0` | The most basic Liveness alert (Target is down) | PromQL |
| `for: 10m` | Duration threshold to prevent false-positives | Prometheus Rules |
| `group_by: [cluster]` | Groups 50 server alerts into 1 single email | Alertmanager |
| `Ack / Acknowledge` | Tells the team "I am working on this, stop paging" | PagerDuty / OpsGenie UI |
| `Resolve` | Closes the incident and resets the alert | PagerDuty / OpsGenie UI |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| Alert Fatigue (100+ emails a day) | Alerting on causes, not symptoms | Delete alerts for "High CPU" or "High RAM". Replace them with alerts for "High Response Time" or "High Error Rate". |
| 50 servers reboot, you get 50 separate PagerDuty phone calls | Alertmanager grouping failed | Configure `group_by: ['alertname', 'datacenter']` in Alertmanager so it bundles all 50 identical alerts into a single, combined notification. |
| Alert fires, but system is fine by the time you log in | Missing or too short `for` clause | Add `for: 5m` to the Prometheus rule to ensure the alert only fires if the issue persists and isn't just a momentary micro-burst. |
| Engineer acknowledges alert but doesn't fix it | Escalation policy failure | Configure PagerDuty Escalation Policies. If the Primary on-call doesn't resolve it in 15 mins, page the Secondary. If they fail, page the Manager. |
| Alert triggers, but nobody knows what to do | Missing Runbook | Mandate that no alert is allowed into production unless it has a documented `runbook_url` attached to it. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A Junior DevOps engineer configures an alert: `If CPU > 85%, send PagerDuty alert to the whole team.` At 2 AM, a cron job runs a database backup. The CPU hits 90% for 10 minutes. The entire team is woken up by phone calls."

**What Junior DevOps Does:**
Apologizes, changes the alert to `CPU > 95%`. The next night, a different cron job pushes it to 96%. The team is woken up again. The team starts ignoring PagerDuty calls, assuming they are false alarms.

**Escalation Trigger:**
The "Boy Who Cried Wolf" syndrome. The next week, the database actually crashes. Because the team was ignoring alerts due to fatigue, a real 2-hour outage goes completely unnoticed until customers complain on Twitter.

**Senior Engineer Resolution:**
1. Deletes the CPU alert entirely.
2. Explains Google SRE philosophy: "CPU is a resource, not a user experience. We only alert when the user is suffering."
3. Replaces it with a Golden Signal alert: "Alert if 99th percentile HTTP Latency > 2 seconds for 5 minutes."
4. Now, when the backup job runs and uses 95% CPU, the system still serves requests in 0.5 seconds, so no alert fires. The team sleeps.
5. If the database actually locks up and latency spikes to 10 seconds, the alert fires, and the team knows it's a real, critical issue worth waking up for.

**Lesson Learned:**
Alerting on infrastructure metrics (CPU/RAM) is an anti-pattern. Alert on the Service Level Indicators (SLIs) that directly impact the user experience.

---

## Interview Questions

**Q1 (Conceptual):** What is the difference between an SLI and an SLO?
**A:** An SLI (Service Level Indicator) is the actual mathematical metric we are measuring (e.g., HTTP 5xx Error Rate). An SLO (Service Level Objective) is the target goal we set for that indicator (e.g., Error rate must remain below 0.1% over a 30-day window).

**Q2 (Practical):** Your database disk is slowly filling up. It will run out of space in 3 days. Do you alert on this? If so, how?
**A:** Yes, this falls under the "Saturation" Golden Signal. However, a static alert like "Disk > 90%" is bad because 90% of a 10TB drive is still 1TB of free space. Instead, I would use Prometheus linear regression (`predict_linear(disk_free[1h], 48 * 3600) < 0`) to alert ONLY if the disk is mathematically predicted to fill up completely within the next 48 hours. This gives the team ample time to act during normal business hours without a 3 AM page.

**Q3 (Scenario-based):** Developers want to release a massive new feature on Friday. The Ops team says no because the system has been unstable. How do you resolve this dispute objectively?
**A:** I would look at the **Error Budget**. If our SLO is 99.9%, we are allowed 43 minutes of downtime this month. If we have only used 10 minutes (budget is healthy), the developers are allowed to push the feature. If we have used 50 minutes (budget is exhausted), policy dictates a strict deployment freeze, and all engineering effort must shift to stability and bug fixes. The data makes the decision, not emotions.

**Q4 (Deep dive):** Explain how Alertmanager handles deduplication and grouping to prevent Alert Storms.
**A:** If a core network switch goes down, 500 servers might become unreachable simultaneously. Prometheus will send 500 distinct alerts to Alertmanager. If configured with `group_by: ['datacenter']`, Alertmanager will recognize they all share the same datacenter label, hold them in a queue for the `group_wait` period (e.g., 30s), and then bundle all 500 alerts into a single Slack message or PagerDuty incident, saving the engineer from receiving 500 phone calls in a row.

**Q5 (Trick/Gotcha):** Should you aim for 100% availability (SLA of 100%) for your services?
**A:** Never. Reaching 100% availability is physically impossible due to external factors (ISP outages, cloud provider failures). More importantly, the cost of going from 99.9% to 99.99% is exponential (requiring active-active multi-region databases and extreme redundancy). Pushing for 100% slows down feature development to a halt. You should only aim for the level of reliability that keeps your users happy, and no higher.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[08-Monitoring-and-Observability/MON-01 Prometheus and Grafana|Prometheus (Metrics generation)]]
[[10-SRE-Practices/SRE-01 SRE Fundamentals|SRE Fundamentals]]
