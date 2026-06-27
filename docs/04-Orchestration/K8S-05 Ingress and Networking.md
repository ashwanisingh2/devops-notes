---
tags: [devops, kubernetes, networking, ingress, security]
aliases: [K8s Networking & Ingress]
created: 2025-06-27
status: #complete
difficulty: #advanced
cert-relevant: #cka #ckad
---

# K8S-05 Ingress and Networking

> [!abstract] Overview
> Getting applications running in Kubernetes is only half the battle; exposing them securely to the internet is the other half. If you expose every microservice using a cloud LoadBalancer, your AWS bill will skyrocket. An Ingress provides a single, smart routing gateway for your entire cluster, handling HTTP/HTTPS routing, SSL termination, and host-based matching. Understanding Ingress, alongside internal Network Policies and CNI plugins, is the hallmark of an advanced Kubernetes engineer.

---

## Concept Overview

- **What it is** — **Ingress** is an API object that manages external access to the services in a cluster, typically via HTTP. A **NetworkPolicy** acts as an internal firewall between Pods. A **CNI** (Container Network Interface) is the underlying plugin that gives Pods IP addresses.
- **Why DevOps engineers use it** — To consolidate public traffic. Instead of 10 LoadBalancers for 10 microservices, you use 1 LoadBalancer pointing to an Ingress Controller, which acts as a reverse proxy (like Nginx) routing traffic based on the URL path (`/api` vs `/frontend`).
- **Where you encounter this in a real job** — Setting up `cert-manager` to automatically provision free Let's Encrypt SSL certificates for your websites, or writing a NetworkPolicy to prevent a compromised frontend Pod from directly accessing the database Pod.
- **Responsibility Split:**
  - **Junior DevOps**: Writes basic Ingress YAML to map a domain name to a Service.
  - **Mid DevOps**: Configures path-based routing, sets up `cert-manager` for TLS termination, and writes default-deny NetworkPolicies.
  - **Senior/SRE**: Manages the Ingress Controller deployment, evaluates CNI plugins (Calico vs Cilium/eBPF) for performance, and debugs CoreDNS resolution timeouts.

*Seedha simple mein: Ingress ek office building ka receptionist hai. Bahar se aane wala har aadmi (traffic) ek hi gate se aayega. Receptionist (Ingress Controller) puchega "Aapko kahan jana hai?", agar `/api` bola toh floor 1 bhejega, agar `/web` bola toh floor 2 bhejega. Isse 10 alag gate (LoadBalancers) banane ka kharcha bach jata hai.*

---

## Technical Deep Dive

### 1. Ingress and Ingress Controllers
An `Ingress` YAML simply defines routing rules. It does nothing on its own. You must install an **Ingress Controller** to execute those rules. The most popular is `ingress-nginx` (maintained by Kubernetes), but alternatives like Traefik or HAProxy are also common.
The Controller listens to the K8s API. When you create an Ingress rule saying "Route `api.example.com` to the API Service", the Controller dynamically updates its internal `nginx.conf` to make that happen. All external traffic hits the Controller's single public IP, which then reverse-proxies the request to the correct Pods.

