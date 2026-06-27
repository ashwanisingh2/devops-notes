---
tags: [devops, sre, reliability]
aliases: [SRE Basics]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #none
---

# SRE-01 SRE Fundamentals

> [!abstract] Overview
> DevOps is a cultural philosophy about bridging the gap between Development and Operations. Site Reliability Engineering (SRE) is the specific, mathematical implementation of that philosophy, pioneered by Google. If DevOps is an abstract concept, SRE is the concrete job description. SREs treat operations as a software engineering problem, prioritizing reliability, automating away manual work ("toil"), and using data-driven error budgets to balance feature velocity with system stability.

---

## Concept Overview

- **What it is** — A discipline that incorporates aspects of software engineering and applies them to infrastructure and operations problems. The main goals are creating scalable, highly reliable software systems.
- **Why DevOps engineers use it** — To stop firefighting. Traditional SysAdmins run around with fire extinguishers fixing broken servers manually. SREs build automated fire-suppression systems, design self-healing architectures, and write software to manage operations.
- **Where you encounter this in a real job** — Defining Service Level Objectives (SLOs) with product managers, writing a Python script to automate a repetitive database backup process, or conducting a blameless postmortem after a major outage.
- **Responsibility Split:**
  - **Junior SRE**: Follows runbooks during on-call shifts, resolves alerts, and identifies manual steps that should be automated.
  - **Mid SRE**: Writes automation scripts to eliminate toil, configures monitoring/alerting, and manages incident response.
  - **Senior SRE**: Architects highly available systems, conducts capacity planning, defines company-wide SLOs, and leads complex root-cause analyses.

*Seedha simple mein: DevOps ek vichardhara (mindset) hai ki Dev aur Ops ko mil kar kaam karna chahiye. SRE us vichardhara ko zameen pe utarne ka tarika hai (implementation). Ek SRE engineer wo software developer hai jisko Operations ka kaam de diya gaya hai, aur wo server theek karne ki jagah, server theek karne wala code likhta hai.*

---

## Technical Deep Dive

### 1. SRE vs DevOps (The Google Definition)
- **DevOps**: Reduce organizational silos, accept failure as normal, implement gradual changes, leverage tooling and automation.
- **SRE**: "Class SRE implements DevOps." SRE uses Error Budgets to accept failure, CI/CD to implement gradual changes, and caps manual work (Toil) at 50% to ensure engineers have time to leverage tooling.

