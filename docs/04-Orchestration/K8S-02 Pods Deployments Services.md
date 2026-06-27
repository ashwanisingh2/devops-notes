---
tags: [devops, kubernetes, workloads, networking]
aliases: [Pods and Deployments]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #cka
---

# K8S-02 Pods Deployments Services

> [!abstract] Overview
> Understanding the Kubernetes architecture is theory; writing YAML manifests for Pods, Deployments, and Services is the daily practice. A Pod runs your container, a Deployment manages replicas and zero-downtime rollouts, and a Service provides a stable internal IP address to route traffic. Mastering these three core primitives allows a DevOps engineer to deploy resilient, highly-available applications that survive node failures and traffic spikes.

---

## Concept Overview

- **What it is** — **Pods** are the smallest deployable units in K8s (wrapping one or more containers). **Deployments** act as managers that ensure a specific number of Pod replicas are always running. **Services** are network abstractions that route traffic to those Pods.
- **Why DevOps engineers use it** — To achieve high availability and zero-downtime updates. If you deploy a new version of an app, a Deployment will roll it out gradually (Rolling Update), ensuring users never see a 502 error. Services ensure that even as Pod IPs constantly change (due to restarts), other apps can still reach them via a stable DNS name.
- **Where you encounter this in a real job** — Writing a deployment YAML for a new Java microservice, configuring health probes to stop K8s from routing traffic to a crashing pod, or exposing a frontend app to the internet via a LoadBalancer service.
- **Responsibility Split:**
  - **Junior DevOps**: Scales deployments up/down (`kubectl scale`), checks pod logs, and restarts deployments.
  - **Mid DevOps**: Writes the YAML files, configures Liveness/Readiness probes, and sets resource requests/limits.
  - **Senior/SRE**: Designs multi-container Pod patterns (sidecars), analyzes deployment rollout strategies (Canary/Blue-Green), and debugs complex Service endpoint routing failures.

*Seedha simple mein: Pod ek worker hai. Deployment uska manager hai jo dekhta hai ki hamesha 5 workers duty pe rahein, aur naye rules (updates) aane pe purane workers ko dheere-dheere replace karta hai. Service ek receptionist hai; clients receptionist ko request dete hain, aur wo free worker (Pod) ko kaam bhej deti hai.*

---

## Technical Deep Dive

### 1. Pods and Health Probes
A Pod usually runs one container, but can run multiple tightly-coupled containers (e.g., an App container + a Logging Sidecar container). Containers in the same Pod share the same network namespace (they can talk via `localhost`).
K8s needs to know if your app is healthy.
- **Liveness Probe**: "Is the app dead?" If this fails, K8s kills the pod and restarts it. (Good for apps stuck in deadlocks).
- **Readiness Probe**: "Is the app ready to take traffic?" If this fails, K8s stops sending user traffic to the pod, but does *not* kill it. (Good for apps taking a long time to load cache/DB connections).
- **Startup Probe**: Used for extremely slow-starting legacy apps to give them time before Liveness takes over.

### 2. ReplicaSets and Deployments
A **ReplicaSet** ensures a specified number of pod replicas are running at any given time. However, you rarely create them directly.
A **Deployment** is a higher-level controller that manages ReplicaSets. Its superpower is **Rolling Updates**. When you update the image tag in a Deployment, it creates a *new* ReplicaSet, scales it up by 1, then scales the *old* ReplicaSet down by 1, repeating this until all pods are updated. Parameters like `maxSurge` (how many extra pods can exist during update) and `maxUnavailable` (how many can be down) control this behavior. If the new version crashes, you can easily `kubectl rollout undo` to revert to the old ReplicaSet.

### 3. Service Types and Networking
Pods are ephemeral; they die and get new IP addresses constantly. A **Service** provides a stable IP and DNS name. It uses label selectors (e.g., `app: my-web`) to know which Pods to route traffic to.
- **ClusterIP** (Default): Exposes the service on a cluster-internal IP. Only reachable from *inside* the K8s cluster.
- **NodePort**: Opens a specific static port (between 30000-32767) on EVERY worker node's IP. Good for quick testing.
- **LoadBalancer**: Provisions a real cloud load balancer (like AWS ALB/ELB) pointing to the NodePorts. Used to expose apps to the public internet.
- **ExternalName**: Acts as a DNS CNAME alias to route internal cluster traffic to an external service (like a managed AWS RDS database).

