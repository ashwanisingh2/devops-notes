---
tags: [devops, git, fundamentals]
aliases: [Git Basics]
created: 2025-06-27
status: #complete
difficulty: #beginner
cert-relevant: #none
---

# Git Fundamentals

> [!abstract] Overview
> Git is the distributed version control system that underpins every modern DevOps workflow — from local code commits to CI/CD pipelines, infrastructure-as-code repositories, and Kubernetes manifest management. Understanding Git internals, the staging area, and the commit lifecycle is not optional for a DevOps engineer; it is the foundation upon which branching strategies, pull request workflows, and automated deployments are built. This note covers everything from how Git stores data internally to daily commands you'll use on the job.

---

## Concept Overview

- **What it is** — Git is a distributed version control system (DVCS) that tracks changes in files by creating snapshots (not diffs) of your entire project at each commit. Every developer has a full copy of the repository history locally.
  *Git ek version control system hai jo aapke code ke har change ka snapshot rakhta hai — jaise ek diary mein har page pe date daalke likho ki aaj kya kiya.*

- **Why DevOps engineers use it** — Every CI/CD pipeline starts with a `git push`. Infrastructure-as-code (Terraform, Ansible) lives in Git repos. Kubernetes manifests are version-controlled. Without Git fluency, you cannot debug pipelines, manage releases, or collaborate effectively.
  *Bina Git ke DevOps engineer woh hai jaise bina steering ke gaadi — pipeline trigger hoti hai git push se, IaC code Git mein rehta hai, sab kuch Git se shuru hota hai.*

- **Where it fits in the DevOps lifecycle** — Git is the **Source** stage — the very first block in the CI/CD pipeline. Code → Git → Build → Test → Deploy.

- **Responsibility Split** —
  | Role | Git Responsibility |
  |---|---|
  | Developer | Write code, create branches, make commits, raise PRs |
  | DevOps/SRE | Manage branching strategy, set up hooks, integrate with CI/CD, manage credentials |
  | Lead/Architect | Define Git workflow (Git Flow/Trunk-Based), enforce branch protection |

---

## Technical Deep Dive

### 1. Git Internals — The Four Objects

Git stores everything in the `.git/objects` directory using four types of objects:

| Object | Purpose | Analogy |
|---|---|---|
| **Blob** | Stores file content (no filename, just data) | *Ek dabba jisme sirf saamaan hai, label nahi* |
| **Tree** | Stores directory structure — maps filenames to blobs | *Dabbon ki list jisme likha hai kaunsa dabba kahan rakhna hai* |
| **Commit** | Points to a tree + stores author, message, parent commit | *Diary ka ek page — date, author, aur kya hua sab likha hai* |
| **Tag** | Named pointer to a specific commit (usually a release) | *Bookmark jo aap important page pe lagate ho* |

Every object is identified by a **SHA-1 hash** (40-character hex string). When you run `git add`, Git creates blob objects. When you run `git commit`, Git creates a tree and a commit object.

```bash
# Inspect Git objects
git cat-file -t <hash>    # Show object type
git cat-file -p <hash>    # Pretty-print object content
ls .git/objects/           # See stored objects
```

The `.git` directory structure:

```
.git/
├── HEAD              # Points to current branch ref
├── config            # Repo-level config
├── objects/          # All blobs, trees, commits, tags
├── refs/
│   ├── heads/        # Branch pointers
│   └── tags/         # Tag pointers
├── index             # The staging area (binary file)
└── hooks/            # Client-side hook scripts
```

### 2. Core Workflow — The Three Areas

Git has three working areas that every command interacts with:

```
Working Directory  →  Staging Area (Index)  →  Local Repository  →  Remote Repository
     (edit)              (git add)               (git commit)          (git push)
```

*Socho ki Working Directory tumhara kitchen hai jahan tum khana bana rahe ho. Staging Area thali hai jisme tum serve karne wale items rakh rahe ho. Commit matlab thali table pe rakh di — ab finalized hai. Push matlab thali customer ke paas bhej di.*

**Essential commands in the workflow:**

