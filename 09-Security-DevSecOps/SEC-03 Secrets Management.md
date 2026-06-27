---
tags: [devops, security, secrets, vault, iam]
aliases: [Secrets Management]
created: 2025-06-27
status: #complete
difficulty: #advanced
cert-relevant: #none
---

# SEC-03 Secrets Management

> [!abstract] Overview
> Passwords, API tokens, and private SSH keys are the keys to the kingdom. Historically, developers hardcoded these directly into the source code, leading to catastrophic breaches when the code was uploaded to GitHub. Secrets Management is the discipline of removing all sensitive data from code and configuration files, securely storing them in an encrypted central vault, and dynamically injecting them into applications at runtime. If you cannot securely manage secrets, your entire infrastructure is compromised by default.

---

## Concept Overview

- **What it is** — The lifecycle management (generation, storage, rotation, and revocation) of digital credentials. 
- **Why DevOps engineers use it** — To prevent credentials from leaking in Git, CI/CD logs, or Docker images. It also solves the "rotation" problem. If an API key is compromised, you can rotate it in the central vault, and all 50 microservices instantly use the new key upon restart, without changing any code.
- **Where you encounter this in a real job** — Configuring a Kubernetes Pod to fetch database credentials from AWS Secrets Manager using the External Secrets Operator, or setting up HashiCorp Vault to generate dynamic, temporary database users for a CI/CD pipeline.
- **Responsibility Split:**
  - **Junior DevOps**: Scans code with `git-secrets` or `trufflehog` to ensure no passwords are accidentally committed.
  - **Mid DevOps**: Integrates CI/CD pipelines with secret stores (e.g., using GitHub Actions Secrets or Jenkins Credentials) to avoid hardcoding deployment tokens.
  - **Senior/SRE**: Architects and operates HashiCorp Vault clusters, implements "Dynamic Secrets" (credentials that expire in 10 minutes), and handles K8s identity mapping (IRSA in AWS).

*Seedha simple mein: Pehle hum ghar ki chabi (password) doormat ke niche (code) chupa dete the, jo koi bhi chor dhoond leta tha. Secrets Management ek digital locker (Vault) hai. Chabi code mein nahi, locker mein hai. Jab app start hota hai, wo identity dikhata hai, locker khulta hai, app ko chabi milti hai, aur kaam ho jata hai.*

---

## Technical Deep Dive

### 1. The Zero-Trust Secret Lifecycle
1. **Never in Code**: Secrets must never touch `git`.
2. **Never in Image**: Secrets must never be baked into a Docker image (`ENV DB_PASS=secret` in a Dockerfile is highly insecure because anyone who pulls the image can run `docker inspect` and see it).
3. **Never in Configs**: Avoid putting plain text secrets in Terraform state or Kubernetes `Secret` YAMLs.
4. **Injection at Runtime**: The app should boot up, authenticate itself to a Secret Store (via IAM role or Service Account), retrieve the secret into memory, and use it.

### 2. HashiCorp Vault Architecture
Vault is the industry gold standard for secrets.
- **Storage Backend**: Where the encrypted data actually lives (Consul, AWS S3, or Raft).
- **Auth Methods**: How clients prove who they are (Token, AWS IAM, Kubernetes ServiceAccount, AppRole).
- **Secrets Engines**:
  - **KV (Key-Value)**: Standard static passwords.
  - **Dynamic Secrets**: Vault connects to PostgreSQL. When an app asks for a password, Vault creates a *brand new* SQL user with a password, gives it to the app, and automatically deletes the SQL user after 1 hour. This is the holy grail of security.

### 3. Kubernetes Integration (External Secrets)
Kubernetes native `Secret` objects are just base64 encoded strings—they are NOT encrypted by default! 
The modern approach is the **External Secrets Operator (ESO)**. ESO runs in K8s, reaches out to AWS Secrets Manager or Vault, fetches the real secret, and injects it into a native K8s Secret just-in-time, allowing K8s to mount it as a file or environment variable for the Pod.

---

## Step-by-Step Lab (HashiCorp Vault Basics)

