---
tags: [devops, security, supply-chain]
aliases: [Supply Chain Security]
created: 2025-06-27
status: #complete
difficulty: #advanced
cert-relevant: #cks
---

# SEC-05 Supply Chain Security

> [!abstract] Overview
> Supply chain security in DevOps focuses on securing the entire software development lifecycle (SDLC) from source code to production deployment. This involves verifying the authenticity, integrity, and provenance of every dependency, library, and tool used to build your software. With high-profile incidents like SolarWinds and Log4Shell, ensuring that your application is built only from trusted components is no longer optional.

## Concept Overview
What is a Software Supply Chain Attack? It's an attack where a cybercriminal infiltrates your system through an outside partner or provider with access to your systems and data. Instead of attacking you directly, they compromise a widely used component (like an open-source library or a build tool) that you rely on.

*Hindi Explanation: Supply chain security ka matlab hai apne software ke raw materials (dependencies, libraries) aur factory (CI/CD pipeline) ko secure karna. Jaise kisi restaurant mein khana banane ke liye sabzi mandi se aati hai, agar sabzi mein milawat ho to khana kharab hoga. Waise hi agar aapki dependencies mein malicious code ho, to pura software compromise ho jayega.*

**Key Concepts:**
- **SBOM (Software Bill of Materials):** A formal record containing the details and supply chain relationships of various components used in building software. Think of it as the ingredients list on a food packet.
- **SLSA (Supply-chain Levels for Software Artifacts):** A security framework, a check-list of standards and controls to prevent tampering, improve integrity, and secure packages and infrastructure.
- **Sigstore (Cosign):** A set of tools for signing, verifying, and protecting software components.

**Desi Analogy:**
Imagine you are running a famous Biryani shop. Your "Software" is the Biryani. The "Supply Chain" is the vendor who gives you rice, the vendor who gives you meat, and the vendor who gives you spices.
- **Supply Chain Attack:** If the spice vendor mixes poison in the spices (like SolarWinds).
- **SBOM:** The recipe book and the receipt from every vendor listing exactly what ingredients were used.
- **SLSA:** The health inspector's checklist verifying your kitchen's hygiene and vendor's licenses.
- **Sigstore (Cosign):** The quality seal on the meat from a trusted butcher, which you verify before cooking.

## Technical Deep Dive

### 1. Major Supply Chain Attacks
**SolarWinds (2020):** Attackers compromised the build system of SolarWinds' Orion IT monitoring software. They injected malicious code into the legitimate software updates. When thousands of organizations (including US government agencies) downloaded the update, they unwittingly installed a backdoor into their networks. This highlighted the danger of trusting signed software from compromised build pipelines.
**Log4Shell (2021):** A critical vulnerability in the widely used Apache Log4j Java logging library. Since Log4j is embedded in millions of applications, it allowed remote code execution (RCE) simply by logging a specific string. This demonstrated how deeply embedded open-source dependencies can create widespread havoc if a vulnerability is discovered.

### 2. SBOM and Generation Tools (Syft)
An SBOM is essentially a machine-readable inventory (JSON/SPDX/CycloneDX format) of all open-source and third-party components in a software product. This visibility is crucial for vulnerability management. When a new vulnerability (like Log4Shell) is announced, you can instantly query your SBOMs to find out which of your applications are affected, rather than scanning everything from scratch.
**Syft** is a powerful CLI tool and Go library for generating a Software Bill of Materials (SBOM) from container images and filesystems. It supports multiple output formats (CycloneDX, SPDX) and is highly integrated into modern CI/CD pipelines to ensure every built image has an accompanying SBOM.

### 3. Securing Artifacts with SLSA and Sigstore
**SLSA** (pronounced "salsa") provides a graded set of security guidelines (Levels 1 to 4). It covers source control (e.g., two-person review), build processes (e.g., ephemeral and isolated environments), and provenance (cryptographic proof of how an artifact was built).
**Sigstore** simplifies cryptographic signing. Traditionally, managing GPG keys for signing container images was a nightmare. **Cosign** (part of Sigstore) allows you to sign container images and store the signatures in the OCI registry itself. It also supports keyless signing using OpenID Connect (OIDC), tying signatures to developer identities or CI/CD service accounts, completely removing the burden of key management.

## Step-by-Step Lab
**Scenario:** You need to generate an SBOM for an Nginx container image, and then sign that image to prove its authenticity before it can be deployed to your Kubernetes cluster.

**Step 1: Install Syft and Cosign**
```bash
# Install Syft
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Install Cosign
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign
```
*Expected output: Commands complete silently. You can verify with `syft version` and `cosign version`.*

**Step 2: Generate an SBOM for an image**
```bash
syft nginx:latest -o cyclonedx-json > nginx-sbom.json
```
*Expected output: Generates a JSON file containing the inventory of the nginx image.*

**Step 3: Generate a Cosign Keypair**
```bash
cosign generate-key-pair
```
*Expected output: Prompts for a password. Creates `cosign.key` (private) and `cosign.pub` (public) files in your current directory.*

**Step 4: Tag and Push a custom image (requires a registry like Docker Hub)**
```bash
# Assuming you are logged into Docker Hub as 'myuser'
docker pull nginx:latest
docker tag nginx:latest myuser/my-nginx:secure
docker push myuser/my-nginx:secure
```
*Expected output: Standard docker push output with image digest.*

**Step 5: Sign the image with Cosign**
```bash
cosign sign --key cosign.key myuser/my-nginx:secure
```
*Expected output: Prompts for password. Pushes the signature to the registry alongside the image.*

