---
tags: [devops, security, vault, secrets-management, pki]
aliases: [Vault Advanced]
created: 2025-06-27
status: #complete
difficulty: #advanced
cert-relevant: #none
---

# Vault Advanced - PKI and Dynamic Secrets

> [!abstract] Overview
> While basic HashiCorp Vault usage involves storing static Key-Value secrets, its true power lies in advanced Secrets Engines. This note explores Dynamic Secrets (generating temporary, unique DB credentials on the fly) and the PKI (Public Key Infrastructure) engine (automating internal TLS certificate issuance), turning Vault into a dynamic security backend rather than just an encrypted hard drive.

## Concept Overview (What/Why/Where/Responsibility Split)

**What is it?**
*   **Dynamic Secrets:** Instead of sharing one `db_admin` password, Vault dynamically creates a unique database user and password valid for only 1 hour whenever an app requests it. When the hour is up, Vault automatically deletes the user from the database.
*   **PKI Engine:** Vault acts as your internal Certificate Authority (CA). It can generate X.509 certificates for your web servers instantly.

*Hindi Explanation:*
*Normal secret management locker jaisa hai – aapne ek password rakha, aur jo chahe nikal le. 'Dynamic Secrets' ek smart guard jaisa hai. Jab koi app aati hai database ka access mangne, guard usey ek naya, temporary ID card (credentials) bana kar deta hai jo sirf 1 ghante chalega. 1 ghante baad card expire, hack hone ka dar khatam! Aur PKI engine khud ka 'LetsEncrypt' hai internal servers ke liye, jo HTTPS certs auto-generate karta hai.*

**Why use it?**
*   **Zero Trust Security:** Eradicates the problem of leaked, long-lived credentials. If a dynamic secret is leaked, it expires shortly anyway.
*   **Revocation:** Vault knows exactly who has what credential. You can revoke access instantly.
*   **Automation:** Replaces manual ticket-based systems for requesting DB access or SSL certs.

**Where is it used?**
Enterprise environments with strict compliance requirements (PCI-DSS, HIPAA), microservices needing automatic TLS (mTLS), and CI/CD pipelines needing temporary cloud access.

**Responsibility Split**
*   **Security/DevOps Team:** Configures the Vault engines, roles, policies, and connects Vault to the target Database/Cloud provider.
*   **Applications:** Authenticate to Vault (e.g., via AppRole or K8s Service Account) to request the dynamic secret or certificate.

## Technical Deep Dive

### 1. Database Secrets Engine (Dynamic Credentials)
To configure this, Vault needs high-privileged access to the target database (e.g., MySQL, Postgres). 
1.  Vault admin configures a connection to MySQL using a root-like user.
2.  Admin defines a "Role" containing a SQL creation statement (e.g., `CREATE USER '{{name}}' IDENTIFIED BY '{{password}}'; GRANT SELECT ON app_db.* TO '{{name}}';`).
3.  When a client requests credentials for this role, Vault executes the SQL, generates a random username/password, returns it to the client, and starts a TTL timer.
4.  Vault revokes (drops) the user when the TTL expires.

### 2. PKI Secrets Engine
Managing internal TLS certificates is historically painful. Vault PKI engine solves this:
1.  Vault generates a Root CA or Intermediate CA.
2.  Admin defines a Role allowing issuance of certs for a specific domain (e.g., `*.internal.company.com`) with a max TTL of 30 days.
3.  Servers request a certificate. Vault signs and returns the cert and private key immediately.
4.  Because the TTL is short (e.g., 24 hours), tools like **Vault Agent** are used on the servers to automatically request a new cert before the old one expires, ensuring seamless rotation.

### 3. Vault HA Architecture (Integrated Storage / Raft)
In production, Vault must be Highly Available. Previously, Vault required an external backend like Consul to store its encrypted data. Modern Vault uses **Integrated Storage (Raft)**. Data is replicated across 3 or 5 Vault nodes directly. One node is the Active Leader, others are Standby. If the leader fails, a standby takes over instantly.

## Step-by-Step Lab

**Scenario:** Enable the PKI engine, generate an internal Root CA, and issue a certificate for an Nginx web server.

**Step 1: Start Vault Dev Server**
```bash
vault server -dev -dev-root-token-id="root"
# In a new terminal, export the address and token
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'
```

**Step 2: Enable the PKI Secrets Engine**
```bash
vault secrets enable pki
# Set max lease time to 1 year
vault secrets tune -max-lease-ttl=8760h pki
```

**Step 3: Generate the Root CA**
```bash
vault write -field=certificate pki/root/generate/internal \
     common_name="example.com" \
     ttl=8760h > CA_cert.crt
# Output: CA certificate is saved to CA_cert.crt
```

**Step 4: Configure the CA and CRL URLs**
```bash
vault write pki/config/urls \
     issuing_certificates="$VAULT_ADDR/v1/pki/ca" \
     crl_distribution_points="$VAULT_ADDR/v1/pki/crl"
```

**Step 5: Create a Role for generating Certs**
We create a role `example-dot-com` that allows issuing certs for the `example.com` domain.
```bash
vault write pki/roles/example-dot-com \
     allowed_domains="example.com" \
     allow_subdomains=true \
     max_ttl="72h"
```