> [!warning] Pre-requisites
> - Vault CLI installed (`brew tap hashicorp/tap && brew install hashicorp/tap/vault`)

### Step 1: Start Vault in Dev Mode
Dev mode runs entirely in memory and auto-unseals for learning purposes.
```bash
# Start server in background
vault server -dev &

# Expected output will show the Root Token and the Vault address.
# Export the environment variables shown in the output:
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='hvs.xxxxxxxxxxxxxxxxxxxx'
```

### Step 2: Store and Retrieve a Static Secret
```bash
# Store a key-value secret (KV-v2 is enabled by default at 'secret/')
vault kv put secret/my-database username="admin" password="SuperSecretPassword123"

# Expected output: Success! Data written to: secret/my-database

# Retrieve the secret
vault kv get secret/my-database

# View just the password field (useful for scripting)
vault kv get -field=password secret/my-database
# Output: SuperSecretPassword123
```

### Step 3: Setup AppRole Authentication (For Machines/CI)
Humans use tokens or OIDC; machines (like Jenkins or backend apps) use AppRole (similar to a Client ID and Secret).
```bash
# Enable the AppRole auth method
vault auth enable approle

# Create a strict policy allowing read-only access to our specific secret
cat <<EOF > app-policy.hcl
path "secret/data/my-database" {
  capabilities = ["read"]
}
EOF
vault policy write myapp-readonly app-policy.hcl

# Create a role linking to the policy
vault write auth/approle/role/myapp policies="myapp-readonly"

# Fetch the Role ID (Client ID)
vault read auth/approle/role/myapp/role-id

# Fetch a Secret ID (Client Secret)
vault write -f auth/approle/role/myapp/secret-id
```

### Step 4: Authenticate as the App
Now, simulate being the application booting up.
```bash
# Login using the Role ID and Secret ID obtained in Step 3
vault write auth/approle/login role_id="<YOUR_ROLE_ID>" secret_id="<YOUR_SECRET_ID>"

# Expected output: A new temporary Vault Token is generated.
# The app uses this token to fetch the secret!
```

