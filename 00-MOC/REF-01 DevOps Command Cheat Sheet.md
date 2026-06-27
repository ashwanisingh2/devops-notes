---
tags: [devops, reference, commands, cheatsheet]
aliases: [Mega Cheat Sheet]
created: 2025-06-27
status: #complete
difficulty: #all-levels
cert-relevant: #none
---

# REF-01 DevOps Command Cheat Sheet

> [!abstract] Overview
> A DevOps engineer's terminal is their primary weapon. Memorizing every single command is impossible, but having a centralized, quickly searchable reference is critical for resolving incidents fast. This mega cheat sheet compiles the most essential, real-world commands for Linux, Git, Docker, Kubernetes, Helm, Terraform, Ansible, PromQL, AWS, and Azure. 

---

## 1. Linux DevOps Commands

| Command | Description | Real Example |
|---------|-------------|--------------|
| `htop` | Interactive process viewer (CPU/RAM) | `htop` |
| `ps aux` | List all running processes with details | `ps aux \| grep nginx` |
| `kill -9` | Force kill a process by PID | `kill -9 14532` |
| `df -h` | Disk space usage (human-readable) | `df -h` |
| `du -sh *` | Size of current directory's contents | `du -sh * \| sort -rh` |
| `lsblk` | List block devices (disks/partitions) | `lsblk -f` |
| `free -m` | Show free and used RAM in MB | `free -m` |
| `netstat -tulpn` | List all listening ports and PIDs | `netstat -tulpn \| grep 8080` |
| `ss -tunlp` | Modern, faster netstat equivalent | `ss -tunlp` |
| `curl -I` | Fetch only HTTP headers | `curl -I https://google.com` |
| `curl -X POST -d` | Send a POST request with JSON data | `curl -X POST -d '{"key":"val"}' http://api/v1` |
| `wget -O` | Download file and save as specific name | `wget -O latest.zip http://url/file.zip` |
| `dig` | DNS lookup for a domain | `dig google.com +short` |
| `nslookup` | Query Internet name servers interactively | `nslookup mydatabase.internal` |
| `chmod 644` | Set permissions: owner rw, others r | `chmod 644 config.yml` |
| `chown user:group` | Change file owner and group | `chown www-data:www-data /var/www` |
| `useradd -m -s` | Create user, make home dir, set shell | `useradd -m -s /bin/bash johndoe` |
| `usermod -aG` | Add user to an additional group | `usermod -aG docker johndoe` |
| `systemctl status` | Check if a system service is running | `systemctl status kubelet` |
| `systemctl enable` | Set a service to start on boot | `systemctl enable docker` |
| `journalctl -u` | View logs for a specific service | `journalctl -u nginx -f` |
| `journalctl -xe` | View end of system logs for errors | `journalctl -xe` |
| `grep -R -i` | Recursive, case-insensitive string search | `grep -R -i "error" /var/log/` |
| `find . -name` | Find files by name in current directory | `find . -name "*.conf"` |
| `find . -mtime` | Find files modified in last 7 days | `find . -mtime -7` |
| `awk '{print $1}'` | Print the first column of text | `cat logs \| awk '{print $1}'` |
| `sed 's/old/new/g'`| Replace text inline | `sed -i 's/8080/80/g' nginx.conf` |
| `tar -czvf` | Compress files into a tarball | `tar -czvf backup.tar.gz /data` |
| `tar -xzvf` | Extract a compressed tarball | `tar -xzvf backup.tar.gz -C /opt` |
| `rsync -avz` | Sync files securely over SSH | `rsync -avz /local/ user@ip:/remote/` |

---

## 2. Git Advanced Commands

