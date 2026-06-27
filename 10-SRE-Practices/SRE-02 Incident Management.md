---
tags: [devops, sre, incident-management, pagerduty]
aliases: [Incident Response]
created: 2025-06-27
status: #complete
difficulty: #advanced
cert-relevant: #none
---

# SRE-02 Incident Management

> [!abstract] Overview
> Systems will break. Databases will corrupt, network cables will be cut, and bad code will bypass tests. How an engineering team responds when production catches fire determines whether an outage lasts 15 minutes or 15 hours. Incident Management brings military-style structure and clear communication to chaotic outages, ensuring that issues are triaged, mitigated, and resolved quickly, followed by a postmortem to guarantee the exact same failure never happens twice.

---

## Concept Overview

- **What it is** — A structured, standardized process for responding to unplanned IT interruptions (incidents). It defines distinct roles, communication channels, and phases (Detection, Triage, Mitigation, Resolution, Postmortem).
- **Why DevOps engineers use it** — To reduce MTTR (Mean Time To Recovery). During an outage, 10 engineers jumping into a Zoom call and shouting over each other creates confusion, duplicated effort, and prolonged downtime. Incident management imposes order.
- **Where you encounter this in a real job** — Being paged at 2 AM, declaring a SEV-1 incident, acting as the Incident Commander in a Slack War Room, or writing the public Status Page update for customers.
- **Responsibility Split:**
  - **Junior SRE/DevOps**: Acts as a Subject Matter Expert (SME) during an incident, investigating logs or metrics when directed by the Commander.
  - **Mid SRE/DevOps**: Serves as the Incident Commander for lower severity (SEV-2/3) issues, coordinates the Zoom bridge, and drafts the Postmortem document.
  - **Senior/SRE**: Acts as the Incident Commander for catastrophic SEV-1 outages, manages executive communication, and drives systemic architectural changes derived from postmortem Action Items.

*Seedha simple mein: Incident Management ek Fire Brigade ka system hai. Jab aag lagti hai (outage), toh sab log paani nahi daalte. Ek leader (Commander) hota hai jo bahar khada hoke directions deta hai, ek insaan public ko handle karta hai (Comms), aur baaki log aag bujhate hain (Engineers). Bina leader ke sirf panic hoga.*

---

## Technical Deep Dive