> [!tip] Pro Tip
> In production Vault environments, the Vault starts in a "Sealed" state. It cannot read its own storage until humans provide "Unseal Keys" (using Shamir's Secret Sharing algorithm). This ensures that even if someone physically steals the hard drive containing the Vault storage, they cannot read the secrets without the cooperation of multiple trusted security officers.

---

## Common Commands Cheat Sheet

| Command / Tool | What It Does | Real Example |
|----------------|-------------|--------------|
| `vault status` | Checks if Vault is sealed or unsealed | `vault status` |
| `vault kv put` | Writes a static secret | `vault kv put secret/api-key key=123` |
| `vault kv get` | Reads a static secret | `vault kv get secret/api-key` |
| `vault operator init`| Initializes a brand new Vault cluster | `vault operator init` |
| `vault operator unseal`| Provides 1 part of the unseal key | `vault operator unseal` |
| `vault policy write` | Uploads an ACL policy to Vault | `vault policy write read-only pol.hcl` |
| `aws secretsmanager get-secret-value` | Fetches secret from AWS | `aws secretsmanager get-secret-value --secret-id my-db` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| `Error response from server: sealed` | Vault is locked | Vault restarted and is protecting its data. 3 out of 5 key holders must run `vault operator unseal` and provide their portion of the master key. (Or configure AWS KMS Auto-unseal). |
| `permission denied` when app tries to read secret | Policy mismatch | The policy attached to the AppRole/Token doesn't have the `read` capability for the exact path. Note: in KV-v2, the API path requires `/data/`, so `secret/my-app` becomes `secret/data/my-app` in the policy! |
| K8s External Secret shows `SecretSyncedError` | Provider Auth Failure | The External Secrets Operator in K8s does not have the correct AWS IAM Role (via IRSA) to talk to AWS Secrets Manager. Check OIDC/Trust relationships. |
| Developer accidentally commits AWS key to GitHub | The key is burned | DO NOT try to hide it by force-pushing. Bots scrape GitHub in milliseconds. Go to AWS IAM, delete the compromised Access Key immediately, then generate a new one and rotate it. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A massive breach hits the news. Hackers got access to a company's production database because a disgruntled ex-employee still had the database password saved on their laptop."

**What Junior DevOps Does:**
Changes the database password manually, updates the Kubernetes YAML files, and restarts all the pods. Hopes they didn't forget to update any legacy apps that might crash with the new password.

**Escalation Trigger:**
Static, shared passwords are a ticking time bomb. Every time a developer leaves the company, rotating shared passwords causes immense friction and downtime.

**Senior Engineer Resolution:**
1. Implements **HashiCorp Vault Dynamic Secrets**.
2. Configures Vault to talk to the PostgreSQL database with administrative rights.
3. Configures the microservices to never use static passwords. When an app boots, it asks Vault for database access.
4. Vault dynamically generates a brand new Postgres user (e.g., `v-myapp-8f92a`) with a random 32-character password.
5. Vault attaches a Time-To-Live (TTL) of 1 hour to this user.
6. The app uses it to connect. After 1 hour, Vault automatically drops the user from the database. The app must fetch a new one.
7. Now, even if an employee steals the password, it is completely useless 60 minutes later. The ex-employee threat is mathematically eliminated.

**Lesson Learned:**
The only truly secure secret is one that doesn't exist yet, and one that expires quickly. Dynamic secrets neutralize credential theft.

---

## Interview Questions

**Q1 (Conceptual):** Why is storing secrets in Kubernetes `Secret` objects considered insecure out-of-the-box?
**A:** Native Kubernetes `Secret` objects are not encrypted; they are only `base64` encoded. Base64 is an encoding format, not encryption, and can be instantly decoded by anyone. Anyone with `get secrets` RBAC permissions, or access to the underlying `etcd` datastore, can read the passwords in plain text. (To fix this, you must explicitly enable KMS Encryption at Rest for `etcd` in the cluster configuration).

**Q2 (Practical):** Your CI/CD pipeline needs to push a Docker image to Docker Hub. How do you pass the Docker Hub password to the pipeline without hardcoding it in the YAML?
**A:** I would store the password securely in the CI provider's secrets manager (e.g., GitHub Actions Secrets or GitLab CI/CD Variables). In the pipeline YAML file, I reference it using a variable syntax, such as `${{ secrets.DOCKER_PASSWORD }}`. The CI runner will inject it dynamically at runtime and mask it (replace it with `***`) in the pipeline logs so it never leaks.

**Q3 (Scenario-based):** You notice a developer has added `ENV DB_PASSWORD=my_secret_password` into a Dockerfile. Why is this bad, and how should it be done instead?
**A:** It is bad because the `ENV` instruction bakes the plain-text password into the Docker image layers. Anyone who pulls the image can run `docker history` or `docker inspect` to see the password. Instead, the Dockerfile should have no secrets. The password should be passed at runtime (e.g., via Kubernetes Secrets mounted as environment variables, or `docker run -e DB_PASSWORD=...`).

**Q4 (Deep dive):** Explain how "Auto-Unseal" works in HashiCorp Vault.
**A:** Normally, Vault uses Shamir's Secret Sharing, requiring humans to manually input 3 out of 5 keys to decrypt the master key when Vault restarts. This is terrible for automated scaling. Auto-Unseal delegates this to a trusted Cloud Key Management Service (like AWS KMS). When Vault boots, it reaches out to AWS KMS using an IAM role, asks KMS to decrypt the master key, and unseals itself automatically without human intervention.

**Q5 (Trick/Gotcha):** If you use a `.env` file to manage secrets locally, is it safe to commit this file to a private Git repository?
**A:** No, it is never safe. Private repositories are regularly cloned to developers' local laptops, backup servers, and CI/CD caches. If the private repo is ever compromised, accidentally made public, or accessed by a rogue employee, all secrets are exposed. `.env` files must strictly be added to `.gitignore`.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[09-Security-DevSecOps/SEC-01 DevSecOps Fundamentals|DevSecOps Foundations]]
[[04-Orchestration/K8S-03 ConfigMaps and Secrets|Kubernetes ConfigMaps and Secrets]]