```bash
# Initialize or clone
git init my-project                    # Create new repo
git clone https://github.com/user/repo.git  # Clone existing

# Daily workflow
git status                             # Check what's changed
git add file.txt                       # Stage specific file
git add .                              # Stage everything
git commit -m "feat: add login page"   # Commit with message
git push origin main                   # Push to remote
git pull origin main                   # Fetch + merge from remote
git fetch origin                       # Download without merging
```

**Understanding HEAD:**
- `HEAD` is a pointer to the current branch's latest commit
- `HEAD~1` means "one commit before HEAD"
- Detached HEAD = HEAD points directly to a commit instead of a branch

### 3. History, Inspection & Configuration

**Viewing history:**

```bash
git log --oneline --graph --all --decorate
# Output:
# * 3a1f2b4 (HEAD -> main) feat: add auth module
# * 9c8d7e6 fix: resolve null pointer
# * 1b2c3d4 (origin/main) initial commit
```

**Diff & Stash:**

```bash
git diff                    # Working dir vs staging
git diff --staged           # Staging vs last commit
git diff HEAD~2..HEAD       # Compare last 2 commits

git stash                   # Temporarily shelve changes
git stash list              # List stashed changes
git stash pop               # Restore and remove stash
git stash apply stash@{1}   # Restore specific stash without removing
```

*Stash ko samjho jaise tum kuch kaam kar rahe ho aur suddenly boss bole "ye pehle kar do" — tum apna kaam ek drawer mein rakh do (stash), boss ka kaam karo, phir drawer se wapas nikaal lo (pop).*

**Tags:**

```bash
git tag v1.0.0                         # Lightweight tag
git tag -a v1.0.0 -m "First release"   # Annotated tag (recommended)
git push origin v1.0.0                 # Push specific tag
git push origin --tags                 # Push all tags
```

**.gitignore patterns:**

```gitignore
# .gitignore
*.log                  # Ignore all log files
node_modules/          # Ignore node_modules directory
.env                   # Ignore environment files
!important.log         # Exception — track this specific log
build/                 # Ignore build output
**/*.tmp               # Ignore .tmp files in any subdirectory
```

**Credential management:**

```bash
# Cache credentials for 1 hour
git config --global credential.helper 'cache --timeout=3600'

# Store credentials permanently (plain text — use on trusted machines only)
git config --global credential.helper store

# Use OS-level credential manager (recommended)
git config --global credential.helper manager   # Windows
git config --global credential.helper osxkeychain  # macOS
```

---

## Step-by-Step Lab

### Lab: Create Repo, Commit, Rollback, and Resolve Merge Conflict

**Step 1 — Initialize a repository and make commits**

```bash
mkdir git-lab && cd git-lab
git init
echo "# My DevOps Project" > README.md
git add README.md
git commit -m "initial commit: add README"
```

Expected output:
```
Initialized empty Git repository in /home/user/git-lab/.git/
[main (root-commit) a1b2c3d] initial commit: add README
 1 file changed, 1 insertion(+)
 create mode 100644 README.md
```

**Step 2 — Make multiple commits to build history**

```bash
echo "app_port=8080" > config.env
git add config.env
git commit -m "feat: add config file"

echo "*.log" > .gitignore
git add .gitignore
git commit -m "chore: add gitignore"

echo "print('hello')" > app.py
git add app.py
git commit -m "feat: add main application"
```

Verify with:
```bash
git log --oneline
# d4e5f6a (HEAD -> main) feat: add main application
# b2c3d4e chore: add gitignore
# 9a8b7c6 feat: add config file
# a1b2c3d initial commit: add README
```

**Step 3 — Rollback with `git reset` (rewrites history)**

```bash
# Soft reset — undo commit but keep changes staged
git reset --soft HEAD~1
git status
# Changes to be committed: app.py

# Hard reset — undo commit AND discard changes (DANGEROUS)
git reset --hard HEAD~1
git log --oneline
# 9a8b7c6 (HEAD -> main) feat: add config file
# a1b2c3d initial commit: add README
```

