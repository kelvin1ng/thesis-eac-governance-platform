# Branch protection and required status checks

**Reference:** CHAPTER3_REFERENCE.md §3.5 Change Flows, §3.6 Table 3 (Threat 1 & 2), supply-chain hardening.

GitHub does not store branch protection rules in the repository; they must be configured in the repository settings (or via API). Configure the following so that PR checks and CODEOWNERS enforce Path A/B and Table 3 preventive controls.

---

## 1. Protected branches (Table 3 — Unauthorized manifest change)

- **Branches:** `main`, and any release branch (e.g. `release/*`).
- **Require a pull request before merging**
  - Required approvals: **1** (or more per org).
  - Dismiss stale reviews when new commits are pushed: **Yes** (recommended).
- **Require status checks to pass before merging**
  - Require branches to be up to date: **Yes** (recommended).
  - Status checks that must pass (from `.github/workflows/pr-checks.yaml` and Path B workflow):
    - `gosec`
    - `conftest-manifests`
    - `trivy-config`
    - `conftest-policies` (when Path B workflow runs)
  - Or require the single check **PR Checks** / **Path B — Policy Check** if your workflow names differ.
- **Require conversation resolution before merging:** optional.
- **Do not allow bypassing the above settings:** enforce for administrators (recommended).
- **Restrict who can push to matching branches:** only allow pushes via PR (no direct push to `main`).

---

## 2. CODEOWNERS (Table 3 — Unauthorized pipeline change)

CODEOWNERS are defined in the repo:

- **Root:** `CODEOWNERS` and `.github/CODEOWNERS`
- **policies/** and **pipelines/:** require review from `@thesis-platform-owners` and `@security-owners` (Path B) [50].

In GitHub:

- **Settings → Code owners →** Enable **Require a review from Code Owners** if you use CODEOWNERS as required reviewers.
- Ensure the teams/users `thesis-platform-owners` and `security-owners` exist (or replace with your org’s teams in `CODEOWNERS`).

---

## 3. Signed commits and tags (Table 3 — Supply chain)

- **Require signed commits:** optional but recommended; enable in branch protection if available.
- **Require signed tags for release:** enforce via process or tag protection; not all hosts support this in the UI.

---

## 4. Summary

| Control              | Where to configure        | Purpose                          |
|----------------------|---------------------------|----------------------------------|
| Protected branches   | Repo Settings → Branches  | Block direct push to main        |
| Required status checks | Branch protection rules | gosec, conftest, trivy must pass |
| CODEOWNERS           | `CODEOWNERS` + GitHub     | Path B: policies/pipelines review |
| Required approvals   | Branch protection        | Mandatory PR review [51]         |

After configuration, Path A (firewall code) requires **PR + status checks (gosec, conftest-manifests, trivy-config)**; Path B (policies/pipelines) additionally requires **CODEOWNERS review** and runs **Path B — Policy Check** when those paths change.