| Command | Description | Real Example |
|---------|-------------|--------------|
| `git init` | Initialize a new local Git repository | `git init` |
| `git clone` | Clone a remote repository | `git clone git@github.com:org/repo.git` |
| `git status` | Check working tree status | `git status` |
| `git add -A` | Stage all modified and new files | `git add -A` |
| `git commit -m` | Commit staged files with a message | `git commit -m "Fix typo"` |
| `git commit --amend`| Add changes to the previous commit | `git commit --amend --no-edit` |
| `git push -u` | Push and set upstream tracking | `git push -u origin main` |
| `git push --force` | Overwrite remote history (Dangerous) | `git push --force origin main` |
| `git pull --rebase` | Fetch and rebase instead of merge | `git pull --rebase origin main` |
| `git fetch --all` | Download all history from all remotes | `git fetch --all` |
| `git branch -a` | List all local and remote branches | `git branch -a` |
| `git checkout -b` | Create and switch to a new branch | `git checkout -b feature/login` |
| `git merge` | Merge a branch into the current one | `git merge feature/login` |
| `git rebase -i` | Interactive rebase (squash commits) | `git rebase -i HEAD~3` |
| `git cherry-pick` | Apply a specific commit to current branch | `git cherry-pick abc1234` |
| `git stash` | Temporarily save uncommitted changes | `git stash push -m "WIP"` |
| `git stash pop` | Apply stashed changes and remove from stash | `git stash pop` |
| `git log --oneline` | View compact commit history | `git log --oneline --graph` |
| `git diff` | View unstaged changes | `git diff` |
| `git diff --staged` | View staged changes | `git diff --staged` |
| `git reset --soft` | Undo commit, keep files staged | `git reset --soft HEAD~1` |
| `git reset --hard` | Undo commit, DELETE all changes | `git reset --hard HEAD~1` |
| `git revert` | Create a new commit undoing a past one | `git revert abc1234` |
| `git tag -a` | Create an annotated release tag | `git tag -a v1.0.0 -m "Release 1"` |
| `git clean -fd` | Remove untracked files and directories | `git clean -fd` |

---

## 3. Docker Commands

| Command | Description | Real Example |
|---------|-------------|--------------|
| `docker build -t` | Build an image from a Dockerfile | `docker build -t myapp:1.0 .` |
| `docker run -d` | Run container in background (detached) | `docker run -d --name web nginx` |
| `docker run -p` | Map host port to container port | `docker run -p 8080:80 nginx` |
| `docker run -v` | Mount a volume (HostPath:ContainerPath) | `docker run -v /opt/data:/data postgres` |
| `docker run -e` | Pass environment variables | `docker run -e DB_PASS=secret mysql` |
| `docker ps` | List running containers | `docker ps` |
| `docker ps -a` | List all containers (including stopped) | `docker ps -a` |
| `docker stop` | Gracefully stop a running container | `docker stop web` |
| `docker rm` | Remove a stopped container | `docker rm web` |
| `docker rm -f` | Force stop and remove a container | `docker rm -f web` |
| `docker rmi` | Remove an image from local cache | `docker rmi myapp:1.0` |
| `docker exec -it` | Open an interactive shell inside container | `docker exec -it web /bin/bash` |
| `docker logs -f` | Tail container logs in real-time | `docker logs -f web` |
| `docker logs --tail`| Show last N lines of logs | `docker logs --tail 100 web` |
| `docker inspect` | Show detailed JSON metadata of container | `docker inspect web` |
| `docker stats` | Live CPU/Memory usage of containers | `docker stats` |
| `docker cp` | Copy files between host and container | `docker cp web:/etc/nginx/nginx.conf .` |
| `docker images` | List all locally pulled images | `docker images` |
| `docker pull` | Download an image from a registry | `docker pull redis:alpine` |
| `docker push` | Upload an image to a registry | `docker push myrepo/myapp:1.0` |
| `docker login` | Authenticate to a registry | `docker login -u user registry.com` |
| `docker network ls` | List Docker networks | `docker network ls` |
| `docker network create`| Create a custom bridge network | `docker network create my-net` |
| `docker volume ls` | List managed volumes | `docker volume ls` |
| `docker system prune`| Delete unused containers, networks, images | `docker system prune -a --volumes` |
| `docker compose up -d`| Start a compose stack in background | `docker compose up -d` |
| `docker compose down`| Stop and remove a compose stack | `docker compose down` |