---

## Step-by-Step Lab

> [!warning] Pre-requisites
> - A running K8s cluster (minikube/kind)
> - Kubectl configured

### Step 1: Create a Deployment YAML
```yaml
# Create web-deploy.yaml
cat << 'EOF' > web-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 5
EOF

# Apply it
kubectl apply -f web-deploy.yaml

# Expected output: deployment.apps/nginx-deployment created
```

### Step 2: Verify the Deployment and Pods
```bash
# Check deployment status
kubectl get deploy

# Check the running pods
kubectl get pods -l app=web

# Expected output:
# NAME                               READY   STATUS    RESTARTS   AGE
# nginx-deployment-5c689d88bb-abc1   1/1     Running   0          30s
# nginx-deployment-5c689d88bb-xyz2   1/1     Running   0          30s
# nginx-deployment-5c689d88bb-123w   1/1     Running   0          30s
```

### Step 3: Expose with a NodePort Service
```yaml
# Create web-svc.yaml
cat << 'EOF' > web-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
EOF

# Apply it
kubectl apply -f web-svc.yaml

# Expected output: service/nginx-service created
```

### Step 4: Perform a Rolling Update
```bash
# Update the image to a newer version
kubectl set image deployment/nginx-deployment nginx=nginx:1.25

# Watch the rolling update happen live
kubectl rollout status deployment/nginx-deployment

# Expected output:
# Waiting for deployment "nginx-deployment" rollout to finish: 1 out of 3 new replicas have been updated...
# deployment "nginx-deployment" successfully rolled out
```

### Step 5: Rollback a Bad Deployment
```bash
# Update to a broken image tag that doesn't exist
kubectl set image deployment/nginx-deployment nginx=nginx:broken-tag

# Check pods - they will be stuck in ErrImagePull
kubectl get pods

# Oh no! Roll back to the previous working version
kubectl rollout undo deployment/nginx-deployment

# Verify the fix
kubectl rollout status deployment/nginx-deployment

# Expected output: deployment "nginx-deployment" successfully rolled out (back to 1.25)
```

> [!tip] Pro Tip
> Never use `latest` as your image tag in a Deployment. If a Pod crashes and K8s pulls the image again, it might pull a newer, breaking version of `latest` without you knowing. Always pin your versions (e.g., `image: myapp:v1.2.3`).

---

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
|---------|-------------|--------------|
| `kubectl get deploy` | Lists Deployments and replica counts | `kubectl get deploy -n prod` |
| `kubectl get svc` | Lists Services and their exposed IPs/ports | `kubectl get svc` |
| `kubectl describe pod`| Shows detailed events and errors for a pod | `kubectl describe pod nginx-xyz` |
| `kubectl logs` | Outputs logs from a container inside a pod | `kubectl logs nginx-xyz -f` |
| `kubectl scale` | Manually scales a deployment replicas up/down | `kubectl scale deploy/nginx --replicas=5` |
| `kubectl rollout status`| Monitors the progress of a rolling update | `kubectl rollout status deploy/web` |
| `kubectl rollout undo`| Reverts a deployment to the previous revision | `kubectl rollout undo deploy/web` |
| `kubectl port-forward`| Forwards a local port directly to a pod/svc | `kubectl port-forward svc/db 5432:5432` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| Pod is stuck in `ImagePullBackOff` | K8s cannot find the Docker image | Check if the image name/tag has a typo. Ensure the registry requires authentication (needs a K8s ImagePullSecret). |
| Pod is stuck in `CrashLoopBackOff` | The application is crashing immediately | Check logs: `kubectl logs <pod-name> --previous`. Usually a missing environment variable, bad config, or code panic. |
| Service has no Endpoints | The Service `selector` doesn't match any Pod `labels` | Run `kubectl get endpoints <svc-name>`. If empty, check the `selector` in your svc.yaml and ensure it exactly matches the `labels` in the deploy.yaml. |
| Readiness probe fails constantly | The app is running, but failing the health check URL | Exec into the pod (`kubectl exec -it <pod> -- sh`) and run `curl localhost:<port>/health` to see what the app is returning (must be 200-399). |
| Cannot access NodePort | Cloud provider firewall is blocking the port | Open the specific NodePort (e.g., 30080) in your AWS Security Group or Azure NSG for the worker nodes. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "We just deployed v2.0 of our API. Suddenly, customers are getting 502 errors intermittently. The pods look like they are running."

