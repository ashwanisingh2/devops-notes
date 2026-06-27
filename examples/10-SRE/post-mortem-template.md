# Incident Post-Mortem Report

**Date of Incident:** YYYY-MM-DD
**Incident Commander:** [Name]
**Severity Level:** SEV-X
**Time to Detect (MTTD):** XX minutes
**Time to Mitigate (MTTR):** XX hours

## 1. Executive Summary
Briefly explain what happened, why it happened, and the customer impact (in simple non-technical terms).

## 2. Timeline
- 10:00 AM - Bad code deployed to production.
- 10:05 AM - Datadog alerts fired (CPU at 100%).
- 10:10 AM - Incident declared. War room assembled.
- 10:15 AM - Rollback initiated (Mitigation).
- 10:20 AM - System stabilized. Incident closed.

## 3. Root Cause Analysis (5 Whys)
1. **Why did the API crash?** The DB ran out of connections.
2. **Why did it run out of connections?** A new un-indexed query was doing full table scans.
3. **Why did the un-indexed query go to production?** The code was pushed directly to the `main` branch.
4. **Why was code pushed directly?** Branch protection rules were disabled on GitHub.
5. **Why were they disabled?** A junior admin temporarily disabled it during an emergency last week and forgot to turn it back on.

## 4. What Went Well?
- Datadog monitoring caught the issue within 5 minutes.
- The rollback process was smooth and executed perfectly.

## 5. What Went Wrong?
- Branch protection was manually disabled without tracking.
- The database didn't have auto-scaling enabled for connections.

## 6. Action Items (To prevent recurrence)
| Ticket ID | Description | Owner | Priority |
|-----------|-------------|-------|----------|
| SEC-101   | Enforce branch protection via Terraform (IaC) so it can't be manually toggled. | Bob | P1 |
| DBA-202   | Set up Datadog alerts for DB connection pools > 80%. | Alice | P2 |
