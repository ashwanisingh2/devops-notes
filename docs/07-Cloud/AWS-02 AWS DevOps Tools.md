---
tags: [devops, ci-cd, aws]
aliases: [AWS DevOps Tools]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #aws-devops
---
# AWS DevOps Tools

> [!abstract]
> This note focuses on the AWS native suite of DevOps and CI/CD tools designed to automate software delivery and infrastructure provisioning. We cover the AWS Code suite (CodeCommit, CodeBuild, CodeDeploy, CodePipeline), infrastructure as code with CloudFormation, platform as a service via Elastic Beanstalk, and secure configuration/access management using Systems Manager (SSM) Parameter Store and Session Manager.

## Concept Overview

To achieve continuous integration and continuous deployment entirely within the AWS ecosystem, AWS provides a managed suite of developer tools.
- **CodeCommit:** Managed source control service (Git repositories).
- **CodeBuild:** Fully managed continuous integration service that compiles source code, runs tests, and produces ready-to-deploy software packages.
- **CodeDeploy:** Automates software deployments to compute services like EC2, ECS, and Lambda.
- **CodePipeline:** CI/CD service for fast and reliable application and infrastructure updates. It glues the above tools together.
- **CloudFormation (CFN):** Infrastructure as Code (IaC) to provision and manage AWS resources using YAML/JSON templates.
- **Elastic Beanstalk:** PaaS that abstracts infrastructure setup. You just upload your code, and Beanstalk handles deployment, provisioning, load balancing, and auto-scaling.
- **SSM Parameter Store / Session Manager:** Parameter Store provides secure, hierarchical storage for configuration data and secrets. Session Manager allows secure, auditable shell access to EC2 without SSH keys or open inbound ports.

*Hindi translation & analogy:* *Yeh tools aapki factory ka assembly line hain. CodeCommit apka godown (store) hai jahan raw material (code) rakha hai. CodeBuild factory ki machine hai jo code ko process karti hai. CodeDeploy delivery boy hai jo final product server tak le jaata hai, aur CodePipeline in sabka manager hai jo ensure karta hai sab ek flow mein ho. CloudFormation ek blueprint hai jisse aap poori building (infrastructure) ek click mein bana sakte hain.*

## Technical Deep Dive

### 1. The AWS CI/CD Pipeline
AWS CodePipeline orchestrates the CI/CD workflow. It watches a source repository (CodeCommit, GitHub, S3) for changes. When a commit occurs, it triggers CodeBuild. CodeBuild uses a `buildspec.yml` file in the repository root to define build phases (install, pre_build, build, post_build). The artifacts produced (e.g., a compiled binary or Docker image) are passed to CodeDeploy. CodeDeploy uses an `appspec.yml` file to define how the application is installed and started on target instances (In-place, Blue/Green deployments).

### 2. Infrastructure as Code: CloudFormation
CloudFormation automates resource provisioning. A template contains several sections: Parameters (inputs), Mappings (lookup tables), Resources (the actual AWS services to create - mandatory), and Outputs. A CFN Stack is the instantiation of a template. Changes to an existing stack are made via Change Sets, which allow you to preview modifications before executing them. It ensures consistent, repeatable environments across dev, staging, and prod.

### 3. Systems Manager (SSM) and Elastic Beanstalk
SSM Parameter Store is critical for secure CI/CD. Instead of hardcoding API keys or database passwords in `buildspec.yml` or CloudFormation, you reference them dynamically from Parameter Store (or Secrets Manager). SSM Session Manager replaces traditional SSH access by using the SSM Agent on the instance to tunnel shell access over HTTPS, removing the need for bastion hosts or port 22 exposure. Elastic Beanstalk is ideal for teams lacking deep AWS expertise, as it manages the underlying EC2, ASG, and ALB resources automatically while allowing customization via `.ebextensions`.

## Step-by-Step Lab

**Scenario:** Create a simple CI/CD pipeline using AWS native tools that deploys a static website to an S3 bucket.

1. **Create an AWS CodeCommit Repository**
   ```bash
   aws codecommit create-repository --repository-name my-web-app --repository-description "My static website"
   # Output will contain the cloneUrlHttp
   ```
2. **Create a `buildspec.yml` file**
   In your local project directory, create `buildspec.yml`:
   ```yaml
   version: 0.2
   phases:
     build:
       commands:
         - echo "Building the static site..."
         - zip -r artifact.zip index.html style.css
   artifacts:
     files:
       - artifact.zip
   ```
3. **Push Code to CodeCommit**
   ```bash
   git remote add origin https://git-codecommit.us-east-1.amazonaws.com/v1/repos/my-web-app
   git add .
   git commit -m "Initial commit"
   git push -u origin master
   ```
4. **Create a CodeBuild Project**
   You need a service role for CodeBuild first. Once created:
   ```bash
   aws codebuild create-project --name my-web-build \
   --source type=CODECOMMIT,location=https://git-codecommit.us-east-1.amazonaws.com/v1/repos/my-web-app \
   --artifacts type=S3,location=my-pipeline-artifacts-bucket \
   --environment type=LINUX_CONTAINER,image=aws/codebuild/standard:5.0,computeType=BUILD_GENERAL1_SMALL \
   --service-role arn:aws:iam::123456789012:role/CodeBuildRole
   ```
5. **Create a CodePipeline**
   Create a pipeline JSON definition linking CodeCommit (Source) -> CodeBuild (Build) -> S3 (Deploy).
   ```bash
   aws codepipeline create-pipeline --cli-input-json file://pipeline.json
   ```
   *(Pipeline automatically triggers on new commits).*
