---
tags: [devops, kubernetes, scaling]
aliases: [K8S Autoscaling]
created: 2025-06-27
status: #complete
difficulty: #advanced
cert-relevant: #cka
---
# Kubernetes Autoscaling

> [!abstract]
> This note focuses on the automated scaling mechanisms in Kubernetes. We will cover the Horizontal Pod Autoscaler (HPA) for scaling out pods based on metrics, the Vertical Pod Autoscaler (VPA) for sizing pod resources, the Cluster Autoscaler for adding/removing worker nodes, and KEDA for advanced event-driven autoscaling based on external queues or streams.

## Concept Overview

Autoscaling in Kubernetes operates at two distinct layers: the Pod layer and the Node (Infrastructure) layer. 
- **Horizontal Pod Autoscaler (HPA):** Adds or removes pod replicas (scaling out/in) based on metrics like CPU utilization or custom metrics.
- **Vertical Pod Autoscaler (VPA):** Increases or decreases the CPU/Memory requests and limits of existing pods (scaling up/down) without changing the replica count.
- **Cluster Autoscaler (CA):** Interacts with the cloud provider (AWS ASG, GCP MIG) to add new worker nodes when pods are pending due to lack of resources, and removes nodes when they are underutilized.
- **KEDA (Kubernetes Event-driven Autoscaling):** A specialized operator that extends HPA to scale pods based on external events, like the length of an AWS SQS queue or Kafka topic, even scaling down to zero.

*Hindi translation & analogy:* *Scaling ke layers samjho. HPA ka matlab hai aur workers lana jab kaam badh jaye (1 ki jagah 5 workers). VPA ka matlab hai usi worker ko zyada taqat (protein shake) dena taaki wo akela bada kaam kar sake. KEDA ek smart supervisor hai jo dekhta hai bahar truck (queue) me kitna maal hai, aur us hisaab se workers bulata hai. Aur Cluster Autoscaler? Jab factory me workers ke khade hone ki jagah khatam ho jaye, CA nayi building (Node) rent pe le aata hai.*

## Technical Deep Dive

### 1. Resource Requests vs. Limits and Metrics Server
For autoscaling to work, K8s must understand resource consumption. The `Metrics Server` must be installed to aggregate CPU/Memory usage. Crucially, pods must have resource `requests` defined. HPA calculates the target utilization as a percentage of the requested resources (e.g., Target 50% CPU of a 200m request). If you don't define requests, HPA cannot calculate the percentage and scaling will fail. `limits` act as a hard cap to prevent a single pod from starving the node.

### 2. The Relationship Between HPA and Cluster Autoscaler
HPA and CA work perfectly together. During a traffic spike, HPA detects high CPU usage and updates the Deployment replica count from 3 to 10. The K8s scheduler tries to place the 7 new pods. If the existing nodes lack the CPU/Memory capacity, the pods remain in a `Pending` state. The Cluster Autoscaler watches for `Pending` pods. When it sees them, it triggers the cloud provider to provision a new VM. Once the VM joins the cluster, the pending pods are scheduled.

### 3. KEDA: Event-Driven Scaling
HPA natively scales based on CPU/Memory, which is reactive. If a massive batch job drops 10,000 messages into a RabbitMQ queue, CPU usage won't spike until pods pull the messages, delaying scaling. KEDA introduces CRDs like `ScaledObject`. It connects directly to RabbitMQ, sees the queue length, and preemptively scales the K8s deployment to process the backlog instantly. Furthermore, HPA can only scale down to 1 pod; KEDA can scale deployments down to 0, saving significant resources.

## Step-by-Step Lab

**Scenario:** Deploy a web app, configure HPA to scale based on CPU, trigger a load test to observe scale-out, and optionally install KEDA.

1. **Ensure Metrics Server is Installed**
   ```bash
   minikube addons enable metrics-server
   kubectl top nodes
   ```
