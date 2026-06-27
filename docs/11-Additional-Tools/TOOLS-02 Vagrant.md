---
tags: [devops, virtualization, vagrant, infrastructure-as-code]
aliases: [Vagrant]
created: 2025-06-27
status: #complete
difficulty: #beginner
cert-relevant: #none
---

# Vagrant

> [!abstract] Overview
> Vagrant is an open-source tool by HashiCorp for building and managing virtual machine environments in a single workflow. It provides an easy-to-configure, reproducible, and portable work environment built on top of industry-standard technology (VirtualBox, VMware, AWS). It lowers development environment setup time, increases production parity, and makes the "works on my machine" excuse a thing of the past.

## Concept Overview (What/Why/Where/Responsibility Split)

**What is it?**
Vagrant acts as a wrapper around virtualization software (like VirtualBox). Instead of clicking through a GUI to create a VM, allocate RAM, attach ISOs, and set up networking, you write a text file (`Vagrantfile`) describing the VM. Vagrant reads this file and automates the VM creation.

*Hindi Explanation:*
*Vagrant ko ek thekedar (contractor) samjho jo ghar (VM) banata hai. Agar aap khud VirtualBox use karoge, toh aapko ek-ek eent khud rakhni padegi (RAM set karo, ISO lagao). Vagrant me aap bas ek naksha (Vagrantfile) de dete ho, aur wo apne aap VirtualBox se baat karke exact waisa hi ghar taiyar kar deta hai. Koi naya developer aaye, usko bas `vagrant up` type karna hai, aur uska setup ready!*

**Why use it?**
*   **Reproducibility:** Everyone on the team gets the exact same OS and dependencies.
*   **Disposable Environments:** Messed up the VM? Just run `vagrant destroy` and `vagrant up` to get a fresh one.
*   **Provisioning:** Easily hook up shell scripts, Ansible, or Chef to configure the VM automatically after it boots.

**Where is it used?**
Primarily used for local development environments, testing configuration management scripts (like Ansible playbooks) locally before applying them to cloud servers, and creating local multi-node clusters (like local K8s or Swarm).

**Responsibility Split**
*   **DevOps/Platform Team:** Creates and maintains the standard `Vagrantfile` and base boxes for the company.
*   **Developers:** Run `vagrant up` to start coding, ensuring their environment matches production closely.

## Technical Deep Dive

### 1. The Vagrantfile Syntax (Ruby)
The `Vagrantfile` is the heart of Vagrant. It is written in Ruby syntax, though you don't need to know Ruby to write it. It defines:
*   **Box:** The base OS image (e.g., `ubuntu/bionic64`, `centos/7`).
*   **Provider configuration:** Specific settings for the hypervisor (e.g., VirtualBox GUI mode, RAM allocation, CPU cores).
*   **Networking:** Port forwarding (mapping host port 8080 to guest port 80), private networks (host-only), or public networks (bridged).

