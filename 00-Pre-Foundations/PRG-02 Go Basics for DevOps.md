---
tags: [devops, golang, scripting]
aliases: [Go for DevOps]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #none
---

# PRG-02 Go Basics for DevOps

> [!abstract]
> Go (Golang) is the language of modern cloud-native infrastructure. Kubernetes, Docker, Terraform, and Prometheus are all written in Go. Its ability to compile down to a single static binary, amazing concurrency features, and high performance make it the go-to language for writing reliable and fast DevOps tooling.

## Concept Overview

**What:** Go is a statically typed, compiled programming language designed at Google. It focuses on simplicity, speed, and massive concurrency.
**Why:** Unlike Python, which requires an interpreter and dependency management (like `pip` and virtual environments) on the target machine, Go compiles your code into a single executable file. You just drop the binary on a Linux server and it runs. No dependencies attached.
**Where:** Used to build CLI tools, custom Kubernetes operators, microservices, and high-performance infrastructure agents.
**Responsibility Split:** While Python is great for quick scripts and API gluing, Go is used when you need to build robust, distributed tools or extend the Kubernetes ecosystem.

*Go (Golang) DevOps ki duniya ka naya bullet train hai. Python ek aaraamdaayik gaadi (car) ki tarah hai, par jab aapko hazaaron concurrent requests handle karni ho ya bina kisi headache (dependencies) ke kisi bhi server pe tool run karna ho, tab Go kaam aata hai.*

## Technical Deep Dive

### 1. The Basics: Types, Control Flow, and Pointers
Go is statically typed, meaning you must declare if a variable is an `int`, `string`, or `bool`. It has strict rules—if you declare a variable and don't use it, the program won't compile. Control flow relies on `if/else`, robust `switch` statements, and only one looping construct: `for` (which can act as a `while` loop too).
Pointers allow you to pass the memory address of a variable rather than a copy of the variable itself, which is crucial for performance and modifying state efficiently.

### 2. Structs and Interfaces
Go does not have classes like traditional Object-Oriented languages. Instead, it groups related data using `structs`. 
`Interfaces` in Go are powerful because they are implemented implicitly. If a struct has the methods defined in an interface, it automatically satisfies that interface. This makes Go highly modular and is heavily used in Terraform providers and Kubernetes controllers.
*Jaise ek form mein alag-alag fields hote hain (Name, Age), struct bilkul waise hi data ko bundle karta hai. Interface yeh batata hai ki us data ke paas kya-kya "capabilities" hain (jaise Print karna ya Save karna).*

### 3. Concurrency (Goroutines & Channels) and Error Handling
The biggest selling point of Go is Goroutines—lightweight threads managed by the Go runtime. You can launch thousands of Goroutines by simply putting the keyword `go` before a function call. Channels are pipes that connect concurrent Goroutines, allowing them to send and receive data safely without race conditions.
Error handling in Go is explicit. There are no `try/catch` blocks. Functions return an `error` as a second return value, and you must check it immediately (`if err != nil`). This forces developers to handle failures upfront.

## Step-by-Step Lab

**Objective:** Write a Go CLI tool to concurrently ping multiple URLs and check their HTTP status codes.

**Step 1: Initialize the Go module**
```bash
mkdir go-healthcheck && cd go-healthcheck
go mod init devops/healthcheck
```
*Expected Output:* `go: creating new go.mod: module devops/healthcheck`

**Step 2: Write the Go code (`main.go`)**
```go
package main

import (
	"fmt"
	"net/http"
	"time"
)

func checkURL(url string, ch chan string) {
	start := time.Now()
	resp, err := http.Get(url)
	elapsed := time.Since(start).Round(time.Millisecond)

	if err != nil {
		ch <- fmt.Sprintf("[DOWN] %s is unreachable (Error: %v)", url, err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode == 200 {
		ch <- fmt.Sprintf("[UP]   %s responded with %d in %v", url, resp.StatusCode, elapsed)
	} else {
		ch <- fmt.Sprintf("[WARN] %s responded with %d in %v", url, resp.StatusCode, elapsed)
	}
}

func main() {
	urls := []string{
		"https://google.com",
		"https://github.com",
		"https://this-site-does-not-exist.com",
	}

	ch := make(chan string)

	// Launch a goroutine for each URL
	for _, url := range urls {
		go checkURL(url, ch)
	}

	// Collect and print results
	for i := 0; i < len(urls); i++ {
		fmt.Println(<-ch)
	}
}
```

**Step 3: Run the code directly**
```bash
go run main.go
```
*Expected Output:*
```text
[UP]   https://github.com responded with 200 in 235ms
[UP]   https://google.com responded with 200 in 341ms
[DOWN] https://this-site-does-not-exist.com is unreachable (Error: Get "https://this-site-does-not-exist.com": dial tcp: lookup this-site-does-not-exist.com: no such host)
```

