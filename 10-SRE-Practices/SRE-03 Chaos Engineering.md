---
tags: [devops, sre, chaos-engineering, reliability]
aliases: [Chaos Engineering]
created: 2025-06-27
status: #complete
difficulty: #advanced
cert-relevant: #none
---

# SRE-03 Chaos Engineering

> [!abstract] Overview
> Traditional testing verifies that your application works under *normal* conditions. Chaos Engineering verifies that your distributed system survives under *turbulent* conditions. Popularized by Netflix's "Chaos Monkey," it is the practice of intentionally injecting failures (killing servers, spiking latency, dropping network packets) into a system to prove its resilience. You break things on purpose during business hours, so they don't break by accident at 3 AM.

---

## Concept Overview

- **What it is** — The discipline of experimenting on a system in order to build confidence in its capability to withstand turbulent conditions in production.
- **Why DevOps engineers use it** — To validate assumptions. You *assume* that if an AWS Availability Zone goes down, your Kubernetes cluster will automatically failover to another AZ. Chaos Engineering forces you to actually shut down the AZ and prove it works.
- **Where you encounter this in a real job** — Running a "GameDay" with the team, deploying LitmusChaos to a staging cluster to randomly delete pods, or testing how an application behaves if the Redis cache adds 500ms of latency to every request.
- **Responsibility Split:**
  - **Junior SRE**: Participates in GameDays, observes dashboards, and helps document the outcomes of the chaos experiments.
  - **Mid SRE**: Writes Chaos Experiment manifests (e.g., in Chaos Mesh), configures the blast radius, and executes the tests in staging environments.
  - **Senior/SRE**: Architects systems for resilience, runs automated chaos experiments continuously in Production (advanced maturity), and leads GameDay planning.

*Seedha simple mein: Chaos Engineering ek mock fire-drill hai. Building mein aag lagne ka wait mat karo. Khud ek choti si aag lagao, aur check karo ki fire alarms baj rahe hain ya nahi, aur sprinkler system theek se chalta hai ya nahi. Isse jab asli aag lagegi, toh sab kuch perfectly kaam karega.*

---

## Technical Deep Dive

### 1. The Chaos Engineering Process
Chaos Engineering follows the Scientific Method:
1. **Steady State**: Define what "normal" looks like (e.g., API latency < 200ms, Error rate < 1%).
2. **Hypothesis**: Make a prediction (e.g., "If I kill the primary database, the replica will take over, and the API will return to Steady State within 10 seconds").
3. **Inject Chaos**: Actually kill the database.
4. **Observe**: Monitor the dashboards. Did it failover in 10 seconds?
5. **Result**: If yes, confidence increased. If no, you found a bug. Fix it, and run the experiment again.

### 2. Blast Radius
You do not start by dropping a nuclear bomb on Production. You control the **Blast Radius**.
- Start in Staging. Try killing one pod.
- Then try it in Production, but only for 1% of users (using traffic routing).
- Then kill a whole node. Then kill a whole Availability Zone.
Always have an **Abort Button** (a way to instantly stop the experiment if the system collapses unexpectedly).

### 3. Chaos Tools (K8s Native)
- **Chaos Mesh**: A CNCF project. Uses Custom Resource Definitions (CRDs) like `PodChaos` (kills/restarts pods) or `NetworkChaos` (adds latency/packet loss).
- **LitmusChaos**: Another CNCF project heavily focused on Kubernetes, providing a "Chaos Hub" of pre-built experiments.
- **Gremlin**: A popular commercial SaaS platform for Chaos Engineering.

---

## Step-by-Step Lab (Mental/Config Walkthrough)

> [!warning] Pre-requisites
> - A Kubernetes cluster (minikube)
> - Chaos Mesh installed via Helm

### Step 1: Establish the Steady State
Imagine an Nginx deployment with 3 replicas.
- **Steady State**: You run a load tester (`hey` or `Apache Bench`) against the service. You observe a constant 200 OK response with 50ms latency.

### Step 2: Formulate the Hypothesis
- **Hypothesis**: "If one Nginx pod is suddenly killed, Kubernetes will instantly route traffic to the remaining 2 pods, the ReplicaSet will spawn a replacement, and the user experience (Steady State) will not drop below 99% success rate."

### Step 3: Write the Chaos Experiment
We will use Chaos Mesh to randomly kill one pod every minute.
```yaml
# pod-kill-experiment.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: nginx-pod-kill
  namespace: default
spec:
  action: pod-kill
  mode: one # Kill exactly one pod
  selector:
    namespaces:
      - default
    labelSelectors:
      app: nginx # Target only the Nginx pods
  duration: '5m' # Run this experiment for 5 minutes
  scheduler:
    cron: '@every 1m' # Trigger the kill every 60 seconds
```

### Step 4: Inject the Chaos and Observe
```bash
# Apply the chaos experiment
kubectl apply -f pod-kill-experiment.yaml

# Open a new terminal and watch the pods
kubectl get pods -w
# You will see a pod terminate, and a new one instantly spin up (Pending -> Running)

# Check your load tester output
# Did any requests return HTTP 502 (Bad Gateway)?
```

### Step 5: Analyze the Results
If the load tester showed `0%` errors, the hypothesis is proven! 
If it showed `5%` errors, the hypothesis is disproven. Why? 
Perhaps the Kubernetes Service didn't remove the dead pod's IP from the endpoints list fast enough. 
**Action Item**: Configure a stricter `readinessProbe` on the deployment and rerun the experiment.

