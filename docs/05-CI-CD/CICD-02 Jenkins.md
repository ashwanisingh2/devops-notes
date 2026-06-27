---
tags: [devops, cicd, jenkins, pipeline]
aliases: [Jenkins Pipeline]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #none
---

# CICD-02 Jenkins

> [!abstract] Overview
> Despite newer tools on the market, Jenkins remains the undisputed heavyweight champion of CI/CD in enterprise environments. It is a powerful, open-source automation server with an ecosystem of thousands of plugins. A DevOps engineer who masters Declarative Pipelines (`Jenkinsfile`) can automate almost any infrastructure, build, or deployment task imaginable.

---

## Concept Overview

- **What it is** — A Java-based automation server. It orchestrates pipelines using a controller-agent architecture.
- **Why DevOps engineers use it** — Extreme flexibility. Because Jenkins runs anywhere (on-premise, cloud, Docker, Kubernetes) and integrates with everything via plugins, it is the default choice for companies with complex, legacy, or highly customized release processes.
- **Where you encounter this in a real job** — Writing a `Jenkinsfile` for a Java application, upgrading the Jenkins controller securely, or troubleshooting why a build agent ran out of disk space.
- **Responsibility Split:**
  - **Junior DevOps**: Monitors Jenkins dashboards, restarts failed jobs, and provisions basic Freestyle jobs.
  - **Mid DevOps**: Writes Declarative `Jenkinsfile`s, configures webhooks, and manages credentials in the Jenkins UI.
  - **Senior/SRE**: Architects scalable Jenkins clusters (using Kubernetes agents), writes Groovy Shared Libraries to standardize pipelines across 100+ repos, and manages Jenkins Configuration as Code (JCasC).

*Seedha simple mein: Jenkins ek strict factory manager hai. Controller (manager) khud kaam nahi karta, wo bas plans (Jenkinsfile) padhta hai aur apne Agents (mazdoor) ko bolta hai: "Tum code fetch karo, tum test chalao, aur tum deploy karo." Agar koi fail hota hai, toh Jenkins laal rang ka error phekta hai.*

---

## Technical Deep Dive

### 1. Architecture: Controller and Agents
Never run builds on the Jenkins Controller (formerly called Master). The Controller's job is scheduling, serving the web UI, and storing configurations. Heavy lifting (compiling code, building Docker images) should happen on **Agents** (formerly Slaves). Agents can be permanent EC2 instances, or dynamically spun up as temporary Pods in Kubernetes (which scale down to zero when idle to save costs).

### 2. Freestyle vs. Pipeline
- **Freestyle Jobs**: Configured entirely via the Web UI (clicking buttons). Bad practice today because the configuration isn't version-controlled. If the Jenkins server dies, you lose the job setup.
- **Pipeline Jobs**: Defined as code in a `Jenkinsfile` stored alongside the application code in Git. Follows "Pipeline as Code".
  - *Scripted Pipeline*: Older, uses raw Groovy code. Highly flexible but hard to read.
  - *Declarative Pipeline*: Modern, uses a strict block structure (`pipeline`, `agent`, `stages`, `steps`). Easier to read and the industry standard.

### 3. Declarative Jenkinsfile Anatomy
A standard Declarative Pipeline looks like this:
- `pipeline {}`: The wrapper for the whole script.
- `agent any`: Tells Jenkins to run this on any available build agent. (Or `agent { docker { image 'node:18' } }`).
- `environment {}`: Defines global environment variables.
- `stages {}`: Contains multiple `stage` blocks (e.g., Build, Test, Deploy).
- `steps {}`: The actual shell commands (`sh 'npm install'`) executed inside a stage.
- `post {}`: Actions to run after the pipeline finishes (e.g., `success { slackSend(...) }` or `always { cleanWs() }`).

### 4. Shared Libraries
If 50 different microservices all use the same 5-stage deployment process, you don't want to copy-paste the `Jenkinsfile` 50 times. **Shared Libraries** allow Senior engineers to write custom Groovy functions (e.g., `companyDockerBuild()`) and store them in a central Git repo. The microservice's `Jenkinsfile` then just imports the library and calls that one function.

---

## Step-by-Step Lab

> [!warning] Pre-requisites
> - A server (or local Docker) with Jenkins installed
> - A GitHub repository

