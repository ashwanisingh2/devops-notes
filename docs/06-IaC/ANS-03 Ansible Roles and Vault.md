---
tags: [devops, iac, ansible, security]
aliases: [Ansible Roles & Vault]
created: 2025-06-27
status: #complete
difficulty: #advanced
cert-relevant: #none
---

# ANS-03 Ansible Roles and Vault

> [!abstract] Overview
> A massive 1,000-line playbook is an anti-pattern. Just as software developers organize code into functions and classes, DevOps engineers organize Ansible code into Roles. Roles provide a standardized directory structure to bundle tasks, variables, files, and templates into reusable, shareable components. Combined with Ansible Vault—a native encryption tool for securing passwords and API keys—Roles enable enterprise-grade, secure, and modular configuration management.

---

## Concept Overview

- **What it is** — **Roles** break down a complex playbook into modular directories (tasks, handlers, vars). **Vault** is a CLI tool integrated into Ansible that encrypts sensitive data files using AES-256.
- **Why DevOps engineers use it** — Reusability and Security. You write an `nginx` role once, and share it across 10 different projects using Ansible Galaxy. Ansible Vault ensures that database passwords used in those roles can be safely committed to GitHub without leaking.
- **Where you encounter this in a real job** — Downloading a community role from Ansible Galaxy to install PostgreSQL, encrypting an SSL private key using Vault before committing, or refactoring a legacy startup playbook into modular roles.
- **Responsibility Split:**
  - **Junior DevOps**: Decrypts Vault files to view passwords and applies playbooks that use existing roles.
  - **Mid DevOps**: Creates new roles using `ansible-galaxy init`, structures `defaults` vs `vars`, and manages `requirements.yml`.
  - **Senior/SRE**: Automates Vault password injection in Jenkins/GitHub Actions pipelines, writes strict Role metadata/dependencies, and authors open-source community Roles.

*Seedha simple mein: Role ek LEGO block hai. Aap ek 'web-server' block banate ho, aur usko kisi bhi project mein fit kar dete ho bina code copy kiye. Vault us block ke andar chupa hua locker hai, taaki agar koi GitHub pe code padh le, toh usko actual password ki jagah garbage encrypted text dikhe.*

---

## Technical Deep Dive

### 1. The Role Directory Structure
When you create a role, Ansible expects a strict directory structure:
- `tasks/main.yml`: The actual steps to execute.
- `handlers/main.yml`: Handlers triggered by tasks.
- `templates/`: Jinja2 `.j2` files.
- `files/`: Static files to be copied.
- `vars/main.yml`: High-priority variables that should *not* be easily overridden.
- `defaults/main.yml`: Low-priority default variables (Users *should* override these).
- `meta/main.yml`: Author info and Role dependencies (e.g., "This web role requires the firewall role to run first").

### 2. Ansible Galaxy
Ansible Galaxy is the public repository for Ansible Roles (similar to Docker Hub for images or NPM for Node). Instead of writing a role to install MySQL, you can download an officially maintained one. You define external roles in a `requirements.yml` file and install them via `ansible-galaxy install -r requirements.yml`.

### 3. Ansible Vault Security
Vault encrypts files or individual variables. If you have a file `db_pass.yml` containing `password: supersecret`, you run `ansible-vault encrypt db_pass.yml`. It prompts for a Vault password and replaces the file contents with an AES256 encrypted string.
You can safely commit this to Git. When you run a playbook that needs this file, you must pass `--ask-vault-pass` or point to a local text file containing the password `--vault-password-file ~/.vault_pass.txt`.

---

## Step-by-Step Lab

> [!warning] Pre-requisites
> - Ansible installed

### Step 1: Initialize a Role
```bash
# Create a roles directory and initialize a new role called 'webserver'
mkdir roles && cd roles
ansible-galaxy init webserver

# Expected output: - Role webserver was created successfully
# Run 'tree webserver' to see the folder structure generated
```

### Step 2: Populate the Role
```yaml
# 1. Edit roles/webserver/defaults/main.yml
---
http_port: 80

# 2. Edit roles/webserver/tasks/main.yml
---
- name: Install Nginx
  apt:
    name: nginx
    state: present
  become: yes

- name: Create index file
  template:
    src: index.html.j2
    dest: /var/www/html/index.html
  become: yes

# 3. Create roles/webserver/templates/index.html.j2
<h1>Listening on port {{ http_port }}</h1>
<h2>DB Password is: {{ db_password }}</h2>
```

### Step 3: Create and Encrypt Secrets with Vault
```bash
# Go back to the root directory
cd ..

# Create a secrets file
echo "db_password: SuperSecret123!" > secrets.yml

# Encrypt it using Vault (You will be prompted to create a password)
ansible-vault encrypt secrets.yml

# Expected output: Encryption successful
# If you 'cat secrets.yml' now, you will see $ANSIBLE_VAULT;1.1;AES256...
```

### Step 4: Write the Master Playbook
```yaml
# Create site.yml
---
- name: Configure Webservers
  hosts: all
  
  # Load the encrypted variables file
  vars_files:
    - secrets.yml

  # Call the role, overriding the default port
  roles:
    - role: webserver
      vars:
        http_port: 8080
```

### Step 5: Execute with Vault Password
```bash
# Run the playbook. It will fail if you don't provide the vault password!
ansible-playbook site.yml -i hosts --ask-vault-pass

# Expected output:
# Vault password: (enter the password you created)
# PLAY [Configure Webservers] ...
# TASK [webserver : Install Nginx] ...
# TASK [webserver : Create index file] ...
```