> [!tip] Pro Tip
> Never run a chaos experiment if you already know the system will break. If you know that killing the DB will bring down the site because you don't have a replica configured, fixing the replica is standard engineering. Chaos Engineering is for discovering the *unknown unknowns*—things you thought were resilient but actually aren't.

---

## Common Commands Cheat Sheet
*(Usually managed via UI/CRDs, but concepts remain)*

| Concept / Tool | What It Does | Real Example |
|----------------|-------------|--------------|
| `PodChaos` | CRD to terminate or fail Kubernetes pods | `action: pod-kill` |
| `NetworkChaos` | CRD to simulate bad networks (latency/loss) | `action: delay`, `latency: 500ms` |
| `StressChaos` | CRD to burn CPU or Memory on a node | `action: memory-stress` |
| `GameDay` | A dedicated team event to run chaos tests | 4 hours on a Thursday afternoon |
| `Blast Radius` | The scope of the experiment's impact | "Only target the 'payment-test' namespace" |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| Experiment causes a massive production outage | Uncontrolled Blast Radius | You targeted all pods instead of just one, or you ran it during peak traffic. Always start small. Ensure your Chaos tool has an automated "Halt/Abort" mechanism if error rates spike. |
| The team refuses to do Chaos Engineering | Fear of breaking things | Explain that Chaos Engineering doesn't *cause* outages; it *reveals* weaknesses that are already there. Better to find them at 2 PM on a Tuesday than 2 AM on a Sunday. Start in a safe Dev environment to build trust. |
| The experiment passes, but the system still fails later | Wrong Steady State | You measured CPU instead of customer latency. The experiment looked fine on the backend, but frontend users were timing out. Always measure Chaos against business-centric SLIs. |
| `NetworkChaos` has no effect | Missing kernel capabilities | Tools like Chaos Mesh manipulate `tc` (traffic control) and IPtables in the Linux kernel to simulate network latency. Ensure the Chaos Mesh daemonset has the necessary `NET_ADMIN` privileges on the worker nodes. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "The company relies heavily on a third-party API (e.g., a Shipping Rate calculator). The code is wrapped in a 5-second timeout. The developers claim that if the third-party API goes down, the checkout page will just skip the shipping calculation and proceed gracefully."

**What Junior SRE Does:**
Reads the code, sees `timeout=5`, trusts the developer, and deploys it.

**Escalation Trigger:**
A month later, the Shipping API experiences a "brownout" (it doesn't go down, but it takes 15 seconds to reply to every request). The company's checkout page hangs, connections pile up, and the entire e-commerce site crashes.

**Senior Engineer Resolution (GameDay):**
1. The Senior SRE doesn't trust assumptions. They organize a GameDay in Staging.
2. They use a Chaos tool to inject a `NetworkChaos` rule that adds 15 seconds of latency specifically to outbound traffic heading to the Shipping API's IP address.
3. They watch the dashboards. The checkout page hangs, threads max out, and Staging crashes. The hypothesis is disproven.
4. The developers investigate and realize the 5-second timeout was only applied to the *connection* phase, not the *read* phase.
5. The developers fix the code, implement a Circuit Breaker pattern, and the SRE reruns the Chaos experiment. This time, it fails gracefully after 5 seconds. Production is saved.

**Lesson Learned:**
Code reviews and unit tests cannot validate distributed network behavior. Only Chaos Engineering can prove how your system reacts to network turbulence.

---

## Interview Questions

**Q1 (Conceptual):** What is the difference between Chaos Engineering and traditional Load Testing?
**A:** Load Testing checks if a system can handle a specific volume of traffic (e.g., 10,000 requests per second) under normal, healthy conditions. Chaos Engineering checks if the system can survive unexpected failures (e.g., a server dying, network packet loss, database failover) while traffic is flowing.

**Q2 (Practical):** You want to test how your Kubernetes microservices handle network latency. How would you simulate this?
**A:** I would use a tool like Chaos Mesh or LitmusChaos. I would write a `NetworkChaos` Custom Resource Definition (CRD) that targets a specific deployment using label selectors, and instructs the Linux kernel (via traffic control/eBPF) to inject 500ms of delay on all outbound packets from those specific pods.

**Q3 (Scenario-based):** You propose running a Chaos experiment in Production, and the CTO says, "Absolutely not, we cannot risk taking the site down for our customers." How do you convince them?
**A:** I would explain the concept of the **Blast Radius**. I would promise that we will not start in Production. We will prove the experiment is safe in Staging first. Then, in Production, we will run it during off-peak hours, targeting only 1% of the traffic using Canary routing, and we will have an automated "Abort" threshold that instantly kills the experiment if our SLI drops by even 0.1%.

**Q4 (Deep dive):** Explain why defining the "Steady State" is the mandatory first step in any Chaos experiment.
**A:** If you do not define a measurable Steady State (e.g., P99 Latency < 200ms, 0% Error Rate), you have no baseline to compare against. When you inject chaos, things will get weird. Without a defined Steady State, you won't know if the system's reaction was a successful mitigation or a catastrophic failure. The Steady State is your scientific control variable.

**Q5 (Trick/Gotcha):** Should you use Chaos Engineering to find bugs in a system that crashes multiple times a week on its own?
**A:** No. Chaos Engineering is for mature, relatively stable systems to find hidden weaknesses. If a system is already unstable and crashing naturally, you don't need to inject chaos to find problems; you just need to look at your standard monitoring logs and fix the obvious architectural flaws first.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[10-SRE-Practices/SRE-01 SRE Fundamentals|SRE Fundamentals]]
[[10-SRE-Practices/SRE-02 Incident Management|Incident Management]]
