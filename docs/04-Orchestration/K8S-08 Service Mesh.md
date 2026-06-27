---
tags: [devops, kubernetes, service-mesh]
aliases: [K8S Service Mesh]
created: 2025-06-27
status: #complete
difficulty: #advanced
cert-relevant: #cka
---
# Kubernetes Service Mesh

> [!abstract]
> This note dives into the concept of a Service Mesh in Kubernetes, focusing on how it manages service-to-service communication. We explore the architecture of a service mesh, compare popular tools like Istio and Linkerd, and understand critical features such as mutual TLS (mTLS), traffic management (canary releases, fault injection), and deep observability without altering application code.

## Concept Overview

As Kubernetes environments grow from a few monoliths to dozens of microservices, managing network traffic, security, and observability becomes incredibly complex. A Service Mesh is a dedicated infrastructure layer that handles this communication.
- **Data Plane:** Lightweight proxies (like Envoy) deployed as "sidecars" alongside every application container in a pod. They intercept and manage all inbound and outbound network traffic.
- **Control Plane:** The centralized management component (like Istiod in Istio) that configures the proxies, manages certificates, and gathers telemetry data.
- **Key Capabilities:** Traffic shaping (canary, blue/green), reliability (retries, timeouts, circuit breakers), security (mTLS, authorization policies), and observability (distributed tracing, metrics).

*Hindi translation & analogy:* *Service mesh ko ek modern city ke traffic control system ki tarah socho. Normal K8s mein services ek doosre se direct baat karte hain (jaise bina traffic lights ki sadak). Service mesh har ghar (pod) ke bahar ek smart security guard (sidecar proxy) bitha deta hai. Ab koi bhi communication in guards ke through hota hai. Ye guards traffic divert kar sakte hain, ID check kar sakte hain (mTLS), aur bata sakte hain ki kaun kisse baat kar raha hai (observability), bina actual ghar walo (app code) ko disturb kiye.*

## Technical Deep Dive

### 1. Istio vs Linkerd
Istio and Linkerd are the dominant players in the Kubernetes service mesh space.
**Istio** uses Envoy as its data plane proxy. It is feature-rich, supporting complex routing, multi-cluster setups, and fine-grained authorization. However, it is resource-intensive and has a steep learning curve.
**Linkerd** uses a purpose-built Rust micro-proxy. It focuses on simplicity, performance, and low resource overhead. It is often the preferred choice when you need fundamental mTLS and observability without the extreme complexity of Istio's advanced routing.

### 2. Mutual TLS (mTLS) and Zero Trust
In a default K8s cluster, pod-to-pod traffic is unencrypted plain text. A compromised pod can sniff network traffic. A service mesh enforces mTLS. The Control Plane acts as a Certificate Authority (CA), issuing short-lived certificates to every sidecar proxy. When Pod A talks to Pod B, Proxy A encrypts the connection and authenticates to Proxy B. This establishes a Zero Trust network where identity is cryptographically verified rather than relying on network perimeter defense.

