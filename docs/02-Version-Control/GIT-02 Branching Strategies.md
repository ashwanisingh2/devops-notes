---
tags: [devops, git, branching]
aliases: [Git Branching]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #none
---

# Branching Strategies

> [!abstract] Overview
> Branching is the mechanism that allows parallel development, safe experimentation, and structured release management in any Git-based workflow. Choosing the right branching strategy — Git Flow, Trunk-Based Development, or GitHub Flow — directly impacts your team's deployment velocity, merge conflict frequency, and CI/CD pipeline design. This note compares all three models, explains merge vs rebase with real scenarios, and covers branch governance practices like protection rules, CODEOWNERS, and naming conventions that production teams rely on daily.

---

## Concept Overview

- **What it is** — A branching strategy is a set of rules that define how developers create, name, merge, and delete branches in a shared repository. It standardizes collaboration and prevents chaos when multiple people work on the same codebase.
  *Branching strategy ek traffic system ki tarah hai — agar sab log bina rules ke gaadi chalaayenge toh accident hoga. Strategy batati hai ki kaunsa branch kab banana hai, kab merge karna hai, aur kaise.*

- **Why DevOps engineers care** — Your CI/CD pipeline behavior is tied to branches. `main` may trigger production deploy, `develop` may trigger staging, feature branches may trigger preview environments. The branching model dictates what gets deployed where and when.
  *DevOps engineer ka kaam hai pipeline design karna — aur pipeline branch pe depend karti hai. Agar branching strategy galat hai toh pipeline bhi galat jagah deploy karegi.*

- **Where it fits** — Between code development and CI/CD pipeline triggers. The branching model is the contract between developers and the automation system.

- **Responsibility Split** —
  | Role | Branching Responsibility |
  |---|---|
  | Developer | Create feature/bugfix branches, raise PRs, resolve conflicts |
  | DevOps/SRE | Configure branch protection, set up CI triggers per branch, manage merge policies |
  | Tech Lead | Choose branching model, define naming conventions, enforce PR review standards |

---

## Technical Deep Dive

### 1. Branching Models — Git Flow vs Trunk-Based vs GitHub Flow

| Aspect | Git Flow | Trunk-Based Development | GitHub Flow |
|---|---|---|---|
| **Main branches** | `main` + `develop` | `main` only | `main` only |
| **Feature branches** | `feature/*` from `develop` | Short-lived (< 1 day) from `main` | `feature/*` from `main` |
| **Release process** | `release/*` branch → merge to `main` + `develop` | Release from `main` directly (feature flags) | Merge PR to `main` → auto-deploy |
| **Hotfixes** | `hotfix/*` from `main` → merge to both `main` + `develop` | Fix on `main` directly | Fix branch from `main` → PR → merge |
| **Complexity** | High — multiple long-lived branches | Low — one branch, feature flags | Low — simple PR workflow |
| **Best for** | Scheduled releases, enterprise products | Continuous deployment, mature CI/CD | Small teams, SaaS, open-source |
| **Merge conflicts** | Frequent (branches diverge) | Rare (short-lived branches) | Moderate |
| **CI/CD compatibility** | Moderate — needs complex pipeline triggers | Excellent — single branch focus | Good — PR-based triggers |

*Git Flow ko samjho ek factory assembly line — raw material (feature) alag line pe banta hai, quality check (release branch) alag section mein hota hai, aur final product (main) sirf approved hoke jaata hai. Trunk-Based mein sab ek hi line pe kaam karte hain lekin chhota-chhota kaam karte hain. GitHub Flow beech ka rasta hai.*

**When to use which:**
- **Git Flow** → When you have versioned releases (v1.0, v2.0), mobile apps, or products with long QA cycles
- **Trunk-Based** → When you deploy multiple times a day, have strong CI/CD, and use feature flags
- **GitHub Flow** → When you want simplicity, have a small team, and deploy on every merge to main

### 2. Merge vs Rebase — When to Use Each

**Merge** creates a merge commit that combines two branches:

```bash
git checkout main
git merge feature/login
# Creates a merge commit: "Merge branch 'feature/login' into main"
```

**Rebase** replays your commits on top of the target branch:

```bash
git checkout feature/login
git rebase main
# Your feature commits are replayed after main's latest commit
```

*Merge ka matlab — do nadiyaan mil rahi hain aur sangam pe ek naya point banta hai (merge commit). Rebase ka matlab — tum apni nadi uthake doosri nadi ke end se shuru kara do, jaise ek line mein lag gaye.*