2. **Deploy an Application with Resource Requests**
   Create `php-apache.yaml`:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: php-apache
   spec:
     selector:
       matchLabels:
         run: php-apache
     replicas: 1
     template:
       metadata:
         labels:
           run: php-apache
       spec:
         containers:
         - name: php-apache
           image: registry.k8s.io/hpa-example
           ports:
           - containerPort: 80
           resources:
             limits:
               cpu: 500m
             requests:
               cpu: 200m
   ---
   apiVersion: v1
   kind: Service
   metadata:
     name: php-apache
     labels:
       run: php-apache
   spec:
     ports:
     - port: 80
     selector:
       run: php-apache
   ```
   ```bash
   kubectl apply -f php-apache.yaml
   ```
3. **Create the Horizontal Pod Autoscaler**
   ```bash
   kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10
   kubectl get hpa
   # Wait a minute. TARGETS will initially show <unknown>/50%, then 0%/50%.
   ```
4. **Trigger Load to Cause Scale-Out**
   Run a busybox pod in a new terminal to generate infinite requests:
   ```bash
   kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
   ```
5. **Observe Scaling Activity**
   In another terminal, watch the HPA and Deployments:
   ```bash
   kubectl get hpa -w
   # You will see CPU spike past 50%, and replicas increase up to 10.
   kubectl get deployment php-apache
   ```
6. *(Optional)* **Stop Load and Observe Scale-In**
   Cancel the load generator (Ctrl+C). After a cooldown period (default 5 mins), the replicas will scale back down to 1.

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
| :--- | :--- | :--- |
| `kubectl top pods` | Shows current CPU/Memory usage per pod | `kubectl top pods -n default` |
| `kubectl autoscale` | Quickly creates an HPA for a resource | `kubectl autoscale deployment my-app --min=2 --max=5 --cpu-percent=80` |
| `kubectl get hpa` | Lists autoscalers and current metrics | `kubectl get hpa -w` |
| `kubectl describe hpa` | Shows scaling events and calculation logic | `kubectl describe hpa php-apache` |
| `kubectl get events` | Helps diagnose pending pods / autoscaling | `kubectl get events --field-selector involvedObject.kind=Pod` |
| `helm repo add kedacore` | Adds KEDA helm repository | `helm repo add kedacore https://kedacore.github.io/charts` |
| `kubectl get scaledobjects` | Lists KEDA scaling rules | `kubectl get scaledobjects -n my-app` |

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
| :--- | :--- | :--- |
| **HPA shows `<unknown>/50%` for targets** | Metrics Server is not running or pods lack resource `requests`. | 1. `kubectl get pods -n kube-system` (check metrics-server). 2. Edit deployment: Ensure `resources.requests.cpu` is explicitly set on containers. |
| **Pods are stuck in `Pending` state** | Node lacks capacity and Cluster Autoscaler is not configured or maxed out. | 1. `kubectl describe pod <name>` (look for FailedScheduling). 2. Check cloud provider ASG limits. 3. Ensure Cluster Autoscaler logs show no errors. |
| **Deployment keeps scaling up and down rapidly (Thrashing)** | Target CPU threshold is too low, or metric fluctuates wildly. | 1. Increase the `--cpu-percent` target. 2. Configure stabilization window `behavior` in the HPA YAML to delay scale-in. |
| **VPA drops pods during production peak hours** | VPA in `Auto` mode restarts pods to apply new resource limits. | 1. Change VPA `updateMode` from `Auto` to `Off` or `Initial`. `Initial` only applies recommendations on pod startup. |
| **KEDA not scaling based on AWS SQS queue** | Incorrect IRSA/IAM permissions or wrong queue URL in `ScaledObject`. | 1. Check KEDA operator logs. 2. Verify the IAM role assigned to KEDA has `sqs:GetQueueAttributes`. |

## Real-World Job Scenario

**Scenario:** An e-commerce backend processes orders from a Kafka topic. During a flash sale, orders pour in. CPU-based HPA scales up too slowly, causing delays in order processing and customer complaints.

**Junior DevOps Action:** Lowers the HPA CPU threshold to 30% hoping it scales faster, or manually sets the replica count to 50 before the sale and forgets to scale it down, wasting thousands of dollars in cloud costs.
**Senior DevOps Action:** Installs KEDA. Removes the CPU-based HPA and creates a KEDA `ScaledObject` pointing to the Kafka topic. Configures it to scale out 1 pod for every 100 lagging messages. KEDA detects the queue spike instantly and preemptively scales the pods to handle the burst, then scales them down to exactly zero when the queue is empty during off-hours, optimizing costs.

## Interview Questions

**Q1: Why is defining resource requests crucial for Horizontal Pod Autoscaling?**
A1: HPA calculates scaling by taking the pod's current metric usage (e.g., CPU) and comparing it to the requested resources to determine a percentage. If resource requests are not defined, HPA cannot calculate the percentage utilization and will fail to scale, showing `<unknown>` target.

**Q2: Explain the difference between HPA and VPA.**
A2: HPA (Horizontal) scales by changing the number of pod replicas (scaling out/in) to handle increased load. VPA (Vertical) scales by increasing or decreasing the CPU and Memory allocated to existing pods (scaling up/down), which typically requires restarting the pod. They should generally not be used together on the same metric (like CPU) to avoid conflicts.

**Q3: How do HPA and Cluster Autoscaler work together?**
A3: When HPA scales out a deployment, it creates new pods. If the cluster nodes do not have enough aggregate resources to schedule these new pods, they remain `Pending`. The Cluster Autoscaler detects these `Pending` pods and provisions new nodes from the cloud provider (e.g., adding an EC2 instance). Once the node is ready, the pods are scheduled.

**Q4: What is KEDA and what problem does it solve over standard K8s HPA?**
A4: KEDA is Kubernetes Event-driven Autoscaling. Standard HPA primarily scales on reactive metrics like CPU/Memory. KEDA allows scaling based on external, proactive metrics like the length of a message queue (SQS, Kafka) or database queries. It also introduces the ability to scale deployments completely down to zero, which standard HPA cannot do.

**Q5: What is 'thrashing' in autoscaling and how do you prevent it?**
A5: Thrashing occurs when a metric fluctuates rapidly around the target threshold, causing the autoscaler to constantly scale up and down in quick succession, destabilizing the application. It is prevented by configuring "stabilization windows" (cooldown periods) in the HPA configuration, which delay scale-in or scale-out actions until the metric has stabilized for a certain duration.

## Related Notes
- [[Master Index]]
- [[04-Orchestration/K8S-01 Kubernetes Architecture]]
- [[07-Cloud/AWS-01 AWS Core Services for DevOps]]