**What Junior DevOps Does:**
Runs `kubectl get pods` and sees they are `Running`. Assumes the code is bad, immediately rolls back the deployment, and blames the developers.

**Escalation Trigger:**
The developers insist the code is fine. The rollback caused a delay in launching a critical marketing campaign.

**Senior Engineer Resolution:**
1. Looks closely at the deployment YAML.
2. Notices there is NO `readinessProbe` defined.
3. Explains the problem: During the rollout, K8s started the v2.0 container. Because there was no readiness probe, K8s assumed the pod was ready *immediately* and started sending user traffic to it. However, the Java Spring Boot app takes 15 seconds to connect to the database and warm up.
4. Users hitting the app during those 15 seconds got 502 Bad Gateway errors.
5. The Senior adds a `readinessProbe` checking the `/health` endpoint.
6. Now, during rollouts, K8s waits until the Java app explicitly returns a 200 OK before sending any user traffic to the new pods. Zero-downtime achieved.

**Lesson Learned:**
Without Liveness and Readiness probes, Kubernetes is flying blind. It doesn't know if your app is actually functioning, only if the Linux process has started.

---

## Interview Questions

**Q1 (Conceptual):** What is the difference between a Liveness Probe and a Readiness Probe?
**A:** A Liveness Probe checks if the application is dead or stuck; if it fails, K8s restarts the container. A Readiness Probe checks if the application is ready to handle incoming network traffic; if it fails, K8s removes the Pod's IP from the Service endpoints, stopping traffic, but does NOT kill the container.

**Q2 (Practical):** You need to securely access a database Pod that is not exposed via a Service to the outside world. How do you access it from your local laptop?
**A:** I would use `kubectl port-forward`. By running `kubectl port-forward pod/<db-pod-name> 5432:5432`, K8s creates a secure tunnel over the API server, mapping my laptop's local port 5432 directly to the pod's port 5432.

**Q3 (Scenario-based):** You scaled your deployment to 5 replicas, but 2 pods are stuck in the `Pending` state. What is the most likely cause and how do you verify?
**A:** The most likely cause is a lack of resources (CPU or Memory) on the worker nodes to satisfy the Pod's resource `requests`. To verify, I would run `kubectl describe pod <pending-pod-name>` and look at the `Events` section at the bottom, which will likely show a `FailedScheduling` message from the kube-scheduler stating "Insufficient cpu" or "Insufficient memory".

**Q4 (Deep dive):** Explain how a Kubernetes Service actually routes traffic to Pods under the hood using `kube-proxy`.
**A:** When a Service is created, K8s assigns it a virtual ClusterIP. The K8s API server notifies the `kube-proxy` running on every worker node. `kube-proxy` then updates the host's OS networking rules (usually iptables or IPVS). When a packet hits the virtual ClusterIP, the iptables rules intercept it and use random load-balancing (DNAT) to rewrite the destination IP to the actual IP of one of the healthy Pods in the Service's endpoint list.

**Q5 (Trick/Gotcha):** Can a Pod contain more than one container? If so, what is a valid use case?
**A:** Yes, K8s supports multi-container Pods. A classic use case is the "Sidecar" pattern. For example, the main container runs an Nginx web server that writes access logs to a file. The second container (sidecar) runs a log-forwarding agent (like Fluentbit) that reads that shared log file and ships the logs to an Elasticsearch cluster.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[04-Orchestration/K8S-01 Kubernetes Architecture|Kubernetes Architecture]]
[[04-Orchestration/K8S-03 ConfigMaps and Secrets|ConfigMaps and Secrets]]