---

## 4. Kubernetes (kubectl) Commands

| Command | Description | Real Example |
|---------|-------------|--------------|
| `kubectl get pods` | List pods in current namespace | `kubectl get pods -n kube-system` |
| `kubectl get nodes` | List cluster worker/control nodes | `kubectl get nodes -o wide` |
| `kubectl get all` | List all standard resources in namespace | `kubectl get all` |
| `kubectl describe` | Detailed info on a specific resource | `kubectl describe pod web-pod-123` |
| `kubectl logs` | View logs for a pod | `kubectl logs web-pod-123` |
| `kubectl logs -f` | Tail logs for a pod | `kubectl logs -f web-pod-123` |
| `kubectl logs -c` | View logs for a specific container in a pod | `kubectl logs web-pod-123 -c nginx` |
| `kubectl exec -it` | Interactive shell inside a pod | `kubectl exec -it web-pod-123 -- /bin/sh` |
| `kubectl apply -f` | Create/Update resources from YAML | `kubectl apply -f deployment.yaml` |
| `kubectl delete -f` | Delete resources defined in YAML | `kubectl delete -f deployment.yaml` |
| `kubectl delete pod`| Manually delete a pod (it will recreate) | `kubectl delete pod web-pod-123` |
| `kubectl port-forward`| Forward local port to pod/svc port | `kubectl port-forward svc/my-db 5432:5432` |
| `kubectl cp` | Copy files to/from a pod | `kubectl cp ./config.txt web-pod:/tmp/` |
| `kubectl scale` | Change number of replicas | `kubectl scale deployment web --replicas=5` |
| `kubectl rollout status`| Check status of a deployment rollout | `kubectl rollout status deployment web` |
| `kubectl rollout history`| View previous deployment versions | `kubectl rollout history deployment web` |
| `kubectl rollout undo`| Rollback to previous deployment version | `kubectl rollout undo deployment web` |
| `kubectl expose` | Create a Service for a Deployment | `kubectl expose deployment web --port=80` |
| `kubectl edit` | Edit a resource's YAML live | `kubectl edit configmap my-config` |
| `kubectl top pods` | Show CPU/Memory usage of pods (needs metrics) | `kubectl top pods -n default` |
| `kubectl top nodes` | Show CPU/Memory usage of nodes | `kubectl top nodes` |
| `kubectl create namespace`| Create a new namespace | `kubectl create namespace dev` |
| `kubectl config get-contexts`| List all available K8s clusters/contexts | `kubectl config get-contexts` |
| `kubectl config use-context`| Switch to a different cluster context | `kubectl config use-context minikube` |
| `kubectl auth can-i` | Check if you have permission to do an action | `kubectl auth can-i delete pods` |

---

## 5. Helm Commands

| Command | Description | Real Example |
|---------|-------------|--------------|
| `helm repo add` | Add a Helm chart repository | `helm repo add bitnami https://charts.bitnami.com/bitnami` |
| `helm repo update` | Update local cache of repo charts | `helm repo update` |
| `helm search repo` | Search for a chart in repos | `helm search repo nginx` |
| `helm install` | Deploy a chart (create a release) | `helm install my-db bitnami/postgresql` |
| `helm install -f` | Deploy with a custom values file | `helm install my-app ./chart -f values.yaml` |
| `helm install --set` | Override a specific value on CLI | `helm install my-app ./chart --set replicaCount=3` |
| `helm upgrade` | Upgrade an existing release | `helm upgrade my-db bitnami/postgresql` |
| `helm rollback` | Roll back to a previous revision | `helm rollback my-db 1` |
| `helm list` | List all installed releases | `helm list -n default` |
| `helm uninstall` | Delete a release | `helm uninstall my-db` |
| `helm history` | View release history and revisions | `helm history my-db` |
| `helm status` | View the status and notes of a release | `helm status my-db` |
| `helm show values` | View the default values of a chart | `helm show values bitnami/redis > default.yaml` |
| `helm create` | Generate a skeleton for a new chart | `helm create my-custom-chart` |
| `helm template` | Render templates locally (dry run) | `helm template my-app ./chart > output.yaml` |