### 2. Providers and Boxes
Vagrant doesn't run VMs itself; it relies on **Providers**. The default and most common provider is Oracle VirtualBox because it is free and cross-platform. Other providers include VMware, Hyper-V, and even AWS/Docker.
A **Box** is a packaged Vagrant environment, typically a compressed base operating system image. Vagrant Cloud (HashiCorp's public registry) hosts thousands of pre-built boxes. When you specify `config.vm.box = "ubuntu/focal64"`, Vagrant downloads this box and clones it to create your VM.

### 3. Provisioners
Booting a plain OS isn't enough; you need software installed. Vagrant **Provisioners** allow you to automatically install software, alter configurations, and more, as part of the `vagrant up` process.
*   **Shell Provisioner:** Runs a bash script. Great for simple setups.
*   **Ansible/Chef/Puppet Provisioners:** Integrates with config management tools. This is extremely powerful for DevOps, as you can test your Ansible playbooks locally on Vagrant VMs before hitting production servers.

## Step-by-Step Lab

**Scenario:** Create a Vagrantfile that provisions two Ubuntu VMs (node1 and node2) and installs Docker on them using a shell script.

**Step 1: Install Prerequisites**
Ensure you have VirtualBox and Vagrant installed on your host machine.

**Step 2: Create Project Directory**
```bash
mkdir vagrant-docker-lab && cd vagrant-docker-lab
```

**Step 3: Write the Vagrantfile**
```ruby
# Create a file named Vagrantfile
Vagrant.configure("2") do |config|
  # Define standard setup for all nodes
  config.vm.box = "ubuntu/focal64"
  
  # Provisioning script to install Docker
  $install_docker = <<-SCRIPT
    apt-get update
    apt-get install -y docker.io
    usermod -aG docker vagrant
    systemctl enable docker
    systemctl start docker
  SCRIPT

  # Define Node 1
  config.vm.define "node1" do |node1|
    node1.vm.hostname = "node1.local"
    node1.vm.network "private_network", ip: "192.168.50.10"
    node1.vm.provision "shell", inline: $install_docker
  end

  # Define Node 2
  config.vm.define "node2" do |node2|
    node2.vm.hostname = "node2.local"
    node2.vm.network "private_network", ip: "192.168.50.11"
    node2.vm.provision "shell", inline: $install_docker
  end
end
```

**Step 4: Bring up the environment**
```bash
vagrant up
# Output: Bringing machine 'node1' up with 'virtualbox' provider...
# Output: Bringing machine 'node2' up with 'virtualbox' provider...
# (Wait while it downloads the box, boots, and runs the script)
```

**Step 5: Verify the setup**
```bash
# SSH into node1
vagrant ssh node1

# Inside node1, check Docker
docker --version
# Output: Docker version 20.10.x...

# Exit node1
exit
```

**Step 6: Destroy the environment**
```bash
vagrant destroy -f
# Output: ==> node2: Destroying VM and associated drives...
```

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
| :--- | :--- | :--- |
| `vagrant init` | Creates a basic Vagrantfile | `vagrant init ubuntu/focal64` |
| `vagrant up` | Creates and configures guest machines | `vagrant up` |
| `vagrant ssh` | Connects to machine via SSH | `vagrant ssh webserver` |
| `vagrant halt` | Gracefully shuts down the VM | `vagrant halt` |
| `vagrant reload` | Restarts VM, applies new Vagrantfile config | `vagrant reload --provision` |
| `vagrant provision` | Runs provisioners without rebooting | `vagrant provision` |
| `vagrant status` | Shows state of machines in Vagrantfile | `vagrant status` |
| `vagrant destroy` | Deletes the VM and its disk | `vagrant destroy -f` |

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
| :--- | :--- | :--- |
| `VBoxManage not found` error | VirtualBox not installed or not in PATH | 1. Install VirtualBox.<br>2. Add VirtualBox directory to System PATH. |
| SSH connection timeout during `vagrant up` | VT-x/AMD-V disabled in Host BIOS | 1. Restart host PC.<br>2. Enter BIOS.<br>3. Enable Hardware Virtualization. |
| Vagrant up hangs at "Warning: Connection timeout" | Network adapter conflict | 1. Open VirtualBox GUI.<br>2. Delete unused Host-Only Adapters.<br>3. `vagrant reload`. |
| Provision script didn't run | Script added after `vagrant up` | 1. Run `vagrant provision` to force the script to run on an existing VM. |
| Permission denied in provision script | Running script as non-root | 1. Vagrant shell provisioner runs as root by default. If using `privileged: false`, ensure script uses `sudo`. |

## Real-World Job Scenario

**Scenario:** A development team is building a microservices app. Developers are using Macs, but production is CentOS 8. Developers complain about weird bugs that don't happen in production.

*   **Junior Engineer's Action:** Asks developers to be careful and install the exact same versions of software on their Macs via Homebrew. Bugs persist due to OS-level differences (e.g., file paths, glibc versions).
*   **Senior Engineer's Action:** Creates a `Vagrantfile` using a `centos/8` box. Configures it with Ansible (the exact same Ansible playbooks used for production). Checks the `Vagrantfile` into the git repository. Developers now run `vagrant up`, code in their Mac IDE via synced folders, and the code runs inside the CentOS VM. "Works on my machine" issues drop to zero.

## Interview Questions

1.  **Q: What problem does Vagrant solve in the DevOps lifecycle?**
    *   **A:** It eliminates environment inconsistencies between developers and production by providing reproducible, infrastructure-as-code-driven local virtual environments.
2.  **Q: How does Vagrant differ from Docker?**
    *   **A:** Docker provides containerization (sharing the host OS kernel, lightweight), while Vagrant orchestrates full Virtual Machines (heavyweight, separate kernel). Vagrant is often used to provision the VM *on which* Docker runs.
3.  **Q: What is a Vagrant Box?**
    *   **A:** A Vagrant Box is a packaged format for Vagrant environments. It is essentially a compressed base OS image (like an ISO) that Vagrant clones to quickly boot up a VM without running an OS installation process.
4.  **Q: Explain Vagrant Synced Folders.**
    *   **A:** Synced folders automatically sync a directory on the host machine with a directory inside the guest VM. By default, the directory containing the `Vagrantfile` is synced to `/vagrant` in the guest. This allows developers to use their host IDEs to edit code while it runs in the VM.
5.  **Q: How do you apply a new configuration change in the Vagrantfile to an already running VM?**
    *   **A:** You run `vagrant reload`. If the change involves provisioning scripts, you run `vagrant reload --provision` to restart the VM and re-run the provisioners.

## Related Notes
- [[Master Index]]
- [[ANSIBLE-01 Ansible Architecture]]
- [[LINUX-01 System Administration]]