### 2. The Concept of Toil
Toil is not just "work I don't like." It has a strict definition in SRE:
- It is manual.
- It is repetitive.
- It is automatable.
- It is tactical, devoid of enduring value (doing it doesn't make the system permanently better).
- It scales linearly as the service grows.
**The 50% Rule**: SREs must spend at least 50% of their time on engineering/coding projects that improve the system. If toil (tickets, manual deployments, on-call alerts) exceeds 50%, the team is understaffed or failing to automate.

### 3. Availability Math and Nines
Reliability is measured in "Nines." 100% availability is impossible.
- **99% (Two Nines)**: 3.65 days of downtime per year. (Acceptable for internal tools).
- **99.9% (Three Nines)**: 8.76 hours of downtime per year. (Standard for most e-commerce/SaaS).
- **99.99% (Four Nines)**: 52.6 minutes of downtime per year. (Mission-critical systems).
- **99.999% (Five Nines)**: 5.26 minutes of downtime per year. (Telecommunications, pacemakers).
Going from 3 Nines to 4 Nines costs 10x more money and slows down development drastically. You only aim for the nines your business actually needs.

---

## Step-by-Step Lab (Calculating SLOs and Error Budgets)

> [!warning] Pre-requisites
> - Basic understanding of HTTP and system metrics

### Step 1: Define the System Boundaries
Imagine an e-commerce checkout API. 
Total Requests in a 30-day month (approx): `10,000,000`

### Step 2: Set the Service Level Objective (SLO)
The business decides that the checkout API must be highly reliable, but doesn't need to be perfect.
**Target SLO**: `99.9%` success rate over 30 days.

### Step 3: Calculate the Error Budget
Error Budget = `100% - SLO`
Error Budget = `100% - 99.9% = 0.1%`
This means `0.1%` of all requests are *allowed* to fail without violating our contract.

### Step 4: Convert to Absolute Numbers
`0.1% of 10,000,000 requests = 10,000 requests.`
Your Error Budget is exactly **10,000 failed requests** per month.

### Step 5: Implement the Policy (The Hard Part)
- Week 1: Devs push code. It bugs out. 4,000 requests fail. (6,000 remaining in budget).
- Week 2: Database crashes. 5,000 requests fail. (1,000 remaining).
- Week 3: Devs want to launch a massive, risky new feature. 
- **The SRE Action**: The SRE team blocks the release. The Error Budget is almost empty. Pushing a risky feature could blow the remaining 1,000 requests. All feature work is frozen. The Devs must spend Week 3 writing tests and improving database stability until the rolling 30-day window recovers.

> [!tip] Pro Tip
> If your system is actually achieving 99.99% reliability but your SLO is only 99.9%, you are moving too slowly! Google actively takes down their own internal systems occasionally (planned maintenance) just to burn their error budget, ensuring that downstream teams don't accidentally rely on a system being 100% available.

---

## Common Commands Cheat Sheet
*(SRE is highly conceptual, these are operational MTxx metrics used in reporting)*

| Metric / Term | What It Does / Means | Real Example / Goal |
|---------------|----------------------|---------------------|
| `MTTF` | Mean Time To Failure (Uptime between crashes) | Goal: Increase (Make it years) |
| `MTTR` | Mean Time To Recovery/Resolve (Time to fix a crash)| Goal: Decrease (Under 15 mins) |
| `MTTD` | Mean Time To Detect (Time until monitoring alerts) | Goal: Decrease (Under 1 minute) |
| `Toil` | Manual, repetitive operational work | Cap at 50% of engineer's time |
| `Runbook` | Step-by-step guide to resolve a specific alert | Attached to every PagerDuty alert |
| `Blameless` | Postmortem culture focusing on systems, not people | "Why did the system let Bob break it?" |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| SREs spend 90% of their time closing Jira tickets | High Toil / Understaffing | Track toil hours meticulously. Prove to management the 50% cap is breached. Halt feature work, dedicate the next sprint entirely to automating the top 3 most common tickets. |
| Developers ignore Error Budgets | Lack of Executive Buy-in | Error budgets only work if the CTO enforces them. If product managers can override the SRE team and push code anyway, you don't have SRE, you just have rebranded SysAdmins. |
| Alert triggers, engineer panics and makes it worse | Missing/Outdated Runbooks | Mandate that no alert can be merged into Prometheus without a link to a verified Runbook. Schedule "Game Days" to practice executing runbooks in staging. |
| Postmortem turns into a finger-pointing argument | Lack of Blameless Culture | The Incident Commander must moderate. Ban the words "Bob made a mistake." Rephrase to: "The deployment script lacked validation checks, allowing a malformed config to be applied." |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A new SRE joins a team. Every Monday morning, a senior engineer spends 3 hours manually checking disk space on 50 legacy servers, rotating log files, and restarting a leaky Java service. The senior engineer is proud of their 'hard work'."

**What Junior SRE Does:**
Learns the manual process and starts doing it for the senior engineer to be helpful, accepting this as normal operational work.

**Escalation Trigger:**
The team is drowning in operational work. They have no time to migrate the legacy servers to Kubernetes, which is their actual Q3 goal.

**Senior Engineer Resolution:**
1. The new SRE recognizes this task as pure **Toil**.
2. They spend 4 hours on a Tuesday writing an Ansible Playbook that checks disk space, configures `logrotate`, and sets up a `systemd` timer to gracefully restart the Java service when memory hits 80%.
3. The playbook is scheduled in Jenkins to run automatically on Sunday nights.
4. The 3-hour Monday morning task is permanently eliminated. The senior engineer is freed up to work on the Kubernetes migration.

**Lesson Learned:**
SREs engineer themselves out of a job. If a human is acting like a machine (doing repetitive tasks), replace the human with a script.

---

## Interview Questions

**Q1 (Conceptual):** What is a Blameless Postmortem, and why is it critical to SRE culture?
**A:** A blameless postmortem is an incident review meeting where the focus is strictly on identifying systemic failures, not punishing individuals. If an engineer accidentally deletes a production database, a blameless culture asks, "Why did the system allow a human to delete production without a safety check?" instead of firing the engineer. If people fear being fired, they will hide their mistakes, making the system vastly more dangerous.

**Q2 (Practical):** Your manager asks you to design an architecture that guarantees 100% uptime (0 minutes of downtime a year). How do you respond?
**A:** I would explain that 100% uptime is mathematically impossible due to external dependencies (AWS region failures, BGP routing errors, cosmic rays). Furthermore, trying to approach 100% (like 5 Nines) costs exponentially more money and effectively halts all feature velocity. I would work with the manager to define realistic SLOs based on what our actual users need, rather than chasing a mythical 100%.

**Q3 (Scenario-based):** You are on-call. A PagerDuty alert wakes you up at 3 AM: `WARNING: Server CPU is at 90%`. You check the API, and latency is perfectly normal (200ms). What do you do?
**A:** I go back to sleep. The next morning, I delete or modify that alert. CPU usage is a cause, not a symptom. If the user experience (latency and error rate) is unaffected, a high CPU just means we are using the hardware efficiently. We should only page humans for symptom-based alerts (SLI breaches) that impact the customer.

**Q4 (Deep dive):** Explain the concept of "Toil" and why Google SREs cap it at 50%.
**A:** Toil is manual, repetitive, tactical work that scales linearly with the service (like manually provisioning users or resetting passwords). If toil is not capped, as the service grows, it will eventually consume 100% of the team's time, leaving 0% for engineering improvements. By strictly capping it at 50%, the team is forced to spend the other 50% writing software to automate the toil away, ensuring the system can scale without linearly scaling the headcount.

**Q5 (Trick/Gotcha):** Is it possible for your SLI to show 99.9% success, but your customers are furious because the system is unusable?
**A:** Yes, absolutely. This means you are measuring the wrong SLI. For example, if you measure "HTTP 200 OK" responses, your SLI might look perfect. But if the application is returning a 200 OK with a blank white screen, the user is failing. Your SLIs must accurately reflect the *actual user journey*, not just technical metrics.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[08-Monitoring-and-Observability/MON-03 Alerting and SLO-SLA-SLI|Alerting and SLOs]]
[[10-SRE-Practices/SRE-02 Incident Management|Incident Management]]
