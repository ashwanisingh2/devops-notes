---
tags: [devops, iac, ansible, playbooks]
aliases: [Ansible Playbooks]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #none
---

# ANS-02 Ansible Playbooks

> [!abstract] Overview
> While Ad-Hoc commands are great for quick fixes, they are not version-controlled or repeatable. True Infrastructure as Code requires Ansible Playbooks. A Playbook is a YAML file that orchestrates complex, multi-tier IT environments. It defines variables, tasks, conditionals, loops, and error-handling mechanisms, allowing DevOps engineers to bootstrap an entire web architecture—from installing packages to templating configuration files—with a single command.

---

## Concept Overview

- **What it is** — Playbooks are Ansible’s configuration, deployment, and orchestration language. They are written in YAML and describe the policy you want your remote systems to enforce.
- **Why DevOps engineers use it** — To automate complex workflows deterministically. A playbook ensures that every time a new web server is spun up, it receives the exact same Nginx version, the exact same firewall rules, and the exact same SSL certificates, eliminating configuration drift.
- **Where you encounter this in a real job** — Writing a playbook to deploy a LAMP stack, using Jinja2 templates to generate dynamic HAProxy config files based on the number of backend servers, or orchestrating a zero-downtime rolling update.
- **Responsibility Split:**
  - **Junior DevOps**: Runs `ansible-playbook` commands and passes extra variables via CLI.
  - **Mid DevOps**: Writes multi-task playbooks, implements Handlers for service restarts, and uses Jinja2 templating.
  - **Senior/SRE**: Refactors messy playbooks using complex variable precedence, optimizes execution speed (strategy plugins), and handles robust error recovery using `block/rescue/always`.

*Seedha simple mein: Playbook ek recipe book hai. Ad-Hoc command matlab "Bhai ek chai bana de". Playbook matlab "Recipe: Pehle paani ubalo, phir patti dalo, phir doodh dalo". Ye recipe likhi hui hai, aap kisi ko bhi doge, same test wali chai banegi.*

---

## Technical Deep Dive

### 1. Playbook Anatomy
A playbook contains a list of **Plays**. A play targets a specific group of `hosts` and executes a list of `tasks`.
Key elements of a Play:
- `hosts`: Which servers to target from the inventory.
- `become`: Boolean indicating if privilege escalation (sudo) is needed.
- `vars`: Variables defined directly in the playbook.
- `tasks`: The sequential list of Ansible modules to execute.
- `handlers`: Special tasks that ONLY run if triggered by a previous task changing state.

### 2. Task Control (Loops and Conditionals)
Playbooks are smart. You don't write 5 tasks to install 5 packages. You write 1 task and use a `loop` (or `with_items`). 
You can use `when` to execute tasks conditionally based on Ansible Facts. For example: `when: ansible_os_family == "Debian"` ensures `apt` is only used on Ubuntu, not RedHat.

### 3. Templating with Jinja2
Often, a configuration file needs to be dynamic. For example, an Nginx config needs to know the server's specific IP address. Ansible uses the `template` module combined with Jinja2 (`.j2` files). When Ansible pushes the template to the server, it evaluates Jinja2 variables like `{{ ansible_default_ipv4.address }}` and replaces them with the actual data before saving the file on the remote host.

---

## Step-by-Step Lab

> [!warning] Pre-requisites
> - Ansible installed on Control Node
> - Inventory file (`hosts`) configured with at least one target server

### Step 1: Write a Jinja2 Template
```jinja2
# Create a file named index.html.j2
<html>
<head><title>Ansible Deployed</title></head>
<body>
    <h1>Welcome to {{ company_name }}</h1>
    <p>This server's OS is: {{ ansible_distribution }} {{ ansible_distribution_version }}</p>
    <p>Server IP: {{ ansible_default_ipv4.address }}</p>
</body>
</html>
```

