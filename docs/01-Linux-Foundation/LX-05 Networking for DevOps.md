---
tags: [devops, networking, linux]
aliases: [DevOps Networking]
created: 2025-06-27
status: #complete
difficulty: #advanced
cert-relevant: #ccna
---

# LX-05 Networking for DevOps

> [!abstract]
> "It's always DNS." Networking is the backbone of DevOps. Whether configuring an AWS VPC, setting up an Ingress Controller in Kubernetes, or troubleshooting why a microservice can't reach a database, deep knowledge of TCP/IP, DNS, TLS, and routing is non-negotiable.

## Concept Overview

**What:** Networking for DevOps focuses on the application and transport layers (OSI Layers 4-7), dealing with how data travels from a user's browser, through firewalls and load balancers, into a container.
**Why:** Modern infrastructure is heavily distributed. A single web request traverses DNS servers, CDNs, Load Balancers, and reverse proxies. When communication breaks, you need to know exactly which layer failed.
**Where:** Configuring Cloud Security Groups, setting up NGINX/HAProxy, managing Route53 DNS, and debugging container networking (CNI).
**Responsibility Split:** Network Engineers manage physical switches and BGP routing; DevOps Engineers manage software-defined networking (VPCs), application load balancing, and firewall rules (iptables/security groups).

*Network troubleshooting ek detective game ki tarah hai. Agar website nahi khul rahi, toh problem browser mein (Layer 7), port block (Layer 4), ya IP routing (Layer 3) kisi mein bhi ho sakti hai. Step-by-step trace karna zaroori hai.*

## Technical Deep Dive

### 1. TCP/UDP, OSI, and HTTP Evolution
The **OSI Model** provides a framework. DevOps mostly cares about Layer 3 (IP/Routing), Layer 4 (TCP/UDP Ports), and Layer 7 (HTTP/DNS). 
**TCP** requires a 3-way handshake (SYN, SYN-ACK, ACK) guaranteeing delivery, making it reliable for Databases and HTTP. **UDP** is connectionless and fast, used for Video streaming and DNS queries.
**HTTP/1.1** loads assets sequentially. **HTTP/2** multiplexes requests over a single TCP connection, drastically improving speed. **HTTP/3** drops TCP entirely and uses QUIC (built on UDP) to reduce latency and handle packet loss better on mobile networks.

### 2. DNS and TLS/SSL Handshake
**DNS (Domain Name System)** translates domain names to IPs. 
- **A Record:** Maps name to IPv4.
- **CNAME:** Maps a name to another name (alias).
- **TXT:** Used for domain verification and SPF/DMARC.
**HTTPS** relies on the TLS Handshake. Before HTTP data is sent, the client and server agree on encryption keys. The server presents an **SSL/TLS Certificate** containing its Public Key, signed by a trusted Certificate Authority (CA). If the cert is expired or self-signed, the browser throws a security warning.
*DNS internet ka phonebook hai. Bina DNS ke aapko har website ka IP address (phone number) yaad rakhna padta.*

### 3. Load Balancing, Firewalls, and SSH
**Load Balancers** distribute traffic across multiple servers using algorithms like Round Robin, Least Connections, or IP Hash. 
**Firewalls** (like Linux `iptables` or Cloud Security Groups) act as bouncers, allowing or denying traffic based on IP, Port, and Protocol.
**SSH (Secure Shell)** is more than just remote terminal access. You can use SSH Tunnels for port forwarding, or **ProxyJump** (`-J`) to securely connect to a private server by bouncing through a public Bastion host.

## Step-by-Step Lab

**Objective:** Inspect TLS certificates, trace network packets, configure a basic firewall, and use SSH ProxyJump.

**Step 1: Inspect a TLS Certificate**
Use `openssl` to see when a website's SSL certificate expires.
```bash
echo | openssl s_client -servername google.com -connect google.com:443 2>/dev/null | openssl x509 -noout -dates
```
*Expected Output:* Shows `notBefore` (issue date) and `notAfter` (expiry date).

**Step 2: DNS Resolution Tracing**
Check the A records for a domain using `dig`.
```bash
dig +short A google.com
```
*Expected Output:* A list of IPv4 addresses.

**Step 3: Capture Network Traffic (Packet Sniffing)**
Use `tcpdump` to capture ICMP (ping) traffic on all interfaces. (Requires root/sudo).
```bash
sudo tcpdump -i any icmp -n -c 5
```
*Open another terminal and run `ping -c 2 8.8.8.8` to generate traffic.*
*Expected Output:* You will see the raw `Echo Request` and `Echo Reply` packets.

**Step 4: Block Traffic with iptables**
Block all incoming traffic from a specific annoying IP. (Use a dummy IP for safety).
```bash
sudo iptables -A INPUT -s 203.0.113.50 -j DROP
```
Verify the rule was added:
```bash
sudo iptables -L INPUT -v -n
```
*Expected Output:* Shows a DROP rule for source `203.0.113.50`.

