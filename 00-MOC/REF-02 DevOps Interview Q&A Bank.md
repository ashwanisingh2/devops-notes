---
tags: [devops, interview, reference, careers]
aliases: [Interview Q&A Bank]
created: 2025-06-27
status: #complete
difficulty: #all-levels
cert-relevant: #all
---

# REF-02 DevOps Interview Q&A Bank

> [!abstract] Overview
> The DevOps interview process is notoriously difficult because it spans multiple distinct disciplines: Systems Administration, Networking, Software Engineering, and Operations. This document contains 90 carefully curated interview questions ranging from conceptual basics to advanced troubleshooting scenarios, categorized by domain.

---

## Linux & Shell Scripting (10)

**Q1 (Conceptual):** What is the difference between hard links and soft (symbolic) links?
**A:** A hard link points directly to the underlying inode on the disk; if you delete the original file, the hard link still works because the data exists until all hard links are deleted. A soft link points to the filename/path; if you delete the original file, the soft link becomes a "dangling" broken link. Hard links cannot span across different filesystems, whereas soft links can.

**Q2 (Practical):** How do you find all files larger than 1GB in `/var/log` and delete them?
**A:** I would use the `find` command combined with `xargs` or `-exec`. The command is: `find /var/log -type f -size +1G -exec rm -f {} +`. It searches specifically for files (`-type f`), larger than 1 Gigabyte (`-size +1G`), and executes the remove command efficiently.

**Q3 (Troubleshooting):** You try to write to a file, but the system says "No space left on device". You run `df -h` and see that `/` has 50% free space. What is the issue?
**A:** The filesystem has run out of inodes. Even though there is physical disk space available, every file requires one inode to store metadata. If an application generated millions of tiny 1-byte files, all inodes are consumed, preventing new files from being created. I would use `df -i` to verify this.

**Q4 (Scenario-based):** **Situation:** A background script crashed, but you don't know why. **Task:** Find the exit code of the last command. **Action:** In Bash, I use the special variable `$?`. **Result:** Running `echo $?` immediately after the command executes will print the exit code (0 for success, non-zero for failure), allowing me to debug the crash.

**Q5 (Deep dive):** Explain what the `umask` value `022` means.
**A:** `umask` dictates the default permissions applied when a new file or directory is created. It is subtracted from the system maximums (666 for files, 777 for directories). So, a `umask` of `022` means new files will have `666 - 022 = 644` (rw-r--r--) permissions, and new directories will have `777 - 022 = 755` (rwxr-xr-x) permissions.

**Q6 (Practical):** How do you safely stop a running process in Linux?
**A:** First, I find the Process ID (PID) using `ps aux | grep process_name`. Then, I use `kill -15 <PID>` (SIGTERM) to ask the process to terminate gracefully, allowing it to close files and save state. I only use `kill -9 <PID>` (SIGKILL) as an absolute last resort, because it forces the kernel to terminate the process instantly, potentially causing data corruption.

**Q7 (Conceptual):** What is the purpose of the `/etc/fstab` file?
**A:** The File System Table (`fstab`) is a configuration file that tells the Linux kernel how and where to mount disk drives and partitions. During boot, the system reads this file to automatically mount attached EBS volumes or NFS shares. If you configure a drive manually via the `mount` command, it will not survive a reboot unless added to `/etc/fstab`.

**Q8 (Scenario-based):** **Situation:** A developer's script is failing because of a syntax error inside a massive 10GB log file. **Task:** They need the first 20 lines of the file to debug it. **Action:** I use `head -n 20 error.log`. **Result:** Unlike opening the file in `vim` (which would crash trying to load 10GB into RAM), `head` reads exactly 20 lines and exits instantly, saving memory.

**Q9 (Deep dive):** What is the difference between `chmod` and `chown`?
**A:** `chmod` (Change Mode) modifies the read, write, and execute permissions of a file for the owner, group, and others (e.g., `chmod 755 file.sh`). `chown` (Change Owner) changes who actually owns the file and which group it belongs to (e.g., `chown nginx:nginx /var/www`).

**Q10 (Practical):** Write a bash `if` statement to check if a directory `/data` exists.
**A:** I would write:
```bash
if [ -d "/data" ]; then
  echo "Directory exists."
else
  echo "Directory missing."
fi
```

---

## Docker & Containers (10)

**Q11 (Conceptual):** What is the difference between a Virtual Machine and a Container?
**A:** A VM includes a full guest Operating System (Windows/Linux) running on top of a Hypervisor, making it heavy (GBs) and slow to boot. A container shares the host machine's OS kernel and only includes the application and its binaries/libraries, making it lightweight (MBs), incredibly fast to start, and highly portable.