### Step 2: Write the Playbook
```yaml
# Create a file named setup-web.yml
---
- name: Deploy Nginx Web Server
  hosts: all
  become: yes # Run as root

  # Define variables used in this play
  vars:
    company_name: "DevOps Vault Corporation"
    http_port: 80

  tasks:
    - name: Install Nginx (Debian/Ubuntu)
      apt:
        name: nginx
        state: latest
        update_cache: yes
      when: ansible_os_family == "Debian"

    - name: Install Nginx (RedHat/CentOS)
      yum:
        name: nginx
        state: latest
      when: ansible_os_family == "RedHat"

    - name: Deploy dynamic HTML template
      template:
        src: index.html.j2
        dest: /var/www/html/index.html
        owner: www-data
        group: www-data
        mode: '0644'
      # If this file changes, notify the handler to restart Nginx
      notify: Restart Nginx

    - name: Ensure Nginx is running and enabled on boot
      service:
        name: nginx
        state: started
        enabled: yes

  # Handlers ONLY run if notified, and run at the very end of the play
  handlers:
    - name: Restart Nginx
      service:
        name: nginx
        state: restarted
```

### Step 3: Check Syntax and Dry Run
```bash
# Verify your YAML syntax is correct
ansible-playbook setup-web.yml --syntax-check

# Run a Dry-Run (Check Mode). It shows what WOULD change, without changing it.
ansible-playbook setup-web.yml --check
```

### Step 4: Execute the Playbook
```bash
# Run the playbook for real
ansible-playbook setup-web.yml -i hosts

# Expected output:
# PLAY [Deploy Nginx Web Server] ****************************************
# TASK [Gathering Facts] ************************************************
# ok: [192.168.1.10]
# TASK [Install Nginx (Debian/Ubuntu)] **********************************
# changed: [192.168.1.10]
# ...
# RUNNING HANDLER [Restart Nginx] ***************************************
# changed: [192.168.1.10]
# PLAY RECAP ************************************************************
# 192.168.1.10 : ok=4 changed=2 unreachable=0 failed=0 skipped=1
```

### Step 5: Verify Idempotency
```bash
# Run it again immediately
ansible-playbook setup-web.yml -i hosts

# Expected output:
# All tasks will report 'ok'. The handler will NOT run because the template didn't change.
# changed=0
```

> [!tip] Pro Tip
> Never use `command: systemctl restart nginx` inside your `tasks` section. It breaks idempotency because the command will execute every single time the playbook runs, interrupting traffic. Always use `notify: Restart Nginx` in your tasks and define the restart logic in the `handlers` section. Handlers only fire if the task actually changed something.

---

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
|---------|-------------|--------------|
| `ansible-playbook` | Executes a playbook | `ansible-playbook deploy.yml -i hosts` |
| `--syntax-check` | Validates YAML and Ansible syntax | `ansible-playbook deploy.yml --syntax-check` |
| `--check` (or `-C`) | Dry run: predicts changes without applying | `ansible-playbook deploy.yml --check` |
| `--step` | Prompts for confirmation before each task | `ansible-playbook deploy.yml --step` |
| `--start-at-task` | Starts execution at a specific task name | `ansible-playbook deploy.yml --start-at-task="Install Nginx"` |
| `--tags` | Only runs tasks assigned a specific tag | `ansible-playbook deploy.yml --tags "db,config"` |
| `-e` / `--extra-vars`| Passes variables overriding playbook vars | `ansible-playbook deploy.yml -e "version=1.5"` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| `Syntax Error while loading YAML` | Incorrect indentation | YAML relies strictly on spaces (not tabs). Ensure lists (`-`) and dictionaries are aligned properly. Use `--syntax-check`. |
| Variable is undefined | Variable precedence / missing quote | Jinja2 variables must be double-quoted if starting a value: `name: "{{ my_var }}"`. Ensure `vars:` is declared at the play level. |
| Handler didn't execute | Task didn't report 'changed' | Handlers ONLY fire if the notifying task's state is `changed`. If you ran the playbook twice, the second run won't trigger the handler. |
| Task runs on Ubuntu but fails on CentOS | Package name mismatch | Apache is `apache2` on Debian, but `httpd` on RedHat. You must use `when:` conditionals to use the correct module/name based on `ansible_os_family`. |
| `FAILED! => {"changed": false, "msg": "Destination directory /etc/myapp does not exist"}` | Missing prerequisite task | You tried to copy/template a file into a folder that doesn't exist. Add a `file: state=directory` task *before* the template task. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A Junior engineer wrote a playbook to download a database backup using `curl`, restore it, and start the app. The playbook fails halfway through because the database is locked. The engineer fixes the DB, reruns the playbook, and it downloads the 50GB backup file again, wasting 2 hours."

