---
tags: [devops, security, network-security]
aliases: [Network Security]
created: 2025-06-27
status: #complete
difficulty: #advanced
cert-relevant: #cks
---

# SEC-06 Network Security for DevOps

> [!abstract] Overview
> Network Security for DevOps is about moving beyond traditional perimeter-based security (like a single big firewall) to a more granular, identity-driven approach. This note covers essential concepts such as Zero Trust Network Access (ZTNA), securing Virtual Private Clouds (VPCs), implementing Web Application Firewalls (WAFs), and using mutual TLS (mTLS) for secure service-to-service communication in distributed systems like Kubernetes.

## Concept Overview
Traditional network security relied on a "castle-and-moat" model: if you are inside the corporate network, you are trusted. Today's environments (cloud, microservices, remote work) require "Zero Trust" — meaning no one and no device is trusted by default, regardless of where they are located.

*Hindi Explanation: Pehle hum sochte the ki network ek kile (castle) ki tarah hai, agar aap andar ho to sab safe hai. Par ab cloud aur microservices ke zamane mein koi boundary nahi rahi. Zero Trust ka matlab hai "kisi par bharosa mat karo, hamesha verify karo". Har connection ko baar-baar check karna padta hai.*

**Key Concepts:**
- **Zero Trust Network Access (ZTNA):** A security framework requiring all users, whether in or outside the organization's network, to be authenticated, authorized, and continuously validated.
- **VPC Security:** Using Subnets, Security Groups (stateful), and Network ACLs (stateless) to isolate and protect resources in the cloud.
- **Web Application Firewall (WAF):** A firewall specifically designed to protect web applications by filtering and monitoring HTTP traffic between a web application and the Internet (protects against SQLi, XSS, etc.).
- **mTLS (Mutual TLS):** An extension of standard TLS where both the client and server authenticate each other using digital certificates, ensuring traffic is both encrypted and verified at both ends.

**Desi Analogy:**
Think of standard TLS (like HTTPS on a website) as going to a bank. You check the bank's ID to make sure it's the real bank, but the bank doesn't know who you are until you log in.
**mTLS** is like entering a high-security military base. You check the guard's ID (server authentication), and the guard checks your ID card (client authentication). Both parties verify each other before any communication happens.

## Technical Deep Dive

### 1. The Zero Trust Architecture
Zero Trust shifts the security perimeter from static, network-based perimeters to focus on users, assets, and resources. It assumes that attackers are already present within the environment. Therefore, every request to access a resource must be strongly authenticated and authorized based on dynamic policies (identity, device health, location). In Kubernetes, Zero Trust is implemented through strict Network Policies that deny all traffic by default and only allow explicitly defined communication paths between pods.

### 2. VPC Security: SGs vs. NACLs
In AWS, securing a Virtual Private Cloud (VPC) relies on two main components:
- **Security Groups (SGs):** These act as a firewall at the instance/ENI level. They are *stateful* (if you allow inbound port 80, the return traffic is automatically allowed). You can only specify ALLOW rules.
- **Network Access Control Lists (NACLs):** These act as a firewall at the subnet level. They are *stateless* (return traffic must be explicitly allowed by outbound rules). You can specify both ALLOW and DENY rules. A common pattern is to use NACLs to block known bad IP blocks at the subnet edge, and use SGs for granular app-level access.

### 3. Mutual TLS (mTLS) in Service Meshes
In a microservices architecture, dozens of services talk to each other over the network. If an attacker breaches the network, they could eavesdrop or spoof requests. mTLS solves this by encrypting traffic *between* microservices and authenticating both ends.
Service meshes like Istio or Linkerd automatically inject a sidecar proxy (like Envoy) into every pod. These proxies handle the mTLS handshakes transparently. The application code doesn't need to know about certificates; the sidecar proxy intercepts the outbound call, establishes an mTLS connection with the destination sidecar, and securely forwards the traffic.

## Step-by-Step Lab
**Scenario:** Implement Zero Trust in a Kubernetes cluster using Network Policies. By default, pods in a namespace can talk to any other pod. We will lock it down so the `backend` can only receive traffic from the `frontend`.

**Step 1: Create a test namespace and pods**
```bash
kubectl create namespace zt-demo
kubectl run frontend --image=nginx --labels="app=frontend" -n zt-demo
kubectl run backend --image=nginx --labels="app=backend" -n zt-demo --expose --port=80
```
*Expected output: Namespace, pods, and backend service created.*

**Step 2: Verify default open communication**
```bash
kubectl exec -it frontend -n zt-demo -- curl -s http://backend
```
*Expected output: The default Nginx welcome page HTML. (Traffic is allowed by default).*

**Step 3: Apply a Default Deny Network Policy**
Create a file `default-deny.yaml`:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: zt-demo
spec:
  podSelector: {} # Selects all pods in the namespace
  policyTypes:
  - Ingress
  - Egress
```
Apply it:
```bash
kubectl apply -f default-deny.yaml
```
*Expected output: `networkpolicy.networking.k8s.io/default-deny-all created`*

**Step 4: Verify communication is now blocked**
```bash
kubectl exec -it frontend -n zt-demo -- curl --connect-timeout 3 http://backend
```
*Expected output: Command times out or says `Connection refused`. The network is now locked down.*

**Step 5: Allow explicit communication (Frontend to Backend)**
Create a file `allow-frontend-to-backend.yaml`:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: zt-demo
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 80
```
*(Note: To make DNS work for the frontend to resolve 'backend', you also need an egress policy to the kube-system namespace on port 53. For simplicity, we assume IP routing or add DNS egress separately).*
```bash
kubectl apply -f allow-frontend-to-backend.yaml
```
*Expected output: `networkpolicy.networking.k8s.io/allow-frontend-to-backend created`*