**Q12 (Practical):** How do you reduce the size of a Docker image?
**A:** First, use a minimal base image like `alpine` or `distroless`. Second, use Multi-Stage Builds to compile the code in a heavy "build" stage, but only copy the compiled binary into the final, lightweight "runtime" stage. Third, chain `RUN` commands with `&&` to minimize the number of intermediate layers created, and clean up package caches (e.g., `apt-get clean`) in the same layer.

**Q13 (Troubleshooting):** You run a container and it exits immediately with code 0. Why?
**A:** Containers only stay alive as long as their primary foreground process (PID 1) is running. If you start a container to run a background service (like `/etc/init.d/nginx start`) or a script that finishes its task, PID 1 completes, and Docker shuts down the container. You must run the process in the foreground (e.g., `nginx -g 'daemon off;'`).

**Q14 (Scenario-based):** **Situation:** Two containers need to communicate securely without exposing ports to the host network. **Task:** Isolate their traffic. **Action:** I create a custom bridge network (`docker network create backend-net`) and run both containers attached to it. **Result:** They can resolve each other via DNS using their container names, but they are isolated from the host and other containers.

**Q15 (Deep dive):** What is the difference between `CMD` and `ENTRYPOINT` in a Dockerfile?
**A:** `ENTRYPOINT` defines the executable that will *always* run when the container starts, and it is very hard to override from the CLI. `CMD` provides the default arguments passed to that `ENTRYPOINT`. If you run `docker run myimage bash`, it overrides the `CMD`, but the `ENTRYPOINT` still executes first. 

**Q16 (Practical):** How do you persist data in a Docker container?
**A:** Data inside a container's writable layer is lost when the container is deleted. To persist data, I use Volumes. I prefer **Named Volumes** (`docker volume create my-vol`, then mount with `-v my-vol:/data`) because Docker manages them securely, or **Bind Mounts** to link a specific host directory directly to the container.

**Q17 (Conceptual):** What is a `.dockerignore` file and why is it important?
**A:** It is exactly like a `.gitignore` file, but for the Docker build context. When you run `docker build .`, the Docker CLI sends the entire current directory to the Docker daemon. If you don't ignore files like `node_modules` or `.git`, the build context becomes massive, significantly slowing down the build and risking secret leakage.

**Q18 (Troubleshooting):** You try to bind to port 80 inside a container, but it fails with "Permission Denied".
**A:** Linux restricts binding to privileged ports (ports below 1024) to the `root` user. Since best security practices dictate running containers as a non-root user (`USER 1000` in the Dockerfile), the process cannot bind to port 80. The fix is to configure the application to listen on an unprivileged port (like 8080) and map it via Docker (`-p 80:8080`).