| Situation | Use Merge | Use Rebase |
|---|---|---|
| Shared/public branches (main, develop) | ✅ | ❌ Never |
| Local feature branch before pushing | Okay | ✅ Preferred |
| PR squash and merge | ✅ Common | Not applicable |
| Preserving full history context | ✅ | ❌ |
| Clean, linear history | ❌ | ✅ |

**Cherry-pick** — Apply a single commit from another branch:

```bash
git cherry-pick abc1234
# Applies just that one commit to your current branch
```

*Cherry-pick matlab puri branch merge nahi karni, sirf ek specific commit uthake apni branch pe lagana — jaise buffet se sirf paneer tikka uthana.*

**Interactive Rebase** — Rewrite, squash, reorder, or edit commits:

```bash
git rebase -i HEAD~4
# Opens editor with last 4 commits:
# pick abc1234 feat: add login
# pick def5678 fix: typo in login
# pick ghi9012 fix: another typo
# pick jkl3456 feat: add logout

# Change to:
# pick abc1234 feat: add login
# squash def5678 fix: typo in login
# squash ghi9012 fix: another typo
# pick jkl3456 feat: add logout
```

This squashes the two typo-fix commits into the login commit, resulting in a cleaner history.

### 3. Branch Governance — Naming, Protection & CODEOWNERS

**Branch naming conventions:**

| Prefix | Purpose | Example |
|---|---|---|
| `feature/` | New feature work | `feature/user-auth` |
| `bugfix/` | Bug fixes | `bugfix/login-timeout` |
| `hotfix/` | Urgent production fixes | `hotfix/payment-crash` |
| `release/` | Release preparation | `release/v2.1.0` |
| `chore/` | Non-feature work (docs, refactoring) | `chore/update-readme` |

**Branch protection rules** (configured in GitHub Settings → Branches):
- Require pull request reviews before merging
- Require status checks to pass (CI must be green)
- Require linear history (no merge commits)
- Restrict who can push to `main`
- Require signed commits

**CODEOWNERS file** (placed at `.github/CODEOWNERS`):

```
# .github/CODEOWNERS
# Global owner
* @devops-team

# Specific paths
/terraform/    @infra-team
/k8s/          @platform-team
/src/auth/     @security-team @backend-team
*.md           @docs-team
```

*CODEOWNERS file batata hai ki kis folder ka maalik kaun hai — jaise society mein flat ka owner fixed hota hai, waise hi codebase mein bhi har folder ka owner define hota hai. Jab bhi us folder mein PR aayega, owner ko automatically review ke liye tag kar diya jaayega.*

**PR (Pull Request) process:**
1. Create feature branch → make commits → push
2. Open PR against target branch (main/develop)
3. Automated checks run (CI, linting, tests)
4. Code review by CODEOWNERS / reviewers
5. Address review comments → push fixes
6. Squash & merge (or merge commit, per team policy)
7. Delete the feature branch

---

## Step-by-Step Lab

### Lab: Implement Git Flow, Create PR with Conflict, Squash & Merge

**Step 1 — Set up repository with Git Flow structure**

```bash
mkdir branching-lab && cd branching-lab
git init
echo "# Branching Lab" > README.md
git add README.md
git commit -m "initial commit"

# Create the develop branch (Git Flow's integration branch)
git checkout -b develop
echo "develop branch created" >> README.md
git add README.md
git commit -m "chore: initialize develop branch"
```

Expected output:
```
Switched to a new branch 'develop'
[develop 4a5b6c7] chore: initialize develop branch
 1 file changed, 1 insertion(+)
```

**Step 2 — Create a feature branch and make commits**

```bash
git checkout -b feature/user-login develop

# Simulate feature work with multiple commits
echo "def login(user, password):" > auth.py
echo "    return True" >> auth.py
git add auth.py
git commit -m "feat: add login function skeleton"

echo "    # validate credentials" >> auth.py
git add auth.py
git commit -m "feat: add credential validation comment"

echo "    # log attempt" >> auth.py
git add auth.py
git commit -m "feat: add logging placeholder"

git log --oneline
# c3d4e5f feat: add logging placeholder
# b2c3d4e feat: add credential validation comment
# a1b2c3d feat: add login function skeleton
```

**Step 3 — Squash commits using interactive rebase**

```bash
git rebase -i HEAD~3
```

In the editor that opens, change:
```
pick a1b2c3d feat: add login function skeleton
squash b2c3d4e feat: add credential validation comment
squash c3d4e5f feat: add logging placeholder
```

Save and close. In the next editor, write a combined commit message:
```
feat: implement user login function

- Added login function skeleton
- Added credential validation
- Added logging placeholder
```

Verify:
```bash
git log --oneline
# f6g7h8i feat: implement user login function
```