---

## 6. Terraform Commands

| Command | Description | Real Example |
|---------|-------------|--------------|
| `terraform init` | Initialize backend, download providers/modules | `terraform init` |
| `terraform init -upgrade`| Update providers/modules to latest allowed | `terraform init -upgrade` |
| `terraform fmt` | Format HCL code to standard style | `terraform fmt -recursive` |
| `terraform validate`| Check HCL syntax and references | `terraform validate` |
| `terraform plan` | Show what will be created/changed | `terraform plan` |
| `terraform plan -out`| Save the plan to a file for safe apply | `terraform plan -out=tfplan` |
| `terraform apply` | Execute the changes | `terraform apply` |
| `terraform apply -auto-approve`| Execute without asking for confirmation | `terraform apply -auto-approve` |
| `terraform destroy` | Tear down all managed infrastructure | `terraform destroy` |
| `terraform state list`| List all resources tracked in state | `terraform state list` |
| `terraform state show`| Show JSON details of a specific resource | `terraform state show aws_instance.web` |
| `terraform state rm` | Untrack a resource (without deleting it) | `terraform state rm aws_instance.web` |
| `terraform state mv` | Rename a resource in state | `terraform state mv aws_instance.old aws_instance.new` |
| `terraform import` | Bring unmanaged cloud resource into state | `terraform import aws_s3_bucket.mybucket my-bucket-name` |
| `terraform output` | Show defined output variables | `terraform output -json` |
| `terraform force-unlock`| Remove a stuck DynamoDB lock | `terraform force-unlock <LOCK_ID>` |

---

## 7. Ansible Commands

| Command | Description | Real Example |
|---------|-------------|--------------|
| `ansible all -m ping` | Test connectivity to all inventory hosts | `ansible all -m ping -i hosts` |
| `ansible -m command` | Run an ad-hoc raw command | `ansible web -m command -a "uptime"` |
| `ansible -m setup` | Gather system facts from hosts | `ansible all -m setup` |
| `ansible-playbook` | Execute an Ansible playbook | `ansible-playbook deploy.yml` |
| `ansible-playbook -i`| Specify a custom inventory file | `ansible-playbook deploy.yml -i staging.ini` |
| `ansible-playbook -e`| Pass extra variables (overrides playbook vars) | `ansible-playbook deploy.yml -e "version=1.0"` |
| `ansible-playbook --check`| Dry-run (predicts changes) | `ansible-playbook deploy.yml --check` |
| `ansible-playbook --syntax-check`| Verify YAML and syntax validity | `ansible-playbook deploy.yml --syntax-check` |
| `ansible-galaxy init` | Create a new role directory structure | `ansible-galaxy init my-role` |
| `ansible-galaxy install`| Download roles from a requirements file | `ansible-galaxy install -r requirements.yml` |
| `ansible-vault encrypt`| Encrypt a plain-text file | `ansible-vault encrypt secrets.yml` |
| `ansible-vault decrypt`| Decrypt a Vault file permanently | `ansible-vault decrypt secrets.yml` |
| `ansible-vault edit` | Safely open and edit an encrypted file | `ansible-vault edit secrets.yml` |
| `ansible-vault rekey` | Change the password of an encrypted file | `ansible-vault rekey secrets.yml` |

---

## 8. PromQL Queries (Prometheus)

| Query | Description | Real Example |
|-------|-------------|--------------|
| `up` | Check if targets are online (1=UP, 0=DOWN) | `up{job="node_exporter"}` |
| `rate()` | Per-second rate of increase of a counter | `rate(http_requests_total[5m])` |
| `sum()` | Aggregate across all instances | `sum(rate(http_requests_total[5m]))` |
| `avg by (label)` | Average grouped by a specific label | `avg by (instance) (node_memory_MemFree_bytes)` |
| `histogram_quantile()`| Calculate percentiles (like 99th percentile latency) | `histogram_quantile(0.99, sum(rate(http_req_duration_bucket[5m])) by (le))` |
| `process_cpu_seconds_total`| CPU time used by a process | `rate(process_cpu_seconds_total[1m])` |
| `node_filesystem_avail_bytes`| Free disk space on node | `node_filesystem_avail_bytes{mountpoint="/"}` |
| `predict_linear()` | Predict when a metric will hit a threshold (Disk Full) | `predict_linear(node_filesystem_avail_bytes[1h], 24*3600) < 0` |