> [!tip] Pro Tip
> Do not use `--ask-vault-pass` in a CI/CD pipeline (like Jenkins), because there is no human to type the password. Instead, store the vault password in Jenkins Credentials, inject it as an environment variable, echo it into a temporary file (`.vault_pass`), and use `ansible-playbook --vault-password-file .vault_pass`.

---

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
|---------|-------------|--------------|
| `ansible-galaxy init` | Creates the directory skeleton for a new role | `ansible-galaxy init nginx-role` |
| `ansible-galaxy install`| Downloads roles from requirements file | `ansible-galaxy install -r reqs.yml` |
| `ansible-vault create` | Creates a new encrypted YAML file in an editor | `ansible-vault create secrets.yml` |
| `ansible-vault encrypt` | Encrypts an existing plain-text file | `ansible-vault encrypt db_vars.yml` |
| `ansible-vault decrypt` | Permanently decrypts a file | `ansible-vault decrypt db_vars.yml` |
| `ansible-vault edit` | Opens an encrypted file in Vim/Nano to edit safely | `ansible-vault edit secrets.yml` |
| `ansible-vault rekey` | Changes the vault password of an encrypted file | `ansible-vault rekey secrets.yml` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| `ERROR! Decryption failed (no vault secrets were found)` | Forgot to pass vault password | You ran `ansible-playbook` without `--ask-vault-pass` or `--vault-password-file`. |
| Role tasks are not executing | Wrong folder structure | Ansible strictly looks for `tasks/main.yml`. If you named it `install.yml`, Ansible will ignore it unless you explicitly use `import_tasks` inside `main.yml`. |
| `ERROR! the role 'mysql' was not found` | Role path issue | Ansible looks for roles in a `roles/` directory relative to the playbook, or in `/etc/ansible/roles`. Check your folder paths or `roles_path` in `ansible.cfg`. |
| Variable in role isn't updating when I pass `-e` | Using `vars/` instead of `defaults/` | Variables in a role's `vars/main.yml` have very high precedence and are hard to override. If a variable is meant to be overridden by the user, put it in `defaults/main.yml`. |
| CI Pipeline hangs forever | Prompting for Vault password | The pipeline is waiting for terminal input. You must use `--vault-password-file` in automated environments. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A team has a monolithic 800-line playbook `deploy.yml` that configures Docker, sets up the firewall, creates users, and deploys a Node.js app. The Security team wants to use the exact same Docker setup on their Bastion host."

**What Junior DevOps Does:**
Copies the 200 lines related to Docker from `deploy.yml` and pastes it into a new `bastion.yml` playbook. Next month, a Docker vulnerability is found, and they forget to update the copy-pasted code in `bastion.yml`.

**Escalation Trigger:**
Code duplication leads to configuration drift and unpatched vulnerabilities across different server types.

**Senior Engineer Resolution:**
1. Rips out the Docker logic and runs `ansible-galaxy init roles/docker-setup`.
2. Moves the tasks, files, and variables into the Role.
3. In `deploy.yml`, replaces 200 lines with:
   `roles: - role: docker-setup`
4. In `bastion.yml`, uses the exact same:
   `roles: - role: docker-setup`
5. Fast forward: When the vulnerability is announced, the Senior updates the `docker-setup` role *once*, and both playbooks automatically inherit the security patch.

**Lesson Learned:**
Roles enforce modularity. If you find yourself copying and pasting tasks between playbooks, stop immediately and abstract it into a Role.

---

## Interview Questions

**Q1 (Conceptual):** What is the difference between `defaults` and `vars` inside an Ansible Role?
**A:** Both store variables, but they have opposite precedence levels. `defaults/main.yml` has the absolute lowest precedence; it is designed for fallback values that users of the role are expected to override. `vars/main.yml` has very high precedence; it is used for internal role logic that users should almost never override.

**Q2 (Practical):** You have a large `secrets.yml` file, but you only want to encrypt one specific variable (`db_password`) instead of the whole file. How do you do this?
**A:** I would use Ansible Vault's string encryption. I run `ansible-vault encrypt_string 'SuperSecret123!' --name 'db_password'`. It generates an encrypted block of text. I can copy and paste that block directly into my normal, unencrypted YAML file.

**Q3 (Scenario-based):** You downloaded a role from Ansible Galaxy to install Redis. It works, but you need it to also create a specific custom log directory after Redis installs. You cannot edit the downloaded role directly. How do you achieve this?
**A:** In my master playbook, I would use `pre_tasks` or `post_tasks`. I would call the Redis role in the `roles:` section, and define my custom directory creation task in the `post_tasks:` section, guaranteeing it runs immediately after the role finishes.

**Q4 (Deep dive):** Explain how role dependencies work in `meta/main.yml`.
**A:** If Role A relies on Role B (e.g., a PHP role relies on a WebServer role), you can define this in Role A's `meta/main.yml` under the `dependencies:` block. When you apply a playbook containing Role A, Ansible will automatically detect the dependency and execute Role B *before* executing Role A.

**Q5 (Trick/Gotcha):** Can a Handler in Role A be notified by a Task in Role B?
**A:** Yes. By default, all handlers across all roles included in a play are loaded into a global namespace. A task in Role B can `notify: Restart Nginx`, and it will trigger the handler defined in Role A, provided the handler names exactly match. (This can also cause naming collisions, which is why handler names should be highly specific).

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[06-IaC/ANS-02 Ansible Playbooks|Ansible Playbooks]]
[[05-CI-CD/CICD-02 Jenkins|Jenkins (For Vault CI Integration)]]
