---
tags: [devops, python, scripting]
aliases: [Python DevOps]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #none
---

# PRG-01 Python for DevOps

> [!abstract]
> Python is the ultimate glue language in DevOps. While Bash is great for simple system tasks, Python scales better for complex logic, interacting with REST APIs, parsing structured data like JSON and YAML, and orchestrating massive deployments. It is the language behind tools like Ansible and AWS CLI.

## Concept Overview

**What:** Python is a high-level, interpreted programming language known for its readability and massive ecosystem of libraries.
**Why:** DevOps requires automation across different systems. Python bridges the gap between infrastructure (Linux/Cloud) and applications, handling text processing, networking, and system calls with ease.
**Where:** Used in CI/CD pipelines, custom monitoring agents, cloud function lambdas (AWS Lambda), and infrastructure management scripts.
**Responsibility Split:** Developers write application code in Python; DevOps Engineers write automation scripts, tools, and hooks in Python.

*Jaise ek mechanic ke paas ek master wrench hota hai jo har nut aur bolt pe lag jata hai, waise hi DevOps mein Python ek master tool hai. Bash scripts ek limit ke baad bohot messy ho jate hain (jaise jugaad ka wire), par Python ka code hamesha saaf aur maintainable rehta hai.*

## Technical Deep Dive

### 1. System Interaction (`os`, `sys`, `subprocess`, `argparse`)
In DevOps, your script needs to talk to the underlying operating system. The `os` module handles environment variables and filesystem paths, while `sys` handles script arguments and exit codes. 
The `subprocess` module is a powerhouse—it replaces old tools like `os.system`. It allows you to run Bash commands from Python, capture their `stdout`/`stderr`, and act on the exit codes. 
`argparse` is used to build professional Command Line Interfaces (CLIs) so your script can accept flags like `--env prod` or `--dry-run`.
*Bina argparse ke script likhna matlab bina menu card ke restaurant chalana. User ko pata hi nahi hoga kya options available hain!*

### 2. Data Handling & Regex (`json`, `yaml`, `re`, File I/O)
DevOps runs on structured data. APIs return JSON, Kubernetes/Ansible use YAML, and log files are plain text. Python’s native `json` module and the third-party `pyyaml` library allow you to convert these files into Python dictionaries, manipulate them, and write them back.
File I/O uses context managers (`with open('file.txt', 'r') as f:`) which ensures files are safely closed even if an error occurs.
For parsing messy log files, the `re` (Regex) module extracts patterns like IP addresses or error codes. 
*YAML aur JSON Python dictionaries ke hi sage bhai hain. Ek baar data Python dictionary mein aa gaya, toh uske saath khelna bohot aasan ho jata hai.*

### 3. Networking, APIs, and Error Handling (`requests`)
The `requests` library is the standard for making HTTP calls. Whether you are triggering a Jenkins build, fetching metrics from Prometheus, or sending an alert to Slack, `requests` handles the GET/POST methods effortlessly.
Robust automation requires strict error handling. Wrapping code in `try...except` blocks ensures that if an API goes down or a file is missing, your script doesn't just crash abruptly. Instead, it logs the failure and alerts the team, or retries the operation gracefully.

## Step-by-Step Lab

**Objective:** Create a Python tool that parses an API, modifies a YAML file, runs a system command, and sends a webhook.

**Step 1: Set up the environment**
```bash
mkdir py-devops-lab && cd py-devops-lab
python3 -m venv venv
source venv/bin/activate
pip install requests pyyaml
```
*Expected Output:* Virtual environment created and packages installed.

**Step 2: Create a dummy config YAML**
```bash
cat <<EOF > config.yaml
server:
  host: localhost
  port: 8080
  status: offline
EOF
```

**Step 3: Write the Python Script (`devops_tool.py`)**
```python
import yaml
import subprocess
import requests
import sys

def check_service(service_name):
    print(f"Checking {service_name}...")
    result = subprocess.run(["systemctl", "is-active", service_name], capture_output=True, text=True)
    return result.stdout.strip() == "active"

def update_yaml(file_path):
    with open(file_path, 'r') as f:
        data = yaml.safe_load(f)
    
    data['server']['status'] = 'online'
    
    with open(file_path, 'w') as f:
        yaml.dump(data, f)
    print("YAML updated.")

def send_slack_alert(msg):
    webhook_url = "https://example.com/slack-webhook-placeholder" # Dummy
    payload = {"text": msg}
    try:
        r = requests.post(webhook_url, json=payload)
        r.raise_for_status()
    except requests.exceptions.RequestException as e:
        print(f"Failed to send alert: {e}")

if __name__ == "__main__":
    is_up = check_service("sshd")
    if is_up:
        update_yaml("config.yaml")
        print("Service is running, config updated.")
    else:
        send_slack_alert("ALERT: sshd is down on the server!")
        sys.exit(1)
```

**Step 4: Run the script**
```bash
python3 devops_tool.py
```
*Expected Output (if sshd is running):*
```text
Checking sshd...
YAML updated.
Service is running, config updated.
```