**Step 6: Verify the image signature**
```bash
cosign verify --key cosign.pub myuser/my-nginx:secure
```
*Expected output: Outputs a JSON object verifying the signature and showing the claims.*

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
| :--- | :--- | :--- |
| `syft <image>` | Generates a quick text-based SBOM | `syft ubuntu:22.04` |
| `syft <image> -o <format>` | Generates SBOM in a specific format | `syft myapp:latest -o spdx-json=sbom.json` |
| `cosign generate-key-pair` | Creates public/private keys for signing | `cosign generate-key-pair` |
| `cosign sign --key <key> <image>` | Signs a container image in a registry | `cosign sign --key cosign.key myrepo/app:v1` |
| `cosign verify --key <key> <img_name>`| Verifies the signature of an image | `cosign verify --key cosign.pub myrepo/app:v1` |
| `cosign attach sbom --sbom <file> <img>`| Attaches an SBOM to an image in registry | `cosign attach sbom --sbom sbom.json myapp:v1` |
| `grype <image>` | Scans image for vulnerabilities | `grype ubuntu:latest` |
| `grype sbom:<file>` | Scans an existing SBOM for vulnerabilities| `grype sbom:nginx-sbom.json` |

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
| :--- | :--- | :--- |
| `error: no matching signatures: ...` | Verifying an image that hasn't been signed or using wrong public key. | 1. Ensure you signed the exact tag/digest. 2. Verify you are using the correct `cosign.pub` file corresponding to the private key used for signing. |
| `Error response from daemon: Get "https://...": unauthorized` | Cosign cannot authenticate to the container registry. | 1. Run `docker login`. 2. Ensure your registry credentials have push permissions. |
| `syft: command not found` | Syft is not installed or not in your system's PATH. | 1. Re-run installation script. 2. `export PATH=$PATH:/usr/local/bin` (or wherever syft was installed). |
| `error getting credentials ...` | Cosign is trying to use an OIDC provider in a non-interactive environment (CI). | Set `COSIGN_EXPERIMENTAL=1` (for older versions) or use an explicit identity token. In GitHub Actions, ensure `id-token: write` permission is set. |
| SBOM JSON file is empty or invalid. | The image might not have standard package managers, or was built from scratch without metadata. | Check the base image. For scratch images with Go binaries, ensure binaries were built without stripping metadata. |

## Real-World Job Scenario
**The Situation:** A new zero-day vulnerability in a popular image processing library is announced on Twitter. The CISO wants to know within 1 hour if any production services are affected.

**Junior DevOps Action:**
- Panics slightly.
- Starts writing a bash script to `docker exec` into every running pod in Kubernetes and run `find` or `dpkg -l`.
- Tries to clone all 50 application repositories to grep `package.json` or `requirements.txt`.
- Takes hours and misses applications deployed manually.

**Senior DevOps Action:**
- Opens the centralized vulnerability management dashboard (e.g., DefectDojo, or an Anchore Enterprise dashboard).
- Alternatively, scripts a query against the centralized S3 bucket where all CI/CD pipelines automatically upload their generated SBOMs using `syft` and `grype`.
- Run `grype sbom:/path/to/bucket/ --search <CVE-ID>` (conceptual).
- Identifies the 3 affected microservices within 5 minutes.
- Triggers a rebuild of those 3 services with the patched library and relies on the Kubernetes admission controller (Kyverno/OPA) to block unsigned images, ensuring the fix is deployed securely.

## Interview Questions

**Q1: Explain what a Software Bill of Materials (SBOM) is and why it is important.**
**A:** An SBOM is a formal, machine-readable inventory of all components, libraries, and dependencies that make up a software application. It is important because it provides visibility. In the event of a vulnerability like Log4Shell, an SBOM allows an organization to immediately identify if and where the vulnerable component is used, rather than scanning entire environments reactively.

**Q2: What was the primary mechanism of the SolarWinds supply chain attack?**
**A:** The attackers compromised the build environment of SolarWinds. They injected malicious code into the legitimate build process of the Orion software. As a result, SolarWinds unknowingly signed and distributed the compromised updates to their customers. This showed that trusting the vendor's signature isn't enough if their internal build pipeline is compromised.

**Q3: How does Cosign improve upon traditional GPG signing for container images?**
**A:** Traditional GPG required complex key management, secure storage, and distribution of public keys. Cosign integrates directly with OCI registries, allowing signatures to be stored alongside the images. More importantly, it supports "keyless" signing using OIDC (OpenID Connect), where short-lived certificates are generated based on a developer's or CI system's identity, eliminating long-term key management.

**Q4: What is the SLSA framework?**
**A:** SLSA (Supply-chain Levels for Software Artifacts) is a security framework introduced by Google that provides a checklist of standards and controls to ensure the integrity of software artifacts. It defines different levels (1-4), requiring increasingly strict controls like ephemeral build environments, provenance generation, and two-person code reviews.

**Q5: If you sign a container image, does that mean the image is free of vulnerabilities?**
**A:** No. Signing an image only guarantees provenance and integrity—it proves *who* built the image and that it hasn't been *tampered with* since it was signed. A developer could easily sign a container image that contains critical vulnerabilities or malicious code. Signing must be combined with vulnerability scanning (like Grype/Trivy) for comprehensive security.

## Related Notes
- [[Master Index]]
- [[SEC-01 Docker Security]]
- [[SEC-06 Network Security for DevOps]]
