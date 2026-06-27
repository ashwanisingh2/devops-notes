---
tags: [devops, serverless, aws, lambda]
aliases: [Serverless and FaaS]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #aws-devops
---

# MISC-02 Serverless and FaaS

> [!abstract] Overview
> Serverless computing allows developers to build and run applications without thinking about servers. It doesn't mean servers don't exist; it means the cloud provider dynamically manages the allocation and provisioning of servers. Function-as-a-Service (FaaS) is a core component of Serverless, where you deploy individual functions (pieces of code) that execute in response to events. AWS Lambda is the most prominent FaaS offering.

## Concept Overview
In traditional computing, you rent a virtual machine (EC2) and pay for it 24/7, whether it's doing work or sitting idle. You also have to patch the OS and manage scaling.
In Serverless (FaaS), you upload your code, and it only runs when triggered (e.g., an HTTP request, a file upload, a database change). You pay *only* for the compute time you consume—down to the millisecond. If your code isn't running, you pay nothing.

*Hindi Explanation: Serverless ka matlab ye nahi ki server ud gaya. Iska matlab hai ki server ka dard (management, OS patching, scaling) ab cloud provider (AWS) ka hai. Jaise Ola/Uber mein aap gadi nahi kharidte, sirf ride ka paisa dete ho. FaaS (Lambda) mein aap sirf utne time ka paisa dete ho jitni der aapka code run hota hai.*

**Key Concepts:**
- **Serverless:** An execution model where the cloud provider manages infrastructure. Includes databases (DynamoDB), storage (S3), and compute.
- **FaaS (Function-as-a-Service):** Event-driven compute. Code runs in ephemeral, stateless containers. (e.g., AWS Lambda, Google Cloud Functions).
- **Cold Start:** The delay experienced when a Serverless function is invoked for the first time or after a period of inactivity, as the cloud provider has to spin up a new container.
- **Serverless Framework & AWS SAM:** IaC tools designed specifically to make defining, packaging, and deploying serverless applications easier.

**Desi Analogy:**
Traditional Servers (EC2) are like hiring a full-time driver. Even if he sits idle all day, you pay his full monthly salary.
Serverless (Lambda) is like booking an Auto-rickshaw on demand. You only pay for the exact distance traveled. If you don't travel, you pay 0 rupees. But, sometimes finding an auto takes a few minutes (Cold Start).

## Technical Deep Dive

### 1. AWS Lambda Architecture
When you create a Lambda function, you provide the code (ZIP file or Container Image) and configure settings like Memory (from 128MB to 10GB). CPU power scales linearly with memory. 
Lambda is heavily event-driven. It integrates natively with over 200 AWS services. For example, an object uploaded to S3 can automatically trigger a Lambda function to resize the image. Lambda scales automatically and massively—handling thousands of concurrent requests without manual intervention.

### 2. Overcoming Cold Starts
Because Lambda spins up microVMs (using Firecracker) dynamically, the first request might take a few seconds (Cold Start) to load the runtime and your code. Subsequent requests to that same instance are fast (Warm Start).
To mitigate cold starts:
- Use faster runtimes (Go, Node.js, Python) instead of heavier ones (Java, .NET) unless optimized (e.g., GraalVM).
- Use **Provisioned Concurrency**: A feature that keeps a specified number of execution environments initialized and ready to respond immediately, at an extra cost.

### 3. Deployment Tools (AWS SAM vs Serverless Framework)
Deploying Lambda functions manually via the AWS Console is fine for testing, but terrible for CI/CD.
- **Serverless Framework (`sls`):** A popular third-party tool that supports multiple clouds (AWS, Azure, GCP). You define your app in a `serverless.yml` file, and it compiles it down to CloudFormation (on AWS) and handles packaging.
- **AWS SAM (Serverless Application Model):** AWS's native extension to CloudFormation. It uses a `template.yaml` file. The `sam cli` allows you to test Lambda functions locally using Docker before deploying.

## Step-by-Step Lab
**Scenario:** Deploy a Python AWS Lambda function using the Serverless Framework. The function is triggered by an S3 upload and sends a mock notification.

**Step 1: Install Serverless Framework**
```bash
npm install -g serverless
```
*Expected output: Serverless Framework installed globally.*

**Step 2: Create a new service**
```bash
serverless create --template aws-python3 --name s3-notifier --path s3-notifier
cd s3-notifier
```
*Expected output: Generates boilerplate files `serverless.yml` and `handler.py`.*

**Step 3: Update handler.py**
Open `handler.py` and replace with:
```python
import json
import urllib.request
import os

def hello(event, context):
    # Get the bucket and file name from the S3 event
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        message = f"New file uploaded: {key} in bucket {bucket}"
        print(message)
        
        # Mock sending a Slack notification
        # webhook_url = os.environ.get('SLACK_WEBHOOK_URL')
        # ... logic to post to webhook ...

    return {"statusCode": 200, "body": json.dumps("Success!")}
```
*Expected output: Code saved.*

**Step 4: Update serverless.yml**
Configure the S3 trigger:
```yaml
service: s3-notifier
frameworkVersion: '3'

provider:
  name: aws
  runtime: python3.9
  region: us-east-1

functions:
  hello:
    handler: handler.hello
    events:
      - s3:
          bucket: my-unique-upload-bucket-999123 # Must be globally unique
          event: s3:ObjectCreated:*
          rules:
            - suffix: .txt
```
*Expected output: Configuration saved.*