### Step 1: Write the Jenkinsfile
```groovy
// In the root of your GitHub repo, create a file named 'Jenkinsfile'
pipeline {
    // Run on any available Jenkins agent
    agent any 
    
    // Define environment variables
    environment {
        DOCKER_CREDS = credentials('docker-hub-creds-id')
        IMAGE_NAME = "myuser/my-app:${env.BUILD_ID}"
    }

    stages {
        stage('Checkout') {
            steps {
                // Pulls code from Git
                checkout scm 
            }
        }
        
        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${IMAGE_NAME} ."
            }
        }
        
        stage('Push to Registry') {
            steps {
                // Logs in using the credentials securely injected by Jenkins
                sh "echo ${DOCKER_CREDS_PSW} | docker login -u ${DOCKER_CREDS_USR} --password-stdin"
                sh "docker push ${IMAGE_NAME}"
            }
        }
        
        stage('Deploy to Staging') {
            steps {
                // Example of executing a remote SSH command to pull and run the image
                sshagent(['staging-server-ssh-key']) {
                    sh "ssh user@staging-server 'docker pull ${IMAGE_NAME} && docker run -d ${IMAGE_NAME}'"
                }
            }
        }
    }
    
    post {
        always {
            // Clean up the workspace so the next build starts fresh
            cleanWs()
        }
        success {
            echo "Pipeline succeeded! Ready for Prod."
        }
        failure {
            echo "Pipeline failed! Sending email to dev team..."
        }
    }
}
```

### Step 2: Configure Credentials in Jenkins
1. Go to Jenkins UI -> Manage Jenkins -> Credentials.
2. Add a `Username with password` credential for Docker Hub. Give it the ID `docker-hub-creds-id`.
3. Add an `SSH Username with private key` credential for the Staging server. Give it the ID `staging-server-ssh-key`.

### Step 3: Create the Pipeline Job
1. Jenkins UI -> New Item -> Select **Pipeline**.
2. Under Pipeline section, choose **Pipeline script from SCM**.
3. Select **Git**, provide your repository URL.
4. Script Path: `Jenkinsfile`.
5. Save and click **Build Now**.

### Step 4: Automate with Webhooks
1. In the job config, check **GitHub hook trigger for GITScm polling**.
2. Go to your GitHub Repo -> Settings -> Webhooks.
3. Add webhook URL: `http://<your-jenkins-ip>:8080/github-webhook/`.
4. Now, every `git push` automatically triggers the pipeline!

> [!tip] Pro Tip
> Never hardcode passwords or API keys in your `Jenkinsfile`. Always use the Jenkins Credentials plugin (`credentials('id')`). Jenkins masks these secrets in the console output, ensuring developers cannot accidentally leak them in the logs.

---

## Common Commands Cheat Sheet

| Concept / Plugin | What It Does | Real Example |
|------------------|-------------|--------------|
| `sh` | Executes a shell script on the Linux agent | `sh 'npm run test'` |
| `bat` | Executes a batch script on a Windows agent | `bat 'msbuild.exe app.sln'` |
| `withCredentials`| Securely binds secrets to variables | `withCredentials([string(credentialsId: 'token', variable: 'TOKEN')]) { ... }` |
| `parallel` | Runs multiple stages simultaneously to save time | `parallel { stage('Test Firefox') {} stage('Test Chrome') {} }` |
| `input` | Pauses pipeline and waits for human approval | `input message: 'Deploy to Prod?'` |
| `timeout` | Fails the stage if it takes too long | `timeout(time: 10, unit: 'MINUTES') { ... }` |
| `retry` | Retries a step if it fails (flaky networks) | `retry(3) { sh 'curl http://api...' }` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| Build fails with `command not found: docker` | Agent doesn't have Docker installed | The Jenkins agent executing the job needs Docker installed, or the Jenkins user lacks permissions (`sudo usermod -aG docker jenkins`). |
| Out of Workspace/Disk Space errors | Old builds filling up the disk | Add `cleanWs()` in the `post { always { ... } }` block to wipe the directory after every run. |
| Pipeline stuck in 'Pending - Waiting for next available executor' | All agents are busy or offline | Go to Manage Jenkins -> Nodes. Check if agents are offline due to disk space or network issues. |
| Console log shows `******` instead of text | Credentials masking | Jenkins aggressively hides anything that looks like a password. If your variable accidentally matches a common string, it gets masked. |
| GitHub Webhook not triggering | Network block | GitHub (internet) cannot reach your local Jenkins (intranet). Use a tool like `ngrok`, or configure Jenkins polling (`H/5 * * * *`) as a fallback. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A developer pushes a commit. The Jenkins pipeline takes 45 minutes to run. The developer loses focus, and the whole team's velocity drops."