**Step 4: Build a static binary**
```bash
GOOS=linux GOARCH=amd64 go build -o healthcheck-linux
ls -lh healthcheck-linux
```
*Expected Output:* You will see a standalone executable file `healthcheck-linux` roughly 6-7 MB in size, ready to be deployed to any Linux server.

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
| :--- | :--- | :--- |
| `go run main.go` | Compiles and executes the file immediately | `go run main.go` |
| `go build -o <name>` | Compiles the code into an executable binary | `go build -o mytool` |
| `go mod init <name>` | Initializes a new Go module for dependency tracking | `go mod init github.com/user/project` |
| `go mod tidy` | Cleans up unused dependencies and downloads new ones | `go mod tidy` |
| `GOOS=linux go build` | Cross-compiles the binary for Linux | `GOOS=linux GOARCH=amd64 go build -o app` |
| `go get <pkg>` | Downloads a third-party package | `go get github.com/spf13/cobra` |
| `go test ./...` | Runs all unit tests in the project | `go test ./... -v` |
| `go fmt ./...` | Automatically formats the Go source code | `go fmt ./...` |

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
| :--- | :--- | :--- |
| `imported and not used: "fmt"` | Go is very strict. You imported a package but didn't use it anywhere in your code. | 1. Remove the unused import from the `import` block. 2. Or use `_ "fmt"` if needed only for side-effects (rare). |
| `cannot use x (type int) as type string` | Go is strongly typed. You cannot implicitly mix types. | 1. Convert the type explicitly using functions like `strconv.Itoa()` for int to string. |
| `go.mod file not found in current directory` | You are trying to build or run tests outside a Go module. | 1. Navigate to the project root. 2. Run `go mod init <module-name>`. |
| `fatal error: all goroutines are asleep - deadlock!` | A Goroutine is waiting to receive on a channel, but no one is sending data, or vice versa. | 1. Ensure for every `<-ch` there is a corresponding `ch <- value`. 2. Check channel buffering. |
| `undefined: MyFunction` | Function is in another file, but you only ran `go run main.go`. | 1. Run `go run .` to compile all `.go` files in the current directory together. |

## Real-World Job Scenario

**Scenario:** Your company needs a lightweight agent running on 5,000 servers to collect custom metrics and send them to a central API every 10 seconds.
- **Junior Action:** Writes a Python script and creates an Ansible playbook to install Python3, pip, create a virtual environment, install requirements, and deploy the script on all 5,000 servers. Spends days troubleshooting broken Python environments on older OS versions.
- **Senior Action:** Writes the agent in Go using Goroutines for efficiency. Runs `go build`, packages the single 10MB binary into a `.deb`/`.rpm` or just copies it over via SSH, sets up a systemd service, and calls it a day. Zero dependencies on the target servers.

## Interview Questions

**Q1: Why is Go preferred over Python for writing Kubernetes operators or Docker?**
**A:** Go compiles to a statically linked binary, meaning it bundles the runtime and dependencies together. This makes deployments trivial. Furthermore, its lightweight Goroutines make it highly scalable for concurrent operations (like monitoring thousands of pods), and its strong typing prevents runtime crashes. 

**Q2: How does error handling work in Go?**
**A:** Go treats errors as normal values. Functions that can fail return an `error` interface as their last return value. Developers must explicitly check `if err != nil` and handle it. There are no exceptions (`try/catch`), which forces explicit error checking at every step.

**Q3: What are Goroutines and Channels?**
**A:** A Goroutine is a lightweight thread managed by the Go runtime, significantly cheaper than an OS thread (taking only ~2KB of memory). A Channel is a typed conduit that allows Goroutines to safely communicate and synchronize data with each other without relying on complex locks or mutexes.

**Q4: Explain "Defer" in Go. Where is it typically used?**
**A:** The `defer` keyword delays the execution of a function until the surrounding function returns. It is most commonly used for cleanup actions, such as closing file handles (`defer file.Close()`), releasing locks, or closing database/HTTP connections to prevent resource leaks.

**Q5: How do you handle dependencies in Go?**
**A:** Go uses Go Modules. You initialize a project with `go mod init`, which creates a `go.mod` file. When you import packages and build the code, Go automatically fetches dependencies and updates the `go.mod` and `go.sum` (checksum) files. You use `go mod tidy` to clean up and sync dependencies.

## Related Notes
- [[PRG-01 Python for DevOps]]
- [[LX-04 OS Concepts for DevOps]]
- [[Master Index]]