**Step 5: Deploy the Service**
*(Requires AWS CLI configured with admin credentials)*
```bash
serverless deploy
```
*Expected output: Packaging service, creating CloudFormation stack, creating S3 bucket, deploying Lambda. Outputs endpoints and function names.*

**Step 6: Test the Trigger**
Upload a `.txt` file to the newly created S3 bucket.
```bash
echo "Hello Serverless" > test.txt
aws s3 cp test.txt s3://my-unique-upload-bucket-999123/
```
Check the Lambda logs:
```bash
serverless logs -f hello
```
*Expected output: Logs showing "New file uploaded: test.txt in bucket..."*

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
| :--- | :--- | :--- |
| `serverless create` | Scaffolds a new serverless project | `sls create --template aws-nodejs` |
| `serverless deploy` | Deploys the stack to AWS | `sls deploy --stage prod` |
| `serverless invoke` | Runs the function remotely on AWS | `sls invoke -f hello -d '{"key":"val"}'` |
| `serverless logs` | Fetches CloudWatch logs for a function| `sls logs -f hello -t` |
| `sam local invoke` | Tests a Lambda locally using Docker | `sam local invoke "MyFunction" -e event.json` |
| `sam deploy -g` | Guided deployment of a SAM application | `sam deploy --guided` |
| `aws lambda list-functions`| Lists all Lambda functions | `aws lambda list-functions` |
| `aws lambda update-function-code`| Updates code without touching IaC (quick fix) | `aws lambda update-function-code --function-name myFunc --zip-file fileb://code.zip` |

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
| :--- | :--- | :--- |
| Error: `Bucket already exists` during deployment. | S3 bucket names must be globally unique across all AWS accounts. | 1. Open `serverless.yml`. 2. Change the bucket name to something random (e.g., append your name or random numbers). 3. Redeploy. |
| Function execution times out after 3 seconds. | Lambda's default timeout is 3s. Your code is taking longer (e.g., API call). | 1. Open `serverless.yml`. 2. Add `timeout: 10` under your function config. 3. Redeploy. |
| AccessDenied Exception when Lambda tries to read DynamoDB. | Lambda Execution Role lacks permissions. | 1. Go to `provider.iam.role.statements` in `serverless.yml`. 2. Add `Allow` for `dynamodb:GetItem` on the target table ARN. |
| Deployment fails: `Unzipped size must be smaller than 250 MB`. | You are bundling too many heavy dependencies (like pandas, numpy) in the ZIP. | 1. Use Lambda Layers to separate dependencies. 2. Alternatively, package the Lambda function as a Docker Container Image (up to 10GB). |
| `sls command not found` | Node or Serverless Framework is not installed. | 1. Install NodeJS. 2. Run `npm install -g serverless`. |

## Real-World Job Scenario
**The Situation:** The marketing team needs to generate PDF reports from user data, but traffic is unpredictable. Sometimes 0 requests per day, sometimes 50,000 requests in an hour after a campaign email.

**Junior DevOps Action:**
- Spins up 5 large EC2 instances behind an Application Load Balancer just to be safe.
- Pays hundreds of dollars a month for servers that sit completely idle 95% of the time.
- Struggles to write auto-scaling rules that respond fast enough to the sudden spikes.

**Senior DevOps Action:**
- Chooses a Serverless architecture (API Gateway + AWS Lambda).
- Writes the PDF generation logic in a Lambda function.
- Deploys using the Serverless Framework.
- Result: When traffic is 0, the cost is $0. When the 50,000 request spike hits, AWS automatically scales out thousands of concurrent Lambda instances instantly to handle the load without breaking a sweat, costing only a few dollars for that specific hour.

## Interview Questions

**Q1: What is a "Cold Start" in Serverless computing and how can you minimize its impact?**
**A:** A cold start is the latency experienced when a serverless function is invoked after being idle. The cloud provider must allocate resources, download the code, start the container, and bootstrap the runtime. To minimize it, you can use lighter runtimes (Python/Node vs Java), keep the deployment package small, or use AWS Provisioned Concurrency, which keeps instances "warm" and ready for a fee.

**Q2: What is the maximum execution time limit for an AWS Lambda function?**
**A:** The maximum execution time limit for AWS Lambda is 15 minutes (900 seconds). If a task takes longer than that, Lambda is not the right tool; you should consider AWS Batch, ECS tasks, or Step Functions to orchestrate multiple Lambdas.

**Q3: How does pricing work for AWS Lambda compared to EC2?**
**A:** EC2 is priced based on uptime (hourly or per-second billing) regardless of CPU utilization. Lambda is priced based on the number of requests and the execution duration (measured in milliseconds) multiplied by the amount of RAM allocated to the function.

**Q4: Can an AWS Lambda function run inside a private VPC?**
**A:** Yes. You can configure a Lambda function to connect to private subnets in a VPC, which allows it to access private resources like RDS databases or ElastiCache. However, attaching to a VPC used to cause severe cold starts (due to ENI creation), but AWS improved this significantly in 2019. Note that a VPC-attached Lambda loses direct internet access unless the subnet has a NAT Gateway.

**Q5: What are Lambda Layers?**
**A:** Lambda Layers are a distribution mechanism for libraries, custom runtimes, and other function dependencies. Instead of bundling massive libraries (like `numpy`) into every single function's deployment package, you put them in a Layer. Multiple functions can reference the same layer, keeping the deployment ZIPs small and deployments fast.

## Related Notes
- [[Master Index]]
- [[MISC-03 Infrastructure Testing]]