**Step 6: Test allowed communication**
```bash
kubectl exec -it frontend -n zt-demo -- curl -s http://backend
```
*Expected output: The Nginx welcome page HTML is visible again, but ONLY from the frontend pod.*

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
| :--- | :--- | :--- |
| `kubectl get netpol` | Lists NetworkPolicies in namespace | `kubectl get netpol -n myapp` |
| `kubectl describe netpol <name>` | Shows detailed policy rules | `kubectl describe netpol default-deny -n myapp` |
| `aws ec2 describe-security-groups` | Lists AWS SGs | `aws ec2 describe-security-groups --group-ids sg-12345` |
| `aws wafv2 list-web-acls` | Lists WAF Access Control Lists | `aws wafv2 list-web-acls --scope REGIONAL` |
| `istioctl x authz check` | Checks Istio authorization policies | `istioctl x authz check my-pod -n default` |
| `curl -v --cert <cert> --key <key>` | Test mTLS connection manually | `curl -v --cert client.crt --key client.key https://api` |
| `nmap -p <port> <ip>` | Scans for open ports | `nmap -p 80,443,22 192.168.1.100` |
| `tcpdump -i any port <port>` | Captures network packets | `tcpdump -i any port 80 -n` |

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
| :--- | :--- | :--- |
| Cannot resolve DNS inside Kubernetes pod after applying NetPol. | Default deny egress policy blocked access to CoreDNS. | 1. Create an Egress NetworkPolicy allowing UDP/TCP port 53 to `kube-system` namespace. 2. Apply the policy and re-test. |
| Application times out when connecting to database in AWS. | Security Group rules are missing or incorrect. | 1. Check DB SG inbound rules; ensure the app SG is referenced. 2. Ensure both are in the same VPC or have peering setup. |
| WAF blocking legitimate users (False Positive). | WAF rules (like SQLi or XSS detection) are too strict for your app's payload. | 1. Check AWS WAF sampled requests. 2. Identify the specific Rule ID blocking the traffic. 3. Add an exception or customize the rule payload inspection. |
| mTLS connection failing (503 or TLS error). | Certificate mismatch, expired certs, or strict mTLS enforced while client doesn't support it. | 1. Check sidecar proxy logs (e.g., Envoy logs). 2. Verify certificate validity dates. 3. Temporarily set mTLS mode to 'Permissive' to debug. |
| Subnet cannot access the internet (AWS). | NACL blocking traffic or missing NAT Gateway route. | 1. Check Route Table for `0.0.0.0/0` -> `nat-xxx`. 2. Check NACL outbound rules allow ephemeral ports (1024-65535) for return traffic. |

## Real-World Job Scenario
**The Situation:** A penetration testing team successfully accessed your Redis database from a public-facing web server pod because they found a vulnerability in the web server code. The CISO demands that Redis be isolated immediately so only the caching service can talk to it.

**Junior DevOps Action:**
- Changes the Redis password.
- Tries to reconfigure the web server to drop the connection.
- Leaves the network open, meaning if another pod is compromised, the attacker can still attempt to brute-force the new password.

**Senior DevOps Action:**
- Immediately drafts a Kubernetes NetworkPolicy with a default deny for the Redis namespace.
- Creates an explicit `Ingress` rule on the Redis pod that uses `podSelector` to strictly allow traffic *only* from pods labeled `app: cache-service`.
- Applies the policy via the GitOps pipeline.
- Explains to the CISO that even with no password, the network layer itself now drops packets from the compromised web server pod, achieving true Zero Trust.

## Interview Questions

**Q1: What is the difference between stateful and stateless firewalls (like AWS SGs vs. NACLs)?**
**A:** A stateful firewall (Security Group) tracks the state of active connections. If you allow inbound traffic on port 80, the firewall automatically remembers this and allows the return traffic back out, regardless of outbound rules. A stateless firewall (NACL) evaluates every packet independently. If you allow inbound on port 80, you must explicitly create an outbound rule allowing traffic on ephemeral ports to let the response out.

**Q2: Explain Mutual TLS (mTLS) and why it's necessary in microservices.**
**A:** In standard TLS, the client verifies the server's identity. In mTLS, the server also verifies the client's identity using certificates. In microservices architectures, mTLS ensures that not only is the traffic encrypted (preventing eavesdropping), but the server cryptographically guarantees that the request is coming from an authorized service, mitigating lateral movement by attackers inside the network.

**Q3: How does a Web Application Firewall (WAF) differ from a traditional network firewall?**
**A:** A traditional network firewall operates at Layer 3/4 (IP addresses and ports). A WAF operates at Layer 7 (Application layer). It inspects the actual HTTP/HTTPS content to block web-specific attacks like SQL injection, Cross-Site Scripting (XSS), and malicious bots, which a traditional firewall would blindly let through if port 443 is open.

**Q4: If you apply a default deny NetworkPolicy in Kubernetes, how do pods resolve DNS?**
**A:** If you deny all Egress traffic, pods cannot reach the CoreDNS pods in the `kube-system` namespace. You must explicitly create an Egress NetworkPolicy that allows traffic on UDP/TCP port 53 specifically to the CoreDNS pods (usually matched via namespace and pod labels).

**Q5: What is Zero Trust Network Access (ZTNA)?**
**A:** ZTNA is a security concept that abandons the idea of a trusted internal network. It requires that every request to a resource—whether coming from inside or outside the corporate network—must be authenticated, authorized, and continuously validated based on identity, context, and device health before access is granted.

## Related Notes
- [[Master Index]]
- [[SEC-05 Supply Chain Security]]
- [[SEC-01 Docker Security]]
