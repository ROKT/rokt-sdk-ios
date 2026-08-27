# Deterministic approval for safe changes

## Why this exists

AI review agents are useful advisory reviewers, but their availability and review output
are not a stable merge-control mechanism for a public repository. This workflow uses
GitHub's own pull request metadata and an explicit, versioned policy to approve a small
class of low-risk changes after the existing `Pull Request` workflow succeeds.

External contributors still require a human approval. The automation does not replace a
code-owner approval on files that have a code owner.

## Repository settings

The workflow relies on these repository settings, which are enabled in this repository:

- Actions default workflow permission: **Read and write permissions**
- **Allow GitHub Actions to create and approve pull requests**: enabled
- Public-fork workflow approval policy: **Require approval for first-time contributors**
- The `main` ruleset requires one approval, dismisses stale approvals after a push,
  requires code-owner approval where a code owner matches, requires review-thread
  resolution, and requires an extra approval for unattributed changes. It does not
  require last-push approval

The workflow still declares only `contents: read` and `pull-requests: write`; it does not
inherit every permission available to the repository's default token.

## Exact eligibility policy

The versioned settings live in [`.github/safe-change-approval.json`](safe-change-approval.json).
A pull request is approved only when every condition below is true:

1. The existing `Pull Request` workflow completed successfully for the current head SHA.
2. The pull request is open, not a draft, and targets `main`.
3. The author is `dependabot[bot]`, or is a human account whose GitHub author association
   is `OWNER`, `MEMBER`, or `COLLABORATOR`. Other bots must be added explicitly.
4. The author is not `github-actions[bot]`, because a review cannot approve its own pull
   request.
5. Every changed file is one of `README.md`, `MIGRATING.md`, or `MONOREPO.md`, or is a
   Markdown file below `docs/` or `documentation/`.
6. Every file is added or modified. Renames, copies, and deletions require human review.
7. The diff changes no more than 20 files and no more than 1,000 total lines.
8. The REST API returns metadata for exactly the number of files reported by the pull
   request.
9. Each changed path is a regular Git file with a textual patch. Symlinks, submodules,
   binary payloads, and truncated tree responses fail closed.

Anything missing, malformed, stale, or outside the allowlist is rejected without an
approval. Workflow files, `CODEOWNERS`, the policy itself, source, build configuration,
dependencies, release notes, security policy, and agent instructions are not eligible.

## Public-repository security model

The approval workflow is triggered by `workflow_run`, so GitHub loads and runs it from
the default branch with a write-capable token only after the unprivileged PR workflow
finishes. It checks out only the approval policy and evaluator from the trusted default
branch. It never checks out, imports, or executes code from the pull request.

The current PR head SHA is fetched again immediately before approval and compared with
the SHA that passed validation. A later push invalidates the decision; the `main` ruleset
also dismisses the old approval, and the new commit must pass the workflow and policy
again.

## Rollout and verification

GitHub only runs a new `workflow_run` workflow after that workflow exists on the default
branch. Consequently, the implementation PR cannot approve itself. After it is merged:

1. Ensure documentation paths that should use this approval are not covered by the
   catch-all `CODEOWNERS` rule. Files with a matching code owner still require that
   owner's approval.
2. Open a small `README.md` pull request from a repository member.
3. Confirm the `Pull Request` workflow succeeds.
4. Confirm `Approve Safe Changes` approves the same commit as `github-actions[bot]`.
5. Push another safe documentation commit and confirm the stale approval is dismissed,
   then recreated only after the new validation run succeeds.
6. Open or draft an external-fork documentation PR and confirm no approval is submitted.

If this policy is later shared across SDK repositories, prefer a centrally maintained
reusable workflow or dedicated GitHub App. Keep the per-repository allowlist local so
each SDK explicitly defines what it considers safe.