**Step 5: SSH ProxyJump (Bastion Host)**
If you have a private server `10.0.0.5` that can only be reached via a public bastion `bastion.mycorp.com`.
```bash
# Don't run this unless you have actual servers
ssh -J user@bastion.mycorp.com user@10.0.0.5
```
*Expected Output:* You seamlessly log into `10.0.0.5` without manually SSHing twice.

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
| :--- | :--- | :--- |
| `ping <ip>` | Tests Layer 3 IP connectivity (ICMP) | `ping 1.1.1.1` |
| `telnet <ip> <port>` | Tests Layer 4 TCP port connectivity | `telnet github.com 443` |
| `nc -zv <ip> <port>` | Netcat port scanner (modern telnet alternative) | `nc -zv 10.0.0.5 3306` |
| `curl -Iv <url>` | Checks Layer 7 HTTP response headers and TLS | `curl -Iv https://api.site.com` |
| `dig <domain>` | Performs DNS lookup | `dig +short CNAME www.site.com` |
| `netstat -tulpn` | Lists open ports and listening processes | `sudo netstat -tulpn \| grep 80` |
| `iptables -L -n` | Lists active firewall rules | `sudo iptables -L -n` |
| `openssl s_client` | Debugs SSL/TLS connections | `openssl s_client -connect site:443` |

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
| :--- | :--- | :--- |
| App can't connect to Database, `ping` works but connection times out. | Layer 3 (Routing/Ping) is fine, but Layer 4 (TCP Port) is blocked by a firewall or Security Group. | 1. Test port with `nc -zv <db-ip> 3306`. 2. If it fails, check AWS Security Groups or local `iptables` allowing port 3306. |
| `curl: (6) Could not resolve host` | The server's DNS configuration is broken, or the domain doesn't exist. | 1. Check `/etc/resolv.conf` for valid nameservers (like 8.8.8.8). 2. Verify with `dig <domain>`. |
| `SSL certificate problem: certificate has expired` | The TLS certificate on the remote server passed its `notAfter` date. | 1. Run `openssl s_client... \| openssl x509 -noout -dates` to verify expiry. 2. Renew cert via Let's Encrypt / CA. |
| NGINX returns `502 Bad Gateway` | The Load Balancer/Proxy can't reach the backend application server. | 1. Check if backend app is running. 2. Verify the backend IP/Port in NGINX config. 3. Check for firewall blocks between NGINX and the app. |
| Service is running, but `curl localhost:8080` connection refused | The app is bound to `127.0.0.1` (localhost) instead of `0.0.0.0` (all interfaces). | 1. Run `netstat -tulpn`. 2. If you see `127.0.0.1:8080`, edit the app config to bind to `0.0.0.0` so it accepts external connections. |

## Real-World Job Scenario

**Scenario:** The monitoring system alerts that the production website is inaccessible.
- **Junior Action:** Logs into the web server, restarts NGINX, restarts the database, and panics when it still doesn't work. Checks the code repository for recent commits.
- **Senior Action:** Takes a systematic OSI approach. 
  1. Checks Layer 7: Runs `curl -Iv https://mywebsite.com`. Sees an SSL error.
  2. Checks Layer 4: Runs `nc -zv <server-ip> 443` - connects successfully.
  3. Realizes it's a certificate issue. Runs `openssl s_client` and notices the TLS cert expired 10 minutes ago. Triggers the certbot renewal script, restarting the proxy. Issue resolved in 2 minutes.

## Interview Questions

**Q1: What happens at the network layer when you type google.com in your browser?**
**A:** 1. The browser checks its cache for the IP. 2. OS checks `/etc/hosts`. 3. OS queries the DNS server to resolve the A record. 4. Browser initiates a TCP 3-way handshake to the IP on port 443. 5. A TLS handshake secures the connection. 6. Browser sends an HTTP GET request. 7. Server responds with HTML.

**Q2: What is the difference between an A Record and a CNAME?**
**A:** An `A Record` maps a hostname directly to an IPv4 address (e.g., `api.com -> 1.2.3.4`). A `CNAME` (Canonical Name) maps a hostname to another hostname (e.g., `www.site.com -> site.com`). You cannot point a CNAME directly to an IP address.

**Q3: How would you securely connect to a database in a private subnet that has no public internet access?**
**A:** I would use an SSH Bastion host (Jump server) located in a public subnet. By using SSH Local Port Forwarding (`ssh -L`) or the `ProxyJump` flag (`ssh -J`), I can securely tunnel my local traffic through the Bastion host directly into the private database.

**Q4: Explain the difference between TCP and UDP.**
**A:** TCP is connection-oriented. It ensures delivery through handshakes and acknowledgments; if a packet drops, it is retransmitted. It is reliable but slower (used for HTTP, SSH, DBs). UDP is connectionless and fires packets without checking if they arrived. It is fast but unreliable (used for Video streaming, DNS, VoIP).

**Q5: What is the purpose of the `/etc/hosts` file?**
**A:** The `/etc/hosts` file is a local text file used by the OS to map hostnames to IP addresses before querying public DNS servers. It is commonly used in DevOps for local development or overriding public DNS resolution to test a new server.

## Related Notes
- [[LX-04 OS Concepts for DevOps]]
- [[Master Index]]