**Q19 (Deep dive):** Explain Docker namespaces and cgroups.
**A:** These are the two fundamental Linux kernel features that make containers possible. **Namespaces** provide isolation (they ensure that Container A cannot see Container B's processes, networks, or mount points). **Cgroups (Control Groups)** provide resource limitation (they ensure Container A cannot consume more than 2GB of RAM or 1 CPU core, preventing the "noisy neighbor" problem).

**Q20 (Scenario-based):** **Situation:** You need to debug a running Nginx container that has no shell (like Alpine or Distroless). **Task:** Inspect its internal files. **Action:** Since `docker exec -it web sh` fails, I use `docker cp` to copy the config file out of the container to my host, read it locally, or use a sidecar container attached to the same network/volumes for debugging. **Result:** I debug the issue without compromising the secure base image.

---

## Kubernetes (15)

**Q21 (Conceptual):** What is the role of `etcd` in the Kubernetes Control Plane?
**A:** `etcd` is a highly available, distributed key-value store that acts as the cluster's brain. It stores the absolute "desired state" and current state of the entire cluster. All K8s components read from and write to the API server, which is the only component allowed to talk directly to `etcd`. If `etcd` is lost and unbacked up, the entire cluster is effectively destroyed.

**Q22 (Practical):** How do you gracefully drain a node for maintenance?
**A:** I run `kubectl cordon <node-name>` to mark it unschedulable (preventing new pods from landing there). Then, I run `kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data`. This safely evicts all running pods, allowing the ReplicaSets to recreate them on other healthy nodes before I shut down the node.

**Q23 (Troubleshooting):** A Pod is stuck in `CrashLoopBackOff`. How do you debug it?
**A:** `CrashLoopBackOff` means the container starts, but the application immediately crashes, and K8s keeps trying to restart it. I would run `kubectl describe pod <pod-name>` to check the Events for Liveness probe failures or OOMKilled errors. Then, I would run `kubectl logs <pod-name> --previous` to see the actual application stack trace from the last crashed instance.

**Q24 (Scenario-based / CKA):** **Situation:** You deleted a Deployment, but the pods are immediately being recreated. **Task:** Stop the pods from returning. **Action:** The issue is that I deleted the Pods manually instead of the Deployment, or there is a higher-level controller (like a Helm release or ArgoCD Application) that is detecting the deletion as "drift" and forcing a sync. **Result:** I must delete the root controller (e.g., `kubectl delete deployment myapp`), which cascades the deletion down to the ReplicaSets and Pods.

**Q25 (Deep dive):** Explain the difference between Liveness, Readiness, and Startup probes.
**A:** **Liveness** checks if the app is dead (e.g., deadlocked); if it fails, K8s restarts the pod. **Readiness** checks if the app is ready to accept traffic; if it fails, K8s temporarily removes the pod's IP from the Service load balancer (no restart). **Startup** is used for legacy apps that take 2 minutes to boot; it disables the other two probes until it passes, preventing K8s from infinitely killing slow-booting apps.

**Q26 (Conceptual):** What is a Headless Service and when do you use it?
**A:** A Headless Service is created by setting `clusterIP: None`. Instead of load balancing traffic to a single virtual IP, DNS resolves the Service name directly to the individual Pod IPs. It is primarily used with **StatefulSets** (like Cassandra or MongoDB) where the client application needs to talk directly to a specific primary or replica pod, not a random load balancer.

**Q27 (Practical):** How do you inject a password securely into a Pod?
**A:** I create a Kubernetes `Secret` object holding the base64-encoded password. In the Pod's YAML `spec`, I mount this Secret either as an Environment Variable (`valueFrom: secretKeyRef`) or mount it as a physical file inside a Volume (`secret: secretName`). I ensure RBAC prevents unauthorized users from reading the Secret object.

**Q28 (Troubleshooting):** Your Pod is stuck in `Pending` state permanently. Why?
**A:** `Pending` means the K8s Scheduler cannot find a suitable Node to place the pod. Common causes include: lack of CPU/Memory resources on the cluster, No taints/tolerations match (the pod isn't allowed to schedule on available nodes), or a requested PersistentVolumeClaim (PVC) cannot be bound or provisioned.

**Q29 (Scenario-based / CKA):** **Situation:** You have a web app deployment running 3 replicas. Traffic spikes and you need 10 replicas immediately. **Task:** Scale the deployment declaratively. **Action:** I run `kubectl scale deployment webapp --replicas=10`. Later, I update the actual Git repository YAML to `replicas: 10` so the change is persisted and recorded in version control. **Result:** The ReplicaSet provisions 7 new pods instantly.

**Q30 (Deep dive):** What is the difference between a DaemonSet and a Deployment?
**A:** A Deployment ensures a specific number of replicas (e.g., 5 pods) are running, spread randomly across the cluster based on resource availability. A DaemonSet ensures that exactly ONE copy of a pod runs on *every single node* in the cluster. DaemonSets are used for node-level agents, such as Fluentd (for log collection) or Calico (for networking).

**Q31 (Conceptual):** What is an Ingress Controller?
**A:** An Ingress Controller is a specialized reverse proxy (like Nginx, Traefik, or HAProxy) running inside the cluster. It reads Kubernetes `Ingress` objects to generate its routing rules. It acts as the single entry point (LoadBalancer) for external traffic, providing path-based routing (e.g., `/api` goes to API pod, `/web` goes to UI pod) and TLS termination.

**Q32 (Practical):** Write the `kubectl` command to expose a deployment on port 8080 internally.
**A:** `kubectl expose deployment my-api --port=8080 --target-port=8080 --type=ClusterIP`

**Q33 (Troubleshooting):** You deployed an app, but accessing the Service IP returns a "Connection Refused".
**A:** The Service might not be mapping to the Pods correctly. First, I check `kubectl get endpoints my-service`. If the endpoints list is empty, it means the `selector` labels in the Service YAML (e.g., `app: myapp`) do not exactly match the `labels` on the Pod. K8s relies strictly on label matching to connect Services to Pods.

**Q34 (Scenario-based / CKA):** **Situation:** An attacker compromised a pod and is trying to access the AWS API. **Task:** Revoke its permissions. **Action:** By default, every pod mounts a default ServiceAccount token. I edit the Pod or Deployment spec and add `automountServiceAccountToken: false`. **Result:** The compromised pod can no longer authenticate to the K8s API server, cutting off internal privilege escalation.

**Q35 (Deep dive):** Explain how `PersistentVolumes` (PV) and `PersistentVolumeClaims` (PVC) work.
**A:** A **PV** is a piece of storage provisioned by the administrator (e.g., an AWS EBS volume of 100GB). A **PVC** is a request for storage made by a developer (e.g., "I need 10GB"). K8s automatically binds the PVC to a suitable PV based on size and access modes. The Pod then mounts the PVC, decoupling the pod specification from the underlying storage infrastructure details.

---

## CI/CD (10)

**Q36 (Conceptual):** What is the difference between Continuous Delivery and Continuous Deployment?
**A:** Both automate the pipeline up to the staging environment. In Continuous **Delivery**, deploying to Production requires a human to manually click an "Approve/Deploy" button. In Continuous **Deployment**, there are no human gates; if the code passes all automated tests in the CI pipeline, it is automatically deployed straight to Production.

**Q37 (Practical):** How do you pass an artifact (like a compiled `.jar` file) from a Build job to a Deploy job in a CI pipeline?
**A:** In most CI tools (GitLab, GitHub Actions, Jenkins), jobs run in isolated runners/containers. I must explicitly define the file as an "Artifact" in the Build job, which uploads it to the CI server's storage. The Deploy job then downloads that Artifact at the start of its run to use it.

**Q38 (Troubleshooting):** Your Jenkins pipeline is failing because it says "Docker command not found" when trying to build an image.
**A:** The pipeline is likely running on a Jenkins agent node that does not have Docker installed, or the Jenkins user does not have permissions to run Docker. I would ensure the pipeline is pinned to a specific agent label (e.g., `agent { label 'docker-node' }`) or configure the Jenkins controller to spin up Docker-in-Docker containers for builds.

**Q39 (Scenario-based):** **Situation:** Developers are complaining that the CI pipeline takes 45 minutes to run, ruining productivity. **Task:** Optimize it. **Action:** I analyze the pipeline and find that `npm install` takes 20 minutes, and unit tests run sequentially. I implement dependency **Caching** (so `node_modules` is reused between runs) and use a **Matrix strategy** to split the tests into 5 parallel jobs. **Result:** Pipeline execution drops to 10 minutes.

**Q40 (Deep dive):** What is a Blue-Green deployment strategy?
**A:** You maintain two identical production environments (Blue and Green). Blue is currently serving live customer traffic. You deploy the new version of the code to the idle Green environment. You run tests on Green safely. Once verified, you flip the load balancer switch, instantly routing all customer traffic from Blue to Green. If a bug is found, you flip the switch back for a 1-second rollback.

**Q41 (Conceptual):** What is GitOps, and how does it differ from traditional CI/CD?
**A:** GitOps (using tools like ArgoCD) separates CI from CD. Traditional CI/CD uses a "Push" model, where Jenkins pushes YAML to the cluster. GitOps uses a "Pull" model. Jenkins only builds the image and updates the Git repository. ArgoCD, running *inside* the cluster, constantly polls Git. When it sees a change, it pulls the new desired state and reconciles the cluster automatically.

**Q42 (Practical):** How do you trigger a GitHub Actions workflow manually?
**A:** In the workflow YAML file, under the `on:` section, I add the `workflow_dispatch:` event trigger. This adds a "Run workflow" button in the Actions tab on the GitHub UI, allowing developers to manually execute the pipeline and pass optional input parameters.

**Q43 (Troubleshooting):** A deployment to production failed, but the deployment script returned `exit 0`, causing the CI pipeline to falsely report "Success" (Green).
**A:** The deployment script likely suppressed the error or used a pipe `|` where only the last command's exit code was evaluated. In bash scripts used in CI, always include `set -e` at the top to ensure the script immediately exits with a failure code if any single command fails. Also, set `set -o pipefail`.

**Q44 (Scenario-based):** **Situation:** You need to deploy a risky new feature, but want to test it on real users safely. **Task:** Implement a safe release strategy. **Action:** I use a **Canary Deployment**. I route 95% of traffic to the stable version, and 5% of traffic to the new "canary" version. **Result:** We monitor the error logs of the 5%. If it crashes, only 5% of users are impacted, and we rollback. If stable, we slowly scale to 100%.

**Q45 (Deep dive):** Explain what Trunk-Based Development is.
**A:** It is a branching model where all developers merge their code directly into a central `main` branch multiple times a day, entirely avoiding long-lived feature branches. This requires heavy reliance on automated testing and Feature Flags (so unfinished code can be hidden in production). It drastically reduces painful merge conflicts and is a core prerequisite for true Continuous Integration.

---

## Terraform & IaC (10)

**Q46 (Conceptual):** What is Terraform State and why is it dangerous to commit it to Git?
**A:** The state file (`terraform.tfstate`) is a JSON mapping of your HCL code to real-world cloud resources. It is highly sensitive because it stores all resource attributes—including database passwords, private keys, and API tokens—in plain text. Committing it to Git exposes all your infrastructure secrets. It must be stored in a secure Remote Backend (like S3).

**Q47 (Practical):** How do you lock a specific version of the AWS provider in Terraform?
**A:** Inside the `terraform {}` block, under `required_providers`, I define the `aws` provider and use the `version` constraint. For example, `version = "~> 5.0"` ensures Terraform only downloads 5.x versions and avoids breaking changes introduced in major version 6.0.

**Q48 (Troubleshooting):** You run `terraform plan` and it wants to destroy your production database and recreate it, even though you just changed a tag.
**A:** You modified an immutable property of the database (or the provider has a bug). Terraform detects that the only way to apply the new configuration is to destroy the old resource entirely and build a new one. **Do not apply.** Revert the HCL change, use the `lifecycle { prevent_destroy = true }` block on critical resources to prevent this exact mistake.

**Q49 (Scenario-based):** **Situation:** A Junior dev accidentally deleted a crucial S3 bucket using the AWS Console instead of Terraform. **Task:** Fix the Terraform state. **Action:** I run `terraform plan`. **Result:** Terraform compares its state to reality, notices the bucket is missing, and offers a plan to seamlessly recreate it based on the existing HCL code. I just run `terraform apply`.

**Q50 (Deep dive):** How does State Locking work in Terraform, and why is DynamoDB used for AWS backends?
**A:** State locking prevents two engineers (or two CI pipelines) from running `terraform apply` at the exact same millisecond, which would corrupt the state file. When using AWS S3 for remote state, S3 natively lacks atomic locking features. Therefore, Terraform integrates with a DynamoDB table, creating a "LockID" record when an apply starts, and deleting it when finished, ensuring safe concurrency.

**Q51 (Conceptual):** What is the difference between a `resource` and a `data` block?
**A:** A `resource` block instructs Terraform to CREATE and manage a new piece of infrastructure (e.g., `resource "aws_instance"`). A `data` block instructs Terraform to READ information about infrastructure that already exists (perhaps created manually or by another team), so you can use its attributes (e.g., `data "aws_vpc"` to find the VPC ID).

**Q52 (Practical):** You have a generic VPC module. How do you provision 3 different VPCs for Dev, Staging, and Prod without duplicating the code?
**A:** I write the VPC module once. Then, I create three separate workspace directories (or use Terraform Cloud Workspaces). In each directory, I call the exact same module block, but pass in different variables via a `.tfvars` file (e.g., `cidr_block="10.1.0.0/16"` for Dev, `cidr_block="10.2.0.0/16"` for Prod).

**Q53 (Troubleshooting):** You renamed an EC2 instance resource in your `main.tf` from `aws_instance.old` to `aws_instance.new`. Terraform wants to destroy the server and rebuild it. How do you prevent this?
**A:** I use the `terraform state mv` command. I run `terraform state mv aws_instance.old aws_instance.new`. This surgically updates Terraform's memory (the state file) so it realizes the new code maps to the exact same AWS resource, resulting in a clean `plan` with no destruction.

**Q54 (Scenario-based):** **Situation:** The company acquired a startup that built their AWS infrastructure completely manually. **Task:** Bring it under Terraform control. **Action:** I write the corresponding HCL code in `main.tf` to match the real resources. Then, I use the `terraform import` command (e.g., `terraform import aws_s3_bucket.my_bucket real-bucket-name`). **Result:** Terraform links the real bucket to the code without recreating it.

**Q55 (Deep dive):** Explain what the `terraform taint` command (or the modern `-replace` flag) does.
**A:** If a resource was created successfully by Terraform, but the software configuration failed (e.g., a bad bash script was run during EC2 provisioning), Terraform thinks it's perfectly healthy. By "tainting" the resource, you explicitly tell Terraform that the resource is broken and must be destroyed and recreated on the next `terraform apply`.

---

## Ansible (10)

**Q56 (Conceptual):** What does "Idempotency" mean in Ansible?
**A:** Idempotency is the property that you can run an Ansible playbook 1,000 times, and the system will remain in the exact same desired state. If a package is already installed, Ansible detects it and does nothing (reports `OK`), rather than trying to install it again and causing errors. This allows you to safely run playbooks repeatedly.

**Q57 (Practical):** You need to restart Nginx, but ONLY if the configuration file was modified in a previous task. How do you do this?
**A:** I use Handlers. I define the restart task in the `handlers:` section of the playbook. In the task that copies the config file, I add `notify: Restart Nginx`. The handler will only trigger at the end of the play IF the config copy task reported a status of `changed`.

**Q58 (Troubleshooting):** You run a playbook against 100 servers. It fails immediately with "UNREACHABLE" on 5 of them.
**A:** This is an SSH connectivity issue. I would verify that the 5 servers are powered on, port 22 is open in their firewall, and that my Control Node has the correct private SSH key loaded to authenticate against those specific machines. I can test this using the Ad-Hoc command: `ansible failing_servers -m ping`.

**Q59 (Scenario-based):** **Situation:** You need to pass an API key to your playbook, but you cannot commit it to GitHub. **Task:** Secure the variable. **Action:** I use **Ansible Vault**. I run `ansible-vault encrypt secrets.yml` to encrypt the file containing the API key. **Result:** I commit the encrypted file to Git, and when executing, I pass `--ask-vault-pass` so Ansible decrypts it in memory at runtime.

**Q60 (Deep dive):** What are Ansible Facts?
**A:** Facts are system properties gathered from the target nodes (e.g., OS distribution, IP addresses, CPU cores, available memory). By default, Ansible runs a hidden `setup` module at the start of every play to collect this data and stores it in variables (like `ansible_os_family`). This allows you to write conditional tasks (e.g., "Only run this `yum` task if the OS is RedHat").

**Q61 (Conceptual):** Why is Ansible considered "Agentless"?
**A:** Unlike Puppet or Chef, Ansible does not require you to install any proprietary daemon or background service on the target servers. It operates completely over standard SSH (or WinRM for Windows). The target server only needs Python installed to execute the modules.

**Q62 (Practical):** How do you group servers logically in an Ansible inventory file?
**A:** In an INI-format inventory file, I use brackets to define groups. For example:
```ini
[webservers]
10.0.0.1
10.0.0.2

[dbservers]
10.0.0.3
```
I can then target specific groups in my playbook using `hosts: webservers`.

**Q63 (Troubleshooting):** You use the `shell` module to run `echo "hello" > test.txt`. The playbook reports `changed` every single time it runs, breaking idempotency.
**A:** The `shell` and `command` modules are not natively idempotent; Ansible blindly executes them. To achieve idempotency, I should use native modules like `copy` or `lineinfile`. If I *must* use `shell`, I should add the `creates:` parameter (`creates: test.txt`), which tells Ansible to skip the command if the file already exists.

**Q64 (Scenario-based):** **Situation:** You are writing a playbook, and you find yourself copying and pasting the same 20 tasks to install Node.js across multiple projects. **Task:** Apply DRY principles. **Action:** I refactor the tasks, variables, and templates into an **Ansible Role** using `ansible-galaxy init nodejs-role`. **Result:** I can now just call `role: nodejs-role` in any future playbook with one line of code.

**Q65 (Deep dive):** Explain Variable Precedence in Ansible. What overrides what?
**A:** Ansible has 22 levels of variable precedence. Generally, variables defined in the Inventory are the weakest. Variables defined in the Playbook (`vars:` block) are stronger. Variables passed via the command line (`-e "my_var=1"`) are the absolute strongest and will override almost everything else.

---

## Monitoring & Observability (10)

**Q66 (Conceptual):** What are the "Three Pillars of Observability"?
**A:** 1. **Metrics** (Prometheus): Aggregated numerical data identifying *if* there is a problem (e.g., CPU is at 100%). 2. **Logs** (ELK Stack): Discrete text records identifying *why* the problem occurred (e.g., Java NullPointerException). 3. **Traces** (Jaeger): The context of a single request traversing microservices, identifying *where* the bottleneck is.

**Q67 (Practical):** A developer wants to graph total HTTP requests in Grafana using Prometheus data. They use the query `http_requests_total`. The graph is a useless, ever-climbing mountain. How do you fix it?
**A:** `http_requests_total` is a Counter metric, which only goes up. Graphing raw counters is useless. You must calculate the per-second rate of increase using a time window. I would change the query to `rate(http_requests_total[5m])`, which shows the actual requests-per-second, providing a readable traffic graph.

**Q68 (Troubleshooting):** Kibana is running extremely slowly, and Elasticsearch reports "High Disk Watermark [95%] exceeded".
**A:** When Elasticsearch hits 95% disk usage, it automatically puts all indices into "Read-Only" mode to prevent catastrophic failure, dropping all new logs. I must immediately add more disk space, or delete old indices (`curl -X DELETE localhost:9200/old-logs-2023.01`), and then manually run an API call to remove the read-only block.

**Q69 (Scenario-based):** **Situation:** The team suffers from "Alert Fatigue" because they get 50 PagerDuty emails a day for high CPU usage. **Task:** Fix the alerting culture. **Action:** I delete all alerts based on internal causes (CPU, RAM). I replace them with symptom-based alerts targeting the user experience (e.g., "Alert if API Latency > 2s for 5 mins" or "Alert if 5xx Error Rate > 5%"). **Result:** The team only gets woken up when users are actually impacted.

**Q70 (Deep dive):** Explain the difference between a Push and a Pull model in monitoring.
**A:** In a **Push** model (like Datadog or InfluxDB), the servers actively send their metrics to the central hub. This can overwhelm the hub and requires configuring outbound credentials on every server. In a **Pull** model (like Prometheus), the central server reaches out (scrapes) the targets via HTTP `/metrics` endpoints. This is highly scalable, easier to secure, and allows developers to easily scrape metrics locally on their laptops.

**Q71 (Conceptual):** What is the purpose of Logstash in the ELK stack?
**A:** Logstash is the data processing pipeline. Unstructured logs (like raw Nginx strings) are useless for querying. Logstash ingests the raw string, uses Grok patterns (Regex) to parse it into structured JSON fields (extracting the IP address, HTTP status code, and URL separately), and then outputs that clean JSON into Elasticsearch.

**Q72 (Practical):** How do you calculate the 99th percentile (P99) latency in Prometheus?
**A:** I use a Histogram metric combined with the `histogram_quantile` function. The query looks like: `histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))`. This proves that 99% of all requests are served faster than the resulting number.

**Q73 (Troubleshooting):** You deployed the OpenTelemetry Collector, but traces from the Python app are not appearing in Jaeger.
**A:** Trace context propagation is likely failing. First, check the Python app's stdout to ensure the OTel SDK is initialized. Second, check the OTel Collector logs to ensure it is successfully receiving gRPC traffic on port 4317. Finally, check if network firewalls are blocking the Collector from exporting data to the Jaeger backend port (14250).

**Q74 (Scenario-based):** **Situation:** A massive network switch fails, causing 500 servers to drop offline. **Task:** Prevent 500 separate PagerDuty phone calls from waking the engineer. **Action:** I configure **Alertmanager Grouping**. **Result:** By setting `group_by: ['datacenter']`, Alertmanager queues the alerts for 30 seconds, sees 500 alerts for the same datacenter, and bundles them into a single, comprehensive incident notification.

**Q75 (Deep dive):** What is an Error Budget?
**A:** It is the mathematical allowance for failure. If your Service Level Objective (SLO) is 99.9% uptime per month, your Error Budget is 0.1% (about 43 minutes of allowed downtime). If the budget is exhausted, policy dictates a strict deployment freeze—developers cannot launch new features until the budget recovers, forcing the team to focus entirely on reliability.

---

## DevSecOps (5)

**Q76 (Conceptual):** What is an SBOM and why is it legally mandated in many industries now?
**A:** A Software Bill of Materials (SBOM) is a comprehensive, machine-readable inventory of every third-party open-source library, version, and nested dependency used in your software. It is critical for Supply Chain Security. If a new zero-day vulnerability (like Log4Shell) is announced, you query your SBOMs to instantly locate which microservices are affected, rather than manually searching millions of lines of code.

**Q77 (Practical):** How do you prevent developers from deploying containers running as the root user in Kubernetes?
**A:** I implement an Admission Controller like OPA Gatekeeper or Kyverno. I write a policy that evaluates incoming Pod YAMLs. If the `securityContext.runAsNonRoot` field is missing or set to `false`, the Admission Controller rejects the API request and blocks the deployment before it ever reaches `etcd`.

**Q78 (Troubleshooting):** A DAST scanner running in your CI pipeline takes 4 hours to complete, completely blocking developer velocity. How do you resolve this?
**A:** A full DAST spider crawl is too aggressive for CI. I would modify the CI pipeline to run an "API Baseline Scan" targeting only critical endpoints, which takes 2 minutes. I would then schedule the comprehensive 4-hour DAST scan to run asynchronously every weekend, shifting the heavy security workload out of the immediate developer feedback loop.

**Q79 (Scenario-based):** **Situation:** A developer accidentally pushes a hardcoded AWS Access Key to a public GitHub repository. **Task:** Secure the environment. **Action:** I immediately log into the AWS Console and deactivate/delete that specific IAM key. **Result:** I do NOT start by trying to delete the GitHub commit, because scraping bots steal keys in milliseconds. Revoking the key in AWS neutralizes the threat instantly.

**Q80 (Deep dive):** Explain the difference between SAST and SCA.
**A:** SAST (Static Application Security Testing) analyzes your *custom written source code* for logical vulnerabilities, like SQL injection or cross-site scripting (e.g., SonarQube). SCA (Software Composition Analysis) ignores your custom code and strictly analyzes your `package.json` or `requirements.txt` to find known public vulnerabilities (CVEs) in *third-party open-source libraries* (e.g., Snyk, Trivy).

---

## SRE & Incident Management (5)

**Q81 (Conceptual):** What is the core definition of "Toil" in SRE?
**A:** Toil is manual, repetitive, tactical work that provides no enduring value and scales linearly as the system grows (e.g., manually resetting user passwords or running a database backup script by hand). SREs have a strict mandate to cap toil at 50% of their time, spending the other 50% writing software/automation to eliminate the toil permanently.

**Q82 (Practical):** You are the Incident Commander (IC) during a massive SEV-1 outage. Two engineers are arguing in Slack over what the root cause is. What is your action?
**A:** The IC's job is to impose order and focus on mitigation. I would intervene: "Stop arguing. Alice, spend 5 minutes proving it's the network. Bob, spend 5 minutes proving it's the database. Report back here." The IC does NOT debug the issue themselves; they delegate, time-box investigations, and maintain control.

**Q83 (Troubleshooting):** During a Chaos Engineering GameDay, you kill a primary database pod. The replica takes over successfully, but the web application returns HTTP 500s. Why?
**A:** The web application code lacks resilience. It likely caches the database IP address on startup or lacks a retry mechanism for dropped connections. When the primary DB died, the web app refused to reconnect to the new replica's IP. The fix is implementing a Circuit Breaker pattern and connection pooling retry logic in the application code.

**Q84 (Scenario-based):** **Situation:** An engineer runs a script that accidentally deletes a production table, causing a 2-hour outage. **Task:** Conduct the postmortem. **Action:** I lead a **Blameless Postmortem**. Instead of asking "Why did Bob make a mistake?", we ask "Why did the system allow a human to execute a destructive command in production without an automated safety check?". **Result:** Action items are generated to implement Terraform and revoke manual CLI access to production databases.

**Q85 (Deep dive):** Why is attempting to achieve 100% availability considered an anti-pattern in SRE?
**A:** 100% availability is physically impossible due to factors outside your control (AWS region failures, cosmic rays). More importantly, the cost of going from 99.9% (3 Nines) to 99.999% (5 Nines) is exponentially higher in engineering effort. Aiming for 100% requires freezing all feature deployments, which bankrupts the business by stopping innovation. You should only aim for the reliability level your actual users require.

---

## Behavioral & DevOps Culture (5)

**Q86 (Behavioral):** Tell me about a time you broke production.
**A:** *(STAR Format Example)* **S:** I was a junior engineer updating a routing table. **T:** I needed to add a single IP. **A:** I wrote the command incorrectly, overwrote the entire routing table instead of appending to it, and brought down the API. I immediately declared an incident and rolled back the config. **R:** During the postmortem, I took responsibility. We implemented an automated CI syntax checker (OPA) for all routing changes so nobody could ever make that mistake again.

**Q87 (Behavioral):** How do you handle a developer who refuses to write unit tests, claiming it "slows down their velocity"?
**A:** I would empathize with their desire for speed, but use data to shift their perspective. I would show them metrics indicating that bugs caught in production take 10x longer to fix (and require painful rollback meetings) compared to bugs caught in CI. I would offer to pair-program with them to set up test templates, proving that automated tests actually *increase* deployment velocity by removing the need for manual QA.

**Q88 (Behavioral):** Describe a time you automated a process that saved your team significant time.
**A:** **S:** Our team spent 4 hours every Friday manually generating compliance reports by querying 5 different databases. **T:** It was pure toil. **A:** I wrote a Python script utilizing Pandas that queried the databases, generated a formatted PDF report, and scheduled it in Jenkins to run automatically on Friday mornings. **R:** It saved the team 16 hours a month, allowing us to focus on our Kubernetes migration project.

**Q89 (Behavioral):** What does the term "DevOps" actually mean to you?
**A:** To me, DevOps is not a job title or a toolset like Docker or Jenkins. It is a cultural philosophy of shared responsibility. Historically, Devs threw code over the wall, and Ops suffered the 3 AM pagers. DevOps means breaking down that silo: Devs take responsibility for how their code runs in production (on-call), and Ops uses software engineering practices to automate infrastructure.

**Q90 (Behavioral):** How do you stay updated with the rapidly changing DevOps landscape?
**A:** I focus on understanding foundational concepts (like networking, Linux kernel, and distributed systems architecture) rather than chasing every new tool. A new CI tool is easy to learn if you understand CI principles. I also follow the CNCF (Cloud Native Computing Foundation) landscape, read engineering blogs from companies like Netflix and Cloudflare, and maintain a personal home lab (Raspberry Pi or AWS Free Tier) to test new technologies hands-on.

---

## Related Notes
[[00-MOC/Master-Index|Master Index]]
[[00-MOC/REF-01 DevOps Command Cheat Sheet|Cheat Sheet]]