**What Junior DevOps Does:**
Uses the `shell` module for everything: `shell: wget url`, `shell: mysql < backup.sql`. Because `shell` isn't idempotent, every time the playbook is rerun, it blindly repeats all actions from step 1.

**Escalation Trigger:**
Deployments take 3 hours instead of 5 minutes because the playbook lacks state awareness and error handling.

**Senior Engineer Resolution:**
1. Refactors the `shell: wget` to use the `get_url` module, which checks if the file exists and matches the checksum before downloading.
2. Wraps the dangerous database restore step in a `block/rescue` structure.
3. Code change:
```yaml
- block:
    - name: Restore Database
      mysql_db:
        state: import
        target: /tmp/backup.sql
  rescue:
    - name: Alert Slack if DB restore fails
      slack:
        msg: "Database restore failed on {{ inventory_hostname }}"
    - name: Fail the playbook gracefully
      fail:
        msg: "Cannot proceed without DB."
```
4. Now, if the playbook is rerun, it skips the 50GB download instantly (idempotency) and handles database errors gracefully by alerting the team instead of crashing silently.

**Lesson Learned:**
Writing a playbook isn't just about scripting bash commands in YAML. It's about designing state-aware, idempotent, and fault-tolerant infrastructure workflows.

---

## Interview Questions

**Q1 (Conceptual):** What is a Handler in Ansible, and how is it different from a standard Task?
**A:** A Handler is a special task that is only executed if it is "notified" by another task. Furthermore, handlers always run at the very end of a play, and they only run once, even if notified by multiple tasks. This is perfectly suited for restarting services like Nginx only if the configuration files actually changed during the run.

**Q2 (Practical):** You have a playbook that installs 15 different packages. How do you rewrite it to be efficient and readable?
**A:** Instead of writing 15 separate `apt` tasks, I would write one task and use a `loop` (or pass a list directly to the module if supported). For example: 
`- apt: name="{{ item }}" state=present`
`  loop: [ 'nginx', 'git', 'curl', 'htop' ]`.

**Q3 (Scenario-based):** You define a variable `port: 80` in your inventory file, `port: 8080` in your playbook `vars` section, and run the playbook with `-e "port=9090"`. Which port will the server actually use?
**A:** It will use `9090`. Ansible has a strict variable precedence order (22 levels). Generally, Inventory variables are the weakest, Playbook variables are stronger, and Extra Vars passed via the CLI (`-e`) are the absolute strongest and will override everything else.

**Q4 (Deep dive):** Explain how `register` and `changed_when` can be used to make a raw shell command idempotent in Ansible.
**A:** Sometimes you must use the `command` module, which always reports `changed`. To make it idempotent, you use `register: my_output` to capture the command's stdout. Then, you add `changed_when: "'Successfully updated' in my_output.stdout"`. Now, Ansible will only report the task as changed (and trigger handlers) if the specific output string is detected, faking idempotency.

**Q5 (Trick/Gotcha):** Can you use a Jinja2 template (`.j2`) to generate an Ansible playbook itself?
**A:** No. Jinja2 templates are evaluated during the execution of a playbook to generate configuration files on the target nodes. Ansible parses the YAML structure of the playbook *before* any Jinja2 variables are evaluated, so you cannot dynamically generate the YAML syntax of the playbook itself using Jinja2 logic.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[06-IaC/ANS-01 Ansible Fundamentals|Ansible Fundamentals]]
[[06-IaC/ANS-03 Ansible Roles and Vault|Ansible Roles and Vault]]