**Step 5: Verify YAML modification**
```bash
cat config.yaml
```
*Expected Output:*
```yaml
server:
  host: localhost
  port: 8080
  status: online
```

## Common Commands Cheat Sheet

| Command / Code Snippet | What It Does | Real Example |
| :--- | :--- | :--- |
| `pip install -r requirements.txt` | Installs Python dependencies from a file | `pip install -r requirements.txt` |
| `subprocess.run(["ls", "-l"])` | Executes a shell command from Python | `subprocess.run(["df", "-h"], capture_output=True)` |
| `json.loads(string)` | Converts JSON string to Python dictionary | `data = json.loads('{"key":"value"}')` |
| `yaml.safe_load(file)` | Converts YAML file to Python dictionary | `config = yaml.safe_load(open('config.yml'))` |
| `requests.get(url)` | Makes an HTTP GET request | `r = requests.get('https://api.github.com')` |
| `sys.argv` | Access command line arguments | `script_name = sys.argv[0]` |
| `os.environ.get('VAR')` | Safely get an environment variable | `db_pass = os.environ.get('DB_PASSWORD')` |
| `re.findall(pattern, text)` | Find all regex matches in a string | `ips = re.findall(r'\d+\.\d+\.\d+\.\d+', logs)` |

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
| :--- | :--- | :--- |
| `ModuleNotFoundError: No module named 'yaml'` | PyYAML package is not installed in the current environment. | 1. Ensure venv is active (`source venv/bin/activate`). 2. Run `pip install pyyaml`. |
| `JSONDecodeError: Expecting property name enclosed in double quotes` | The string being parsed has single quotes or trailing commas, which makes it invalid JSON. | 1. Check the source JSON. 2. Replace single quotes with double quotes. 3. Remove trailing commas. |
| `subprocess.CalledProcessError: Command returned non-zero exit status 1` | The bash command executed by `subprocess.run(check=True)` failed. | 1. Use `try...except subprocess.CalledProcessError as e:`. 2. Print `e.stderr` to see the actual bash error. |
| `requests.exceptions.ConnectionError: Max retries exceeded` | The target API or URL is unreachable (firewall/DNS issue). | 1. Check if the server has internet. 2. Verify URL. 3. Test with `curl` to isolate Python issues from network issues. |
| `IndentationError: expected an indented block` | Mixed tabs and spaces, or missing indentation after a colon (`:`). | 1. Configure editor to use 4 spaces for tabs. 2. Fix indentation block under `if`, `def`, or `for`. |

## Real-World Job Scenario

**Scenario:** The DevOps team needs to delete all AWS EBS volumes that are "available" (unattached) for more than 30 days to save costs.
- **Junior Action:** Logs into the AWS Console, filters volumes, and manually deletes them one by one. Takes 3 hours.
- **Senior Action:** Writes a Python script using the `boto3` SDK to fetch all unattached volumes, checks their creation date using the `datetime` module, and deletes them automatically. Puts the script in an AWS Lambda function triggered by EventBridge every week. Takes 30 minutes to write and saves hours every month.

## Interview Questions

**Q1: How is `subprocess.run()` different from `os.system()`?**
**A:** `os.system()` just runs the command and returns the exit code, but dumps output directly to the terminal. `subprocess.run()` is more modern and allows you to capture standard output (`stdout`) and standard error (`stderr`) into Python variables using `capture_output=True`, making it much better for automation.

**Q2: How do you securely pass secrets to a Python script without hardcoding them?**
**A:** Never hardcode secrets. Pass them as environment variables and read them using `os.environ.get('SECRET_NAME')`. Alternatively, fetch them at runtime from a secrets manager like AWS Secrets Manager or HashiCorp Vault using their respective Python SDKs.

**Q3: Explain the difference between lists and dictionaries in Python. When would you use each?**
**A:** A list is an ordered collection of items accessed by index (e.g., `servers[0]`). A dictionary is a collection of key-value pairs accessed by key (e.g., `config['port']`). Use lists for a collection of similar items (like a list of IP addresses), and dictionaries for structured configurations or mapping relationships.

**Q4: How do you handle a situation where an API call might occasionally time out?**
**A:** Use the `timeout` parameter in the `requests` library (e.g., `requests.get(url, timeout=5)`). Combine this with a `try...except requests.exceptions.Timeout:` block. For robust automation, implement a retry mechanism using a loop or a library like `tenacity` with exponential backoff.

**Q5: What are Python decorators and have you used them in DevOps?**
**A:** Decorators are wrappers that modify the behavior of a function without changing its source code, using the `@decorator_name` syntax. In DevOps, they are commonly used in web frameworks like Flask/FastAPI for routing (`@app.route`), or custom decorators can be written to add automatic retries, logging, or execution time tracking to pipeline scripts.

## Related Notes
- [[PRG-02 Go Basics for DevOps]]
- [[LX-04 OS Concepts for DevOps]]
- [[Master Index]]
