# Branch Protection Setup

Instructions for configuring branch protection rules on GitHub.

## Prerequisites

- Repository must be on GitHub (public or Pro/Team/Enterprise for private repos)
- You must be a repository administrator

## Configuration Steps

### 1. Navigate to Branch Protection

1. Go to your repository: `https://github.com/sq4ind/dockerized-directslave`
2. Click **Settings** (gear icon)
3. In the left sidebar, click **Branches** (under "Code and automation")
4. Click **Add branch protection rule** (or "Add classic branch protection rule")

### 2. Configure Rule for `main` Branch

**Branch name pattern:** `main`

### 3. Enable These Settings

#### Required Status Checks

- [x] **Require status checks to pass before merging**
- [x] **Require branches to be up to date before merging**

Add these required status checks:
- `Lint & Validate` (from ci.yml)
- `Build & Verify` (from ci.yml)
- `Security Scan` (from ci.yml)

#### Pull Request Reviews

- [x] **Require a pull request before merging**
  - Required approvals: `1` (or `0` if you're the sole maintainer)
- [x] **Dismiss stale pull request approvals when new commits are pushed**

#### Additional Protections

- [x] **Require conversation resolution before merging** (optional)
- [x] **Do not allow bypassing the above settings** (recommended for teams)
- [ ] **Require signed commits** (optional - adds complexity)

### 4. Save Changes

Click **Create** (or **Save changes**) to apply the rule.

## Auto-merge Configuration

For Dependabot auto-merge to work, you also need:

1. Go to **Settings** > **General**
2. Scroll to **Pull Requests** section
3. [x] Enable **Allow auto-merge**

This allows the auto-merge workflow (`.github/workflows/auto-merge.yml`) to function correctly.

## Verification

After setup, verify by:

1. Creating a test branch
2. Making a small change
3. Opening a PR to `main`
4. Confirming CI checks run automatically
5. Verifying merge is blocked until checks pass

## Notes

- **Dependabot PRs**: Will be auto-approved and auto-merged for patch/minor updates (after CI passes)
- **Major updates**: Will NOT be auto-merged - require manual review
- **Your own PRs**: Will require CI to pass before merge (you can self-approve if sole maintainer)
- **Direct pushes to main**: Will be blocked (must go through PR)