*Reset ka matlab hai time machine — tum past mein chale gaye aur future delete ho gaya. `--soft` mein saamaan bacha rehta hai, `--hard` mein sab saaf.*

**Step 4 — Rollback with `git revert` (safe, creates new commit)**

```bash
# First, recreate commits
echo "print('hello')" > app.py && git add app.py && git commit -m "feat: add app"

# Revert the config commit (keeps history intact)
git revert HEAD~1 --no-edit
git log --oneline
# f7g8h9i Revert "feat: add config file"
# e5f6g7h feat: add app
# 9a8b7c6 feat: add config file
# a1b2c3d initial commit: add README
```

*Revert ka matlab — galti hui toh ek naya commit bana ke galti fix kar do, lekin purani history mein koi chheda-chhaadi nahi. Production mein hamesha revert use karo, reset nahi.*

**Step 5 — Create and resolve a merge conflict**

```bash
# Create a feature branch
git checkout -b feature/login

# Edit README on feature branch
echo "## Login Feature" >> README.md
git add README.md
git commit -m "feat: add login section to README"

# Switch to main and make conflicting change
git checkout main
echo "## Dashboard Feature" >> README.md
git add README.md
git commit -m "feat: add dashboard section to README"

# Merge feature branch into main
git merge feature/login
```

Expected conflict output:
```
Auto-merging README.md
CONFLICT (content): Merge conflict in README.md
Automatic merge failed; fix conflicts and then commit the result.
```

Resolve the conflict:
```bash
# Open README.md — you'll see:
# <<<<<<< HEAD
# ## Dashboard Feature
# =======
# ## Login Feature
# >>>>>>> feature/login

# Edit to keep both:
cat > README.md << 'EOF'
# My DevOps Project
## Dashboard Feature
## Login Feature
EOF

git add README.md
git commit -m "merge: resolve conflict, keep both features"
```

---

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
|---|---|---|
| `git init` | Initialize new Git repository | `git init my-project` |
| `git clone <url>` | Copy remote repository locally | `git clone https://github.com/org/app.git` |
| `git add .` | Stage all changes | `git add .` |
| `git commit -m "msg"` | Create a commit with message | `git commit -m "fix: resolve timeout bug"` |
| `git push origin main` | Push commits to remote branch | `git push origin main` |
| `git pull origin main` | Fetch and merge remote changes | `git pull origin main` |
| `git log --oneline --graph` | View commit history as graph | `git log --oneline --graph --all` |
| `git diff --staged` | Show staged changes | `git diff --staged` |
| `git stash` | Temporarily shelve uncommitted work | `git stash` → do urgent fix → `git stash pop` |
| `git reset --hard HEAD~1` | Undo last commit and discard changes | `git reset --hard HEAD~1` (use with caution!) |
| `git revert HEAD` | Create new commit that undoes last commit | `git revert HEAD --no-edit` |
| `git tag -a v1.0 -m "msg"` | Create annotated tag | `git tag -a v2.1.0 -m "Release 2.1.0"` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---|---|---|
| `fatal: not a git repository (or any of the parent directories): .git` | You're not inside a Git repo directory | `cd` into the correct project folder, or run `git init` if it's a new project |
| `error: failed to push some refs to 'origin/main'` | Remote has commits you don't have locally | Run `git pull origin main --rebase` first, resolve any conflicts, then `git push` again |
| `CONFLICT (content): Merge conflict in file.txt` | Two branches modified the same lines | Open the file, look for `<<<<<<<` markers, manually edit to keep correct content, then `git add file.txt && git commit` |
| `fatal: refusing to merge unrelated histories` | Trying to merge two repos with no common ancestor | Add `--allow-unrelated-histories` flag: `git merge origin/main --allow-unrelated-histories` |
| `error: Your local changes to the following files would be overwritten by merge` | Uncommitted changes conflict with incoming changes | Either `git stash` your changes first, or `git commit` them before pulling |
| `warning: LF will be replaced by CRLF` | Line ending mismatch (Windows vs Linux) | `git config --global core.autocrlf true` (Windows) or `input` (Mac/Linux) |
| `remote: Permission to user/repo.git denied` | Authentication failure or wrong credentials | Check SSH keys with `ssh -T git@github.com` or reconfigure credential helper |