6. **Verify Deployment**
   Push a new change to CodeCommit. Monitor the CodePipeline console to see the Source, Build, and Deploy stages succeed.

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
| :--- | :--- | :--- |
| `aws codecommit credential-helper` | Git config for CodeCommit auth | `git config --global credential.helper '!aws codecommit credential-helper $@'` |
| `aws codebuild start-build` | Manually triggers a build project | `aws codebuild start-build --project-name my-project` |
| `aws codepipeline start-pipeline-execution` | Triggers a pipeline execution | `aws codepipeline start-pipeline-execution --name my-pipeline` |
| `aws ssm put-parameter` | Stores a config value or secret | `aws ssm put-parameter --name "/app/db_pass" --value "secure123" --type "SecureString"` |
| `aws ssm start-session` | Starts an interactive shell session | `aws ssm start-session --target i-0abcd1234efgh5678` |
| `aws cloudformation describe-stack-events` | Views CFN deployment logs | `aws cloudformation describe-stack-events --stack-name my-vpc-stack` |
| `aws deploy create-deployment` | Triggers a CodeDeploy rollout | `aws deploy create-deployment --application-name MyApp --deployment-group-name MyDG` |
| `eb create` | Creates a Beanstalk environment | `eb create dev-env --instance-type t2.micro` |

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
| :--- | :--- | :--- |
| **CodeBuild fails with "Access Denied" to S3** | CodeBuild IAM Service Role lacks permissions to the artifact S3 bucket. | 1. Open IAM Console. 2. Find the CodeBuild role. 3. Attach a policy granting `s3:PutObject` to the target bucket ARN. |
| **CodeDeploy agent not executing AppSpec** | CodeDeploy agent is not installed, not running, or IAM instance profile is missing. | 1. Connect via Session Manager. 2. `systemctl status codedeploy-agent`. 3. Ensure EC2 role has `AWSCodeDeployRole` policy. |
| **CloudFormation stack stuck in ROLLBACK_FAILED** | A resource deletion failed during rollback (e.g., S3 bucket not empty). | 1. Manually empty the S3 bucket or resolve the blocking resource. 2. Manually delete the stack in CFN console, skipping the failed resource. |
| **Session Manager cannot connect to EC2** | SSM Agent missing/stopped, or EC2 lacks network access to SSM endpoints. | 1. Ensure EC2 IAM role has `AmazonSSMManagedInstanceCore`. 2. Verify EC2 has NAT/IGW access or VPC endpoints for SSM. |
| **Pipeline doesn't trigger on CodeCommit push** | CloudWatch Event rule missing or Pipeline webhook misconfigured. | 1. Edit pipeline in console. 2. Re-save the source action to recreate the EventBridge rule automatically. |

## Real-World Job Scenario

**Scenario:** The development team complains that every deployment to the staging environment requires manual SSH access to restart services and pull code.

**Junior DevOps Action:** Writes a bash script that SSHs into the server, runs `git pull`, and `systemctl restart app`, and runs it locally from their laptop when asked.
**Senior DevOps Action:** Implements AWS CodePipeline. Packages the application in CodeBuild, then uses CodeDeploy with an `appspec.yml` to gracefully stop the app, deploy new files, and start the service. Replaces all SSH access with SSM Session Manager for secure auditing. Stores database credentials in SSM Parameter Store to eliminate hardcoded secrets in the code.

## Interview Questions

**Q1: What is the purpose of `buildspec.yml` and `appspec.yml`?**
A1: `buildspec.yml` is used by CodeBuild to define build commands, environment variables, and artifacts to output during the CI process. `appspec.yml` is used by CodeDeploy to dictate how an application is deployed, specifying file copying locations and lifecycle hooks (like ApplicationStop, BeforeInstall, AfterInstall) during the CD process.

**Q2: Explain Blue/Green deployments in AWS CodeDeploy.**
A2: In a Blue/Green deployment, the new version (Green) is provisioned alongside the old version (Blue). CodeDeploy routes a small percentage of traffic (or test traffic) to Green. Once verified, the load balancer shifts 100% of traffic to Green, and the Blue instances are either terminated or kept for a fast rollback.

**Q3: How do you handle secrets securely in an AWS CI/CD pipeline?**
A3: Store secrets in AWS Systems Manager (SSM) Parameter Store as `SecureString` or in AWS Secrets Manager. Reference these secrets dynamically in CloudFormation templates, ECS Task Definitions, or in `buildspec.yml` using the parameter ARN, rather than hardcoding them in source control.

**Q4: Why use CloudFormation Change Sets?**
A4: Change Sets allow you to preview the impact of changes to a CloudFormation stack before applying them. It shows which resources will be created, modified, or deleted (especially important to see if a database instance will be replaced and lose data) preventing accidental destructive actions.

**Q5: What are the benefits of using SSM Session Manager over SSH?**
A5: Session Manager doesn't require opening inbound port 22 in Security Groups, doesn't require managing SSH keys, works on instances in private subnets without a bastion host (via VPC endpoints), and centrally logs all session activity (commands executed) to CloudTrail and CloudWatch Logs for auditing.

## Related Notes
- [[Master Index]]
- [[07-Cloud/AWS-01 AWS Core Services for DevOps]]
- [[02-Configuration-Management/Ansible-01 Introduction]]