### 3. Traffic Splitting and Canary Deployments
Traditional Kubernetes Deployments update pods incrementally but offer poor control over traffic percentage (e.g., you can't easily send exactly 5% of traffic to a new version). Istio introduces Custom Resource Definitions (CRDs) like `VirtualService` and `DestinationRule`. A `VirtualService` can intelligently route Layer 7 (HTTP) traffic, sending 90% of requests to version v1 and 10% to v2 (Canary release), or route based on HTTP headers (e.g., routing users with an "internal-tester" cookie to a beta version).

## Step-by-Step Lab

**Scenario:** Install Istio on Minikube, deploy the Bookinfo sample app, configure a 70/30 canary traffic split, and visualize it in Kiali.

1. **Download and Install Istio CLI**
   ```bash
   curl -L https://istio.io/downloadIstio | sh -
   cd istio-*
   export PATH=$PWD/bin:$PATH
   ```
2. **Install Istio on Kubernetes**
   ```bash
   istioctl install --set profile=demo -y
   # Label the default namespace for automatic sidecar injection
   kubectl label namespace default istio-injection=enabled
   ```
3. **Deploy the Bookinfo Sample Application**
   ```bash
   kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
   kubectl get pods # Notice 2/2 containers (app + istio-proxy)
   ```
4. **Deploy the Istio Addons (Kiali, Prometheus, Jaeger)**
   ```bash
   kubectl apply -f samples/addons
   # Wait for pods to be ready, then open Kiali dashboard
   istioctl dashboard kiali &
   ```
5. **Create a Canary Traffic Split (70/30)**
   First, define `DestinationRules` to identify versions, then a `VirtualService` for routing:
   Create `traffic-split.yaml`:
   ```yaml
   apiVersion: networking.istio.io/v1alpha3
   kind: VirtualService
   metadata:
     name: reviews
   spec:
     hosts:
     - reviews
     http:
     - route:
       - destination:
           host: reviews
           subset: v1
         weight: 70
       - destination:
           host: reviews
           subset: v2
         weight: 30
   ---
   apiVersion: networking.istio.io/v1alpha3
   kind: DestinationRule
   metadata:
     name: reviews
   spec:
     host: reviews
     subsets:
     - name: v1
       labels:
         version: v1
     - name: v2
       labels:
         version: v2
   ```
   ```bash
   kubectl apply -f traffic-split.yaml
   ```
6. **Generate Traffic and Verify**
   Run a loop making curl requests to the ingress gateway and check the Kiali dashboard graph to visually verify the 70/30 split.

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
| :--- | :--- | :--- |
| `istioctl install` | Installs Istio into the cluster | `istioctl install --set profile=default -y` |
| `istioctl analyze` | Analyzes namespace for Istio issues | `istioctl analyze -n default` |
| `istioctl proxy-status` | Shows sync status of all sidecar proxies | `istioctl proxy-status` |
| `kubectl label namespace` | Enables auto sidecar injection | `kubectl label namespace my-app istio-injection=enabled` |
| `istioctl dashboard kiali` | Opens Kiali observability UI | `istioctl dashboard kiali` |
| `linkerd check` | Validates Linkerd installation | `linkerd check --pre` |
| `linkerd install` | Generates Linkerd installation manifests | `linkerd install \| kubectl apply -f -` |
| `kubectl get virtualservices` | Lists Istio routing rules | `kubectl get virtualservices -n my-app` |

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
| :--- | :--- | :--- |
| **Pods have 1/1 containers (no proxy)** | Namespace missing `istio-injection=enabled` label. | 1. `kubectl label namespace default istio-injection=enabled`. 2. Restart the pods: `kubectl rollout restart deploy <name>`. |
| **503 Service Unavailable between pods** | mTLS policy mismatch or network policy blocking proxy ports. | 1. Check `PeerAuthentication` objects in the namespace. 2. Verify `istioctl analyze` reports no misconfigurations. |
| **Traffic splitting is not working** | Missing `DestinationRule` or incorrect label selectors. | 1. Ensure `DestinationRule` subsets match the actual pod labels (`version: v1`). 2. Verify `VirtualService` references the exact host and subset names. |
| **High CPU/Memory on Worker Nodes** | Envoy proxies consuming too many resources due to large mesh size. | 1. Optimize configuration by applying `Sidecar` CRDs to limit the scope of services each proxy knows about. 2. Increase node sizes. |
| **Kiali graph is empty** | No traffic flowing or Prometheus addon not deployed. | 1. Ensure `samples/addons/prometheus.yaml` is deployed. 2. Use a load generator (like Hey or curl loop) to send continuous requests. |

## Real-World Job Scenario

**Scenario:** The security team mandates that all internal microservice communication must be encrypted, and the product team wants to test a risky new checkout service with only 5% of users.

**Junior DevOps Action:** Starts modifying the application code of every single microservice to implement TLS certificates manually, and tries to use standard K8s deployments for the rollout, failing to achieve exactly 5%.
**Senior DevOps Action:** Introduces Istio. Enables STRICT mTLS cluster-wide via a `PeerAuthentication` policy, securing all traffic instantly without code changes. Creates a `VirtualService` to route exactly 5% of traffic to the `checkout-v2` deployment, monitoring the error rates in Kiali before gradually increasing the weight to 100%.

## Interview Questions

**Q1: What is a sidecar proxy in the context of a service mesh?**
A1: A sidecar proxy (like Envoy) is a lightweight container deployed in the same Pod as the application container. It intercepts all inbound and outbound network traffic for that application, allowing the service mesh to manage routing, security, and observability transparently.

**Q2: How does Istio achieve mutual TLS (mTLS)?**
A2: The Istio control plane (Istiod) acts as a Certificate Authority. It generates and distributes cryptographic certificates to the Envoy proxies. When two services communicate, their proxies establish a TLS connection, authenticating each other's certificates, ensuring traffic is encrypted and identities are verified.

**Q3: Contrast Istio and Linkerd.**
A3: Istio uses Envoy (C++), has a comprehensive feature set (advanced Layer 7 routing, API gateway capabilities), but has a steeper learning curve and higher resource footprint. Linkerd uses a custom Rust micro-proxy, prioritizes extreme simplicity, zero-config mTLS, and low overhead, but lacks some of the complex routing capabilities of Istio.

**Q4: What is the purpose of an Istio `VirtualService` vs a `DestinationRule`?**
A4: A `VirtualService` defines *how* traffic is routed to a service (e.g., match HTTP path `/api`, route 80% to version A). A `DestinationRule` defines *what* happens to traffic after it is routed (e.g., define the subsets/versions based on labels, configure circuit breakers, or set TLS settings).

**Q5: How does a Service Mesh improve observability?**
A5: Because all traffic flows through the proxies, the mesh automatically generates metrics (request rates, error rates, latencies) and distributed tracing spans for every hop. This provides deep visibility into microservice performance and dependencies via tools like Jaeger and Kiali, without requiring developers to instrument their code.

## Related Notes
- [[Master Index]]
- [[04-Orchestration/K8S-01 Kubernetes Architecture]]
- [[04-Orchestration/K8S-09 Kubernetes Operators and CRDs]]