---

## Real-World Job Scenario

> **Scenario:** A junior DevOps engineer accidentally committed AWS credentials (`.env` file with `AWS_SECRET_ACCESS_KEY`) to the shared repository and pushed it to `main`.

### Junior Action ❌
- Panics and deletes the file, makes a new commit: `git rm .env && git commit -m "remove secrets"`
- Thinks the secret is safe now
- **Problem:** The secret is still visible in Git history. Anyone can run `git log -p` and see it.

### Senior Action ✅
1. **Immediately rotates the compromised AWS credentials** in the AWS Console — this is the #1 priority
2. Removes the file and adds it to `.gitignore`:
   ```bash
   echo ".env" >> .gitignore
   git rm --cached .env
   git commit -m "security: remove leaked credentials, add to gitignore"
   ```
3. Uses `git filter-branch` or **BFG Repo Cleaner** to purge the secret from entire Git history:
   ```bash
   # Using BFG (faster and simpler)
   java -jar bfg.jar --delete-files .env
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   git push --force
   ```
4. Notifies the security team and documents the incident
5. Sets up a **pre-commit hook** or **git-secrets** to prevent future credential leaks:
   ```bash
   # Install git-secrets
   git secrets --install
   git secrets --register-aws
   ```

*Senior engineer pehle credentials rotate karta hai — kyunki agar koi already credentials dekh chuka hai toh file delete karne se kuch nahi hoga. Pehle taala badlo, phir safai karo.*

---

## Interview Questions

### Q1: What is the difference between `git merge` and `git rebase`?
**Answer:** `git merge` creates a new "merge commit" that combines two branches, preserving the complete history of both branches. `git rebase` replays your branch's commits on top of the target branch, creating a linear history. Use merge for shared/public branches (main, develop) to preserve context. Use rebase for local feature branches before pushing to keep history clean. Never rebase commits that have been pushed and shared with others — it rewrites history and causes conflicts for teammates.

### Q2: What happens internally when you run `git add file.txt`?
**Answer:** Git computes the SHA-1 hash of the file content, creates a **blob object** in `.git/objects/`, and updates the **index** (staging area in `.git/index`) to map the filename to this blob hash. The working directory file is unchanged. At this point, the change is staged but not committed.

### Q3: Explain the difference between `git reset --soft`, `--mixed`, and `--hard`.
**Answer:**
- `--soft`: Moves HEAD to the specified commit. Changes remain **staged** (in index). Use when you want to redo a commit message or combine commits.
- `--mixed` (default): Moves HEAD and **unstages** changes. Changes remain in working directory. Use when you want to re-stage selectively.
- `--hard`: Moves HEAD, clears staging area, AND **discards working directory changes**. This is destructive — use only when you want to completely abandon recent work.

### Q4: How do you undo a commit that has already been pushed to a shared remote branch?
**Answer:** Use `git revert`, not `git reset`. `git revert HEAD` creates a new commit that undoes the changes from the specified commit without rewriting history. This is safe for shared branches because it doesn't change existing commit hashes. Example: `git revert abc1234 --no-edit && git push origin main`. Never use `git reset --hard && git push --force` on shared branches — it will break every teammate's local repo.

### Q5: What is a detached HEAD state and how do you fix it?
**Answer:** Detached HEAD occurs when HEAD points directly to a commit instead of a branch reference — typically happens when you `git checkout <commit-hash>` or checkout a tag. Any new commits made in this state are "orphaned" (not on any branch) and can be garbage-collected. To fix: create a branch from the current position with `git checkout -b my-branch`, or switch back to an existing branch with `git checkout main`. If you already made commits in detached HEAD, use `git reflog` to find the commit hash and `git cherry-pick` it onto your branch.

---

## Related Notes

- [[00 DevOps Master Index]]
- [[GIT-02 Branching Strategies]]
- [[GIT-03 GitHub Advanced]]