**Step 6: Request a Certificate (The Application's Job)**
```bash
vault write -format=json pki/issue/example-dot-com \
     common_name="test.example.com" > cert_data.json
     
# You can parse this JSON to extract the certificate and private_key
cat cert_data.json | jq -r '.data.certificate' > test.crt
cat cert_data.json | jq -r '.data.private_key' > test.key

# View the generated cert details
openssl x509 -in test.crt -text -noout | grep "Subject: CN"
# Output: Subject: CN = test.example.com
```

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
| :--- | :--- | :--- |
| `vault secrets enable` | Mounts a new secrets engine | `vault secrets enable database` |
| `vault secrets list` | Lists all enabled secrets engines | `vault secrets list` |
| `vault read` | Reads data or requests dynamic secrets | `vault read database/creds/my-role` |
| `vault write` | Writes config or requests action (like PKI) | `vault write pki/issue/web-role common_name=x.com` |
| `vault lease list` | Lists active dynamic secret leases | `vault lease list database/creds/my-role` |
| `vault lease revoke` | Manually kills a dynamic secret immediately | `vault lease revoke database/creds/my-role/abcd...` |
| `vault token create` | Generates a new auth token | `vault token create -policy=web-policy` |
| `vault status` | Checks HA status and unseal status | `vault status` |

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
| :--- | :--- | :--- |
| Dynamic DB secret request fails | Vault lacks DB privileges | 1. Verify the root DB connection config in Vault.<br>2. Ensure the DB user Vault uses has `CREATE USER` and `GRANT` privileges. |
| PKI issues certs but browsers reject them | Root CA not trusted | 1. Vault's internal CA is not public.<br>2. You must distribute and install `CA_cert.crt` into your OS/Browser's Trusted Root store. |
| `vault is sealed` error | Vault restarted and needs unsealing | 1. Vault encrypts data at rest. On restart, it must be unsealed.<br>2. Run `vault operator unseal` and provide the unseal keys (3 times usually). |
| Dynamic credentials expiring too fast | Role TTL is too short | 1. Check role config: `vault read database/roles/my-role`.<br>2. Update `default_ttl` or use Vault Agent to auto-renew the lease. |
| Application fails to read secrets | Missing Policy | 1. Ensure the token/AppRole assigned to the app has a policy attached that grants `read` capability to the specific path. |

## Real-World Job Scenario

**Scenario:** Developers frequently ask DBAs for read-only credentials to the production PostgreSQL database to debug issues. The DBA creates manual users (`dev_john`, `dev_sarah`) and often forgets to delete them. Passwords are shared in Slack.

*   **Junior Engineer's Action:** Creates a script to parse Slack for passwords and tells people off. Writes a cron job to delete DB users older than 30 days. It's a band-aid solution that breaks often.
*   **Senior Engineer's Action:** Configures Vault's Database Secrets Engine. Creates a `read-only-prod-db` role. When developers need access, they authenticate to Vault via OIDC (Okta/GitHub), and request a credential. Vault creates a unique user (e.g., `v-root-read-onl-xyz`) in Postgres, gives the password to the developer, and automatically drops the user after 2 hours. Zero manual DBA work, zero orphaned accounts, complete audit trail.

## Interview Questions

1.  **Q: What is a Dynamic Secret in Vault?**
    *   **A:** Unlike static KV secrets, a dynamic secret is generated on-demand. When requested, Vault connects to the target system (like AWS or MySQL), creates a new credential with strict permissions, assigns it a TTL (Time To Live), and automatically revokes/deletes it when the TTL expires.
2.  **Q: Why use Vault for PKI instead of traditional Certificate Authorities?**
    *   **A:** Traditional CAs often involve manual ticket requests and manual installation of long-lived certs (1-2 years). Vault automates this via API, issuing short-lived certs (e.g., 24 hours), which drastically reduces the attack surface if a key is compromised.
3.  **Q: How do you handle applications that cannot call the Vault API to renew their dynamic secrets or certificates?**
    *   **A:** You use **Vault Agent**. It runs as a sidecar or daemon alongside the application. Vault Agent handles the authentication, retrieves the secrets/certs, writes them to a local file, and automatically handles renewal (re-fetching before TTL expires).
4.  **Q: What happens to dynamic secrets if the Vault server goes down?**
    *   **A:** The credentials themselves exist on the target system (e.g., the DB user is in MySQL) and will continue to work. Once Vault comes back up, it checks its lease registry. If any leases expired while it was down, it immediately revokes them.
5.  **Q: Explain Vault Auto-Unseal.**
    *   **A:** When Vault starts, it is sealed (cannot decrypt its storage). Manually unsealing requires human operators to enter key shards (Shamir's Secret Sharing). Auto-unseal uses a trusted external system (like AWS KMS or Azure Key Vault) to store the master key, allowing Vault to automatically decrypt its storage and start up without human intervention.

## Related Notes
- [[Master Index]]
- [[DEVSECOPS-02 Secrets Management]]
- [[DB-01 Database Administration Basics]]