### 2. TLS Termination and Cert-Manager
Handling HTTPS/SSL manually is tedious and error-prone. Modern K8s clusters use `cert-manager`. You define a `ClusterIssuer` (like Let's Encrypt). Then, in your Ingress YAML, you simply add a `tls` section. `cert-manager` detects this, automatically contacts Let's Encrypt, performs the DNS/HTTP validation challenge, downloads the certificate, and creates a K8s Secret. The Ingress Controller then uses this Secret to terminate TLS (decrypt the HTTPS traffic) before sending plain HTTP to your Pods.

### 3. CNI Plugins and NetworkPolicies
Kubernetes dictates that every Pod gets a unique IP and can talk to every other Pod without NAT. The **CNI** (Container Network Interface) makes this happen. 
- **Flannel**: Very simple, good for learning, but lacks NetworkPolicy support.
- **Calico**: The industry standard. Supports advanced routing (BGP) and robust NetworkPolicies.
- **Cilium**: The modern replacement using eBPF in the Linux kernel for extreme performance and security.
By default, K8s network traffic is "allow all". If a hacker compromises your frontend pod, they can ping your internal database pod. A **NetworkPolicy** acts like AWS Security Groups for Pods. A best practice is to deploy a "Default Deny All" policy, and then explicitly allow traffic only where necessary (e.g., Allow Frontend -> API -> Database).

---

## Step-by-Step Lab

> [!warning] Pre-requisites
> - Minikube running (`minikube start`)
> - Enable the Nginx Ingress Controller: `minikube addons enable ingress`

### Step 1: Deploy Two Sample Applications
```bash
# Create an apple and a banana app, and expose them as ClusterIP services
kubectl create deployment apple --image=hashicorp/http-echo -- -text="apple"
kubectl expose deployment apple --port=5678 --target-port=5678

kubectl create deployment banana --image=hashicorp/http-echo -- -text="banana"
kubectl expose deployment banana --port=5678 --target-port=5678
```

### Step 2: Create Path-Based Ingress Rules
```yaml
# Create ingress.yaml
cat << 'EOF' > ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fruit-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - path: /apple
        pathType: Prefix
        backend:
          service:
            name: apple
            port:
              number: 5678
      - path: /banana
        pathType: Prefix
        backend:
          service:
            name: banana
            port:
              number: 5678
EOF

kubectl apply -f ingress.yaml
```

### Step 3: Test the Routing
```bash
# Get the IP of your minikube node (which acts as the Ingress IP locally)
IP=$(minikube ip)

# Test routing
curl http://$IP/apple
# Expected output: apple

curl http://$IP/banana
# Expected output: banana
```

### Step 4: Implement a Default Deny NetworkPolicy
```yaml
# Create deny-all.yaml
cat << 'EOF' > deny-all.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {} # Selects ALL pods in the namespace
  policyTypes:
  - Ingress
EOF

kubectl apply -f deny-all.yaml
```

### Step 5: Test the Firewall and Allow Access
```bash
# Try to curl the apple service again
curl --max-time 3 http://$IP/apple
# Expected output: Timeout! Traffic is blocked by NetworkPolicy.

# To fix this, you would create a second NetworkPolicy that explicitly 
# allows Ingress traffic FROM the Ingress Controller namespace TO your pods.
```

> [!tip] Pro Tip
> If you are setting up `cert-manager` with Let's Encrypt, ALWAYS use the Staging issuer while testing. Let's Encrypt has strict rate limits. If you misconfigure your Ingress with the Production issuer, it might hit the API 50 times in an hour and ban your domain for a week.

---

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
|---------|-------------|--------------|
| `kubectl get ingress` | Lists Ingress rules and the IP they are bound to | `kubectl get ing` |
| `kubectl describe ing`| Shows exact routing rules and controller errors | `kubectl describe ing fruit-ingress` |
| `kubectl get netpol` | Lists NetworkPolicies in the namespace | `kubectl get netpol` |
| `kubectl get cert` | Lists cert-manager certificates and validity | `kubectl get cert -n prod` |
| `kubectl get clusterissuer`| Checks if Let's Encrypt is configured | `kubectl get clusterissuer` |
| `minikube ip` | Returns the local IP of the cluster (for local ingress) | `minikube ip` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| Ingress returns `404 Not Found` (from Nginx) | The path/host doesn't match, or missing rewrite | Check `kubectl describe ing`. If your app expects `/`, but the ingress path is `/api`, you must add the annotation `nginx.ingress.kubernetes.io/rewrite-target: /`. |
| Ingress returns `503 Service Unavailable` | Service lacks endpoints | The Ingress is routing to a Service, but the Service has no healthy Pods. Run `kubectl get endpoints <svc>`. |
| Certificate is stuck in `False` or `Pending` | cert-manager validation challenge failed | Run `kubectl describe challenge`. Ensure your domain's DNS A-record points to the Ingress Controller's public IP. |
| Pod cannot resolve `google.com` | CoreDNS is failing | Check CoreDNS logs: `kubectl logs -n kube-system -l k8s-app=kube-dns`. Usually caused by a broken `resolv.conf` on the worker node. |
| App cannot reach database after applying NetworkPolicy | Missing Egress rules | If you apply an Egress policy, you MUST explicitly allow DNS resolution (port 53 UDP) to CoreDNS, otherwise the app can't resolve the DB service name. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A developer deployed a new admin dashboard to the cluster. By mistake, they set the Ingress host rule to match our main domain `www.company.com`, overriding the production web app."

**What Junior DevOps Does:**
Panics, deletes the developer's Ingress object immediately, and tells the developer never to use that domain again.

**Escalation Trigger:**
The developer needs a way to test their code, but the cluster routing is a free-for-all. Anyone can claim any domain if they write the YAML.

**Senior Engineer Resolution:**
1. Implements the **Gatekeeper / OPA (Open Policy Agent)** admission controller.
2. Writes a Rego policy that intercepts all Ingress creation requests.
3. The policy states: "If a user is creating an Ingress in the `dev` namespace, the host MUST end with `.dev.company.com`. If it matches `www.company.com`, reject the API request."
4. Now, if a developer makes a typo or maliciously tries to steal production traffic, the `kubectl apply` command fails instantly with a clear error message.

**Lesson Learned:**
Trust no one with networking rules in a multi-tenant cluster. Enforce boundaries using Policy-as-Code to prevent catastrophic routing overrides.

---

## Interview Questions

**Q1 (Conceptual):** What is the difference between a LoadBalancer Service and an Ingress?
**A:** A LoadBalancer Service provisions a 1-to-1 cloud load balancer (like AWS ELB) for a single application, operating at Layer 4 (TCP/UDP). It gets expensive if you have many apps. An Ingress operates at Layer 7 (HTTP/HTTPS) and uses a single LoadBalancer to route traffic to dozens of different backend services based on URL paths or hostnames, saving costs and centralizing SSL management.

**Q2 (Practical):** How do you configure an Ingress rule to route `api.myapp.com` to the `api-svc` and `admin.myapp.com` to the `admin-svc`?
**A:** I would define an Ingress resource with two rules under the `rules` list. The first rule would have `host: api.myapp.com` with a backend pointing to `api-svc`. The second rule would have `host: admin.myapp.com` pointing to `admin-svc`.

**Q3 (Scenario-based):** You applied a default-deny NetworkPolicy to your namespace. Now, your frontend pod cannot talk to your backend pod. Write the logic for the NetworkPolicy to fix this.
**A:** I would create a new NetworkPolicy targeting the backend pods (using `podSelector: matchLabels: app: backend`). Under `ingress: from:`, I would add a `podSelector: matchLabels: app: frontend`. This explicitly allows incoming traffic to the backend, but only if it originates from a pod labeled as the frontend.

**Q4 (Deep dive):** Explain how `cert-manager` works with Let's Encrypt using the HTTP-01 challenge.
**A:** When an Ingress requests a certificate, `cert-manager` creates a temporary Pod (the solver) and a temporary Ingress rule mapping to a specific hidden path (`/.well-known/acme-challenge/...`). Let's Encrypt's servers make an HTTP request over the internet to that path on your domain. The solver Pod answers with the expected token. Let's Encrypt verifies you own the domain and issues the certificate, which `cert-manager` stores as a K8s Secret.

**Q5 (Trick/Gotcha):** Can you use a Kubernetes NetworkPolicy to block outbound internet access (e.g., stopping a hacked pod from downloading malware)?
**A:** Yes, but only if your CNI plugin supports it (like Calico or Cilium). Flannel does not support NetworkPolicies at all. If you are using Calico, you can define an `Egress` policy that defaults to deny, and then explicitly allow only internal cluster CIDRs and DNS (Port 53), effectively blocking access to public IP addresses.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[04-Orchestration/K8S-02 Pods Deployments Services|Services vs Ingress]]
[[04-Orchestration/K8S-06 RBAC and Security|RBAC and Security]] (OPA/Gatekeeper)