**What Junior DevOps Does:**
Checks the pipeline and sees that Unit Tests take 10 minutes, UI Tests take 20 minutes, and Security Scans take 15 minutes, running sequentially one after the other. Suggests skipping the UI tests.

**Escalation Trigger:**
QA team refuses to skip UI tests. The pipeline must be fast, but quality cannot be compromised.

**Senior Engineer Resolution:**
1. Modifies the `Jenkinsfile` to use the **Parallel** block.
2. Architecture change: Instead of running sequentially on one agent, the pipeline requests 3 separate agents simultaneously.
3. Code change:
```groovy
stage('Parallel Testing') {
    parallel {
        stage('Unit Tests') { steps { sh 'npm run unit' } }
        stage('UI Tests') { steps { sh 'npm run ui' } }
        stage('Security Scan') { steps { sh 'npm run scan' } }
    }
}
```
4. The pipeline now completes in 20 minutes (the length of the longest test), saving 25 minutes per commit.

**Lesson Learned:**
Sequential pipelines are an anti-pattern. Always run independent tests in parallel. Utilize your build farm's resources to optimize developer feedback loops.

---

## Interview Questions

**Q1 (Conceptual):** What is the difference between a Scripted Pipeline and a Declarative Pipeline?
**A:** Scripted Pipeline is based heavily on Groovy syntax, offering immense programmatic flexibility but requiring deep coding knowledge. Declarative Pipeline is a newer, more structured, block-based syntax (`pipeline {}`, `stages {}`) designed to be easier to read, write, and maintain, which is the recommended standard today.

**Q2 (Practical):** How do you pause a Jenkins pipeline to wait for a QA manager to approve the deployment to Production?
**A:** I would use the `input` step. In the Deploy stage, I would add `input message: 'Approve Prod Deployment?'`. The pipeline will pause execution indefinitely until a user with the correct permissions logs into the Jenkins UI and clicks "Proceed" or "Abort".

**Q3 (Scenario-based):** Your Jenkins controller crashes and the hard drive is corrupted. How do you recover the jobs?
**A:** If we were using Freestyle jobs, they are likely lost forever unless the `$JENKINS_HOME` directory was backed up. If we were following DevOps best practices, all jobs were defined as Declarative Pipelines (`Jenkinsfile`) stored in GitHub. We just spin up a new Jenkins controller, recreate the pipeline jobs pointing to the Git repos, and we are back online. Furthermore, using JCasC (Jenkins Configuration as Code) ensures even the controller settings are backed up in Git.

**Q4 (Deep dive):** Explain how Jenkins dynamically provisions build agents on a Kubernetes cluster.
**A:** Using the Kubernetes plugin, Jenkins talks to the K8s API. When a job triggers, instead of waiting for a static VM agent, Jenkins dynamically spins up a Pod containing a JNLP (Java Network Launch Protocol) container and any required tool containers (like Maven or Node). The job executes inside the Pod. Once the job finishes, Jenkins deletes the Pod, freeing up cluster resources.

**Q5 (Trick/Gotcha):** Can you run a Docker container *inside* a Jenkins pipeline that is itself running on a Kubernetes Pod?
**A:** Yes, but it requires "Docker-in-Docker" (DinD) or "Docker-out-of-Docker" (DooD) configurations, which have severe security and complexity implications (like mounting the host's `/var/run/docker.sock`). Modern K8s environments prefer using tools like Kaniko or Buildah inside the pipeline Pod, which build Docker images securely without requiring a Docker daemon at all.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[05-CI-CD/CICD-01 CI-CD Concepts|CI/CD Concepts]]
[[05-CI-CD/CICD-03 GitHub Actions|GitHub Actions]]