*Squash ka matlab hai chhote-chhote commits ko ek bada commit banana — jaise 10 chhoti parcels ko ek bada box mein pack karna. History clean rehti hai.*

**Step 4 — Create a merge conflict scenario**

```bash
# Switch to develop and make a conflicting change
git checkout develop
echo "def login(user, token):" > auth.py
echo "    return validate(token)" >> auth.py
git add auth.py
git commit -m "feat: refactor login to use token auth"

# Now try to merge feature branch
git merge feature/user-login
```

Expected conflict:
```
Auto-merging auth.py
CONFLICT (content): Merge conflict in auth.py
Automatic merge failed; fix conflicts and then commit the result.
```

**Step 5 — Resolve conflict and complete the merge**

```bash
# View the conflict
cat auth.py
# <<<<<<< HEAD
# def login(user, token):
#     return validate(token)
# =======
# def login(user, password):
#     return True
#     # validate credentials
#     # log attempt
# >>>>>>> feature/user-login

# Resolve by combining both approaches
cat > auth.py << 'EOF'
def login(user, token):
    # validate credentials
    result = validate(token)
    # log attempt
    log_login_attempt(user, result)
    return result
EOF

git add auth.py
git commit -m "merge: resolve login conflict, combine token auth with logging"

# Clean up feature branch
git branch -d feature/user-login
```

**Step 6 — Simulate a release using Git Flow**

```bash
# Create release branch from develop
git checkout -b release/v1.0.0 develop
echo "VERSION=1.0.0" > version.txt
git add version.txt
git commit -m "release: bump version to 1.0.0"

# Merge release into main
git checkout main
git merge release/v1.0.0 --no-ff -m "release: v1.0.0"
git tag -a v1.0.0 -m "Release version 1.0.0"

# Also merge back into develop
git checkout develop
git merge release/v1.0.0 --no-ff -m "merge: release v1.0.0 back to develop"

# Clean up
git branch -d release/v1.0.0

# Verify
git log --oneline --graph --all
```

---

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
|---|---|---|
| `git checkout -b <branch>` | Create and switch to new branch | `git checkout -b feature/payment` |
| `git merge <branch>` | Merge branch into current branch | `git merge feature/payment` |
| `git rebase <branch>` | Rebase current branch onto target | `git rebase main` |
| `git rebase -i HEAD~N` | Interactive rebase last N commits | `git rebase -i HEAD~5` |
| `git cherry-pick <hash>` | Apply specific commit to current branch | `git cherry-pick a1b2c3d` |
| `git branch -d <branch>` | Delete merged branch | `git branch -d feature/payment` |
| `git branch -D <branch>` | Force delete unmerged branch | `git branch -D experiment/broken` |
| `git merge --abort` | Cancel an in-progress merge | `git merge --abort` |
| `git rebase --abort` | Cancel an in-progress rebase | `git rebase --abort` |
| `git log --oneline --graph --all` | Visualize all branches | `git log --oneline --graph --all --decorate` |
| `git push origin --delete <branch>` | Delete remote branch | `git push origin --delete feature/old` |
| `git branch -a` | List all branches (local + remote) | `git branch -a` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---|---|---|
| `CONFLICT (content): Merge conflict in file.py` | Two branches modified the same lines in the same file | Open the file, find `<<<<<<<` / `=======` / `>>>>>>>` markers, manually choose the correct code, then `git add file.py && git commit` |
| `fatal: refusing to merge unrelated histories` | Merging two repos with no common ancestor (common after `git init` + adding remote) | Use `git merge origin/main --allow-unrelated-histories` |
| `error: cannot rebase: You have unstaged changes` | Modified files exist when trying to rebase | `git stash` → `git rebase main` → `git stash pop` |
| `CONFLICT (modify/delete): file.txt deleted in HEAD and modified in feature` | One branch deleted a file while another modified it | Decide: keep the file (`git add file.txt`) or accept deletion (`git rm file.txt`), then `git commit` |
| `fatal: The current branch feature/x has no upstream branch` | Branch hasn't been pushed to remote yet | `git push --set-upstream origin feature/x` |
| `error: failed to push some refs... Updates were rejected because the tip of your current branch is behind` | Remote has newer commits than local | `git pull --rebase origin main` then `git push` |
| Accidentally merged wrong branch into main | Premature or incorrect merge | `git revert -m 1 <merge-commit-hash>` to undo the merge commit safely |

---

## Real-World Job Scenario

> **Scenario:** The team is preparing for a major release (v3.0). Three feature branches are in progress. A critical security vulnerability is reported in production (v2.9).

### Junior Action ❌
- Tries to push the security fix directly to `main` — blocked by branch protection
- Creates a fix on the `develop` branch — but that includes unreleased v3.0 features
- Asks to merge `develop` into `main` to include the fix — this would deploy unfinished features to production
- **Result:** Either the fix is delayed, or unfinished code reaches production