### 1. Incident Severity Levels (SEVs)
Every company defines these slightly differently, but the standard structure is:
- **SEV-1 (Critical)**: Core business functions are entirely down. Massive revenue loss. (e.g., Checkout page is broken for all users). All hands on deck immediately.
- **SEV-2 (High)**: Major functionality is broken, but workarounds exist or only a subset of users is affected. (e.g., PayPal integration is down, but Credit Cards work).
- **SEV-3 (Medium)**: Minor feature broken, no significant revenue impact. (e.g., User avatars aren't loading).
- **SEV-4 (Low)**: Internal tools issue or cosmetic bug. Handled during normal business hours.

### 2. The Roles of Incident Response
Borrowed from the ICS (Incident Command System) used by firefighters:
- **Incident Commander (IC)**: The boss of the incident. They do NOT fix the code or look at logs. They delegate tasks, keep the team focused, and make hard decisions (like "Roll back the database now").
- **Communications Lead**: Handles all non-technical communication. Updates the public Status Page, updates the C-Suite executives, and insulates the engineers from managers asking "Is it fixed yet?".
- **Operations / Subject Matter Experts (SMEs)**: The engineers actually executing commands, querying logs, and fixing the problem.

### 3. Mitigation vs. Resolution
- **Mitigation**: Stopping the bleeding. If a bad code push breaks the site, Mitigation is rolling back to the previous version. The site is up, the bleeding has stopped.
- **Resolution**: Curing the disease. Finding out *why* the bad code broke the site, fixing the bug in the new code, writing a test, and deploying it successfully.
During an incident, the IC's primary goal is ALWAYS Mitigation, not Resolution.

---

## Step-by-Step Lab (Running a Mock SEV-1)

> [!warning] Pre-requisites
> - A communication platform (Slack/Teams)

### Step 1: Detection and Declaration
- **02:00 AM**: PagerDuty alerts the On-Call Engineer: `Critical: Checkout API 500 Error Rate > 20%`.
- The engineer verifies it's a real issue, goes to the `#sre-alerts` Slack channel, and declares the incident.
- **Action**: `/incident declare SEV-1 Checkout API Failing`

### Step 2: Assemble the War Room
- The Incident Commander (IC) takes charge in the dedicated `#inc-checkout-outage` channel.
- **IC**: *"I am the IC. Alice, you are Comms Lead. Bob and Charlie, you are SMEs. Bob, check the APM logs. Charlie, check the recent GitHub deployments."*

### Step 3: Triage and Investigation
- **Charlie**: *"I see a deployment to the Checkout service at 01:50 AM."*
- **Bob**: *"Logs show the new code is failing to authenticate with the Stripe API due to a missing environment variable."*
- **IC**: *"Understood. The new deployment is the likely cause."*

### Step 4: Mitigation
- **IC**: *"Charlie, roll back the Checkout deployment to the previous stable tag immediately."*
- **Charlie**: *"Executing rollback via ArgoCD... Rollback complete. Pods are cycling."*
- **Bob**: *"Error rates are dropping back to 0%. Checkout is succeeding."*
- **IC**: *"Excellent. We are mitigated at 02:15 AM."*

### Step 5: Communications and Stand-down
- **Alice (Comms)**: *"Updating public Status Page: Issue identified and mitigated. Monitoring system stability."*
- **IC**: *"Great job team. We are stable. I am ending the active incident. Bob, create a Jira ticket for the root cause resolution tomorrow. Charlie, schedule the blameless postmortem for Thursday."*

> [!tip] Pro Tip
> If you are the Incident Commander, the fastest way to fail is to open a terminal and start typing commands. The moment the IC starts debugging, the incident loses its leader. If you must debug because you are the only one who knows how, explicitly hand off the IC role to someone else first: *"Alice, I am handing off IC duties to you so I can investigate the database."*

---

## Common Commands Cheat Sheet
*(Incident management relies on ChatOps and processes)*

| Action / Chat Command | What It Does | Real Example |
|-----------------------|-------------|--------------|
| `/incident declare` | Triggers incident bot (Rootly/FireHydrant) | `/incident declare SEV1 Database Down` |
| `Status Page Update` | Publicly acknowledges the issue | "Investigating elevated error rates." |
| `Zoom/Meet Bridge` | Dedicated voice channel for the incident | Pinned in the Slack war room. |
| `Rollback` | The most common mitigation strategy | `kubectl rollout undo deployment/api` |
| `Postmortem Template` | Standardized Google Doc for review | Contains Timeline, Impact, Root Cause. |
| `Action Items (AIs)` | Jira tickets generated from the postmortem | "AI: Add pre-commit hook for env vars." |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| Executives keep interrupting the engineers in Slack | Missing Comms Lead | The IC must immediately designate a Communications Lead. The Comms Lead creates a separate Slack channel or thread specifically for stakeholder updates, telling execs to stay out of the engineering channel. |
| Engineers spend 2 hours trying to fix a bug during downtime | Focusing on Resolution, not Mitigation | The IC must intervene: "Stop debugging the new code. Roll back to the previous version immediately." Stop the bleeding first, cure the disease tomorrow. |
| Nobody knows who is doing what | Unclear Commander | The IC must explicitly direct people by name, and require acknowledgment. "Bob, check the DB logs. (Wait for Bob to say 'On it')." |
| The same incident happens again a month later | Failed Postmortem Process | The postmortem didn't generate Action Items, or the Action Items were put in the backlog and ignored. Action Items from a SEV-1 must take priority over all new feature work in the next sprint. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A Junior DevOps engineer accidentally drops a production table while trying to clean up a staging database. The website goes down immediately."

**What Junior DevOps Does:**
Panics. Sweats profusely. Tries to secretly restore a backup themselves using Google searches. Fails. An hour later, customers are complaining, and the Junior finally admits it.

**Escalation Trigger:**
Fear of blame caused a 1-hour delay in declaring the incident.

**Senior Engineer Resolution (Postmortem Phase):**
1. The incident is resolved (using automated RDS backups).
2. During the Postmortem, the Senior Engineer explicitly enforces a **Blameless Culture**.
3. They state: "We are not here to discuss the Junior's mistake. We are here to discuss why the system allowed a Junior engineer to have destructive access to Production using the same credentials they use for Staging."
4. **Action Item 1**: Implement strict IAM separation between Staging and Prod.
5. **Action Item 2**: Implement Terraform so DB changes are done via PR, not manual CLI access.
6. The Junior engineer feels supported, learns from the experience, and the entire system becomes fundamentally more secure.

**Lesson Learned:**
Human error is inevitable. If your system relies on humans never making a mistake, your system is poorly designed. Fix the system, don't fire the human.

---

## Interview Questions

**Q1 (Conceptual):** What is the difference between Mitigation and Resolution in incident response?
**A:** Mitigation is the act of restoring service to the customer as quickly as possible, even if it's a hacky workaround or a rollback (stopping the bleeding). Resolution is the long-term fix applied later to ensure the root cause is permanently eliminated (curing the disease).

**Q2 (Practical):** You are the Incident Commander on a SEV-1 call. Two very senior engineers are arguing aggressively over Zoom about whether the issue is a network routing problem or a database lock, wasting 15 minutes. What do you do?
**A:** As the IC, I must break the deadlock. I would intervene firmly and assign parallel tracks: "Stop arguing. Alice, I want you to spend the next 5 minutes proving it's a network issue. Bob, you spend 5 minutes proving it's the database. Report back here in 5 minutes with evidence." 

**Q3 (Scenario-based):** A massive outage occurs, and the CEO joins the engineering Slack channel, asking every 2 minutes for an ETA on the fix, causing the engineers to panic. How do you handle this?
**A:** I immediately step in as the Communications Lead (or assign one). I direct-message the CEO or reply in the channel: "Hello [CEO], we are currently in an active SEV-1 triage. I will be your point of contact. Please join the #executive-updates channel where I will provide you with a status report every 15 minutes. We need to keep this channel clear for engineering commands."

**Q4 (Deep dive):** Describe the core sections of a standard Blameless Postmortem document.
**A:** A standard postmortem includes: 1. **Summary/Impact** (What happened and who was affected), 2. **Timeline** (Chronological order of events from detection to mitigation), 3. **Root Cause** (The deepest systemic failure, found using the "5 Whys" method), 4. **What Went Well / What Went Wrong** (Reviewing the incident response itself), and 5. **Action Items** (Concrete, assigned Jira tickets to prevent recurrence).

**Q5 (Trick/Gotcha):** Should you write a postmortem for every single alert that goes off in PagerDuty?
**A:** No, that would create massive administrative toil. Postmortems require significant time investment. You generally only write them for user-impacting outages (SEV-1 and SEV-2), or for "near-misses" where a catastrophic failure was narrowly avoided by luck.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[10-SRE-Practices/SRE-01 SRE Fundamentals|SRE Fundamentals]]
[[10-SRE-Practices/SRE-03 Chaos Engineering|Chaos Engineering (Preventing Incidents)]]