---

## 9. AWS CLI Commands

| Command | Description | Real Example |
|---------|-------------|--------------|
| `aws configure` | Set up access keys and default region | `aws configure` |
| `aws s3 ls` | List S3 buckets | `aws s3 ls` |
| `aws s3 cp` | Copy file to/from S3 | `aws s3 cp backup.zip s3://my-bucket/` |
| `aws s3 sync` | Sync a local directory with an S3 bucket | `aws s3 sync ./dist/ s3://my-website-bucket/` |
| `aws ec2 describe-instances`| List details of all EC2 instances | `aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' --output table` |
| `aws eks update-kubeconfig`| Configure kubectl for an EKS cluster | `aws eks update-kubeconfig --region us-east-1 --name my-cluster` |
| `aws sts get-caller-identity`| Check who you are authenticated as | `aws sts get-caller-identity` |
| `aws ecr get-login-password`| Login to Elastic Container Registry | `aws ecr get-login-password \| docker login --username AWS --password-stdin <acc-id>.dkr.ecr.us-east-1.amazonaws.com` |
| `aws secretsmanager get-secret-value`| Fetch a plain-text secret | `aws secretsmanager get-secret-value --secret-id my-db-pass --query SecretString --output text` |
| `aws iam list-users` | List all IAM users | `aws iam list-users` |

---

## 10. Azure CLI Commands

| Command | Description | Real Example |
|---------|-------------|--------------|
| `az login` | Authenticate via browser | `az login` |
| `az account set` | Switch to a specific subscription | `az account set --subscription "Prod-Sub"` |
| `az group create` | Create a Resource Group | `az group create --name myRG --location eastus` |
| `az aks get-credentials`| Configure kubectl for an AKS cluster | `az aks get-credentials --resource-group myRG --name myAKS` |
| `az acr login` | Login to Azure Container Registry | `az acr login --name myregistry` |
| `az vm list` | List all VMs | `az vm list --output table` |
| `az storage blob upload`| Upload file to Azure Blob Storage | `az storage blob upload --container-name mycontainer --file backup.zip --name backup.zip` |
| `az keyvault secret show`| Fetch a secret from Key Vault | `az keyvault secret show --name db-pass --vault-name myVault --query value -o tsv` |

---

## 11. Bash One-Liners for DevOps

| Command | Description | Real Example |
|---------|-------------|--------------|
| Kill process by port | Kills whatever is running on port 8080 | `kill -9 $(lsof -t -i:8080)` |
| Decode base64 | Decodes K8s secret strings | `echo "cGFzc3dvcmQ=" \| base64 -d` |
| Watch a command | Re-runs a command every 2 seconds | `watch -n 2 kubectl get pods` |
| Delete evicted K8s pods| Cleans up stuck Evicted pods | `kubectl get pods \| grep Evicted \| awk '{print $1}' \| xargs kubectl delete pod` |
| Generate random password| Creates a 16-character secure string | `openssl rand -base64 16` |
| SSH without host checking| Bypasses known_hosts strictly for local labs | `ssh -o StrictHostKeyChecking=no user@ip` |
| Empty a log file safely| Truncates a file without breaking processes | `> /var/log/syslog` |
| Find largest files | Finds top 10 largest files/folders | `du -a /var \| sort -n -r \| head -n 10` |

---

## Related Notes
[[00-MOC/Master-Index|Master Index]]
[[00-MOC/REF-02 DevOps Interview Q&A Bank|Interview Q&A Bank]]