### Senior Action ✅
1. Creates a `hotfix/cve-2024-xxxx` branch from `main` (not from `develop`):
   ```bash
   git checkout main
   git pull origin main
   git checkout -b hotfix/cve-2024-xxxx
   ```
2. Makes the minimal security fix on this branch:
   ```bash
   # Fix the vulnerability
   vim src/auth/session.py
   git add src/auth/session.py
   git commit -m "security: patch CVE-2024-XXXX session hijacking"
   ```
3. Opens a PR against `main`, gets expedited review from the security team
4. After merge to `main`, tags the release:
   ```bash
   git checkout main && git pull
   git tag -a v2.9.1 -m "Hotfix: CVE-2024-XXXX"
   git push origin v2.9.1
   ```
5. **Crucially**, also merges the hotfix into `develop` to ensure v3.0 includes the fix:
   ```bash
   git checkout develop && git pull
   git merge hotfix/cve-2024-xxxx
   git push origin develop
   ```
6. Deletes the hotfix branch and documents the incident

*Senior engineer samajhta hai ki hotfix ka source hamesha `main` hoga — kyunki production `main` se deploy hai. `develop` se fix karna matlab unfinished code bhi saath mein le jaana. Pehle production fix karo, phir develop mein merge karo.*

---

## Interview Questions

### Q1: Compare Git Flow, Trunk-Based Development, and GitHub Flow. When would you choose each?
**Answer:** **Git Flow** uses `main` + `develop` as long-lived branches with `feature/`, `release/`, and `hotfix/` branches. Best for products with scheduled releases and long QA cycles (mobile apps, enterprise software). **Trunk-Based Development** uses only `main` — developers commit directly or via very short-lived branches (< 1 day), using feature flags to hide incomplete work. Best for teams with mature CI/CD doing continuous deployment. **GitHub Flow** uses `main` + feature branches with PR-based merging. It's simpler than Git Flow but more structured than Trunk-Based. Best for small teams, SaaS products, and open-source projects. I'd choose Git Flow for a banking app with quarterly releases, Trunk-Based for a cloud SaaS deploying 50 times/day, and GitHub Flow for a startup with 5 developers.

### Q2: When should you use `git merge` vs `git rebase`?
**Answer:** Use `merge` on shared/public branches (main, develop) because it preserves complete history and doesn't rewrite commits that others depend on. Use `rebase` on local feature branches before pushing to create a clean, linear history. The golden rule: **never rebase commits that have been pushed to a shared remote** — it rewrites commit hashes, causing conflicts for everyone who has pulled those commits. In practice, many teams use `git pull --rebase` for local sync and squash-merge for PRs.

### Q3: What is `git cherry-pick` and when would you use it in a real scenario?
**Answer:** `git cherry-pick <commit-hash>` applies a specific commit from one branch onto another without merging the entire branch. Real scenario: A developer fixed a critical bug on `feature/payments` (commit `abc1234`), but that feature branch isn't ready for release. You cherry-pick just the bug fix commit onto `main` to deploy it immediately: `git checkout main && git cherry-pick abc1234`. Another use case: backporting a fix from `main` to a `release/v2.x` maintenance branch.

### Q4: Explain CODEOWNERS and how it improves code quality in a DevOps team.
**Answer:** CODEOWNERS is a file (`.github/CODEOWNERS`) that maps file paths or patterns to GitHub users/teams who are automatically added as reviewers when a PR touches those paths. Example: `/terraform/ @infra-team` ensures any change to Terraform files requires infra team review. It improves code quality by: (1) ensuring domain experts review relevant changes, (2) preventing accidental infrastructure changes without proper review, (3) distributing review load across specialized teams, and (4) creating clear ownership accountability. In DevOps, this is critical — you don't want a frontend developer accidentally modifying Kubernetes manifests without SRE review.

### Q5: How would you squash the last 5 commits into one before creating a PR?
**Answer:** Use interactive rebase: `git rebase -i HEAD~5`. In the editor, change the first commit to `pick` and all subsequent ones to `squash` (or `s`). Save and close. In the next editor, write a combined commit message. Then force-push to your feature branch: `git push --force-with-lease origin feature/my-branch`. Use `--force-with-lease` instead of `--force` as a safety check — it fails if someone else has pushed to the branch since your last fetch. This is safe because you're only rewriting your own feature branch history, not shared branches.

---

## Related Notes

- [[00 DevOps Master Index]]
- [[GIT-01 Git Fundamentals]]
- [[GIT-03 GitHub Advanced]]
