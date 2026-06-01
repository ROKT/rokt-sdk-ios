# Agent guidelines

## Review guidelines

When reviewing PRs that touch this repo or downstream services, apply these
severity levels.

### P0 — block merge

- Hardcoded secrets or credentials (API keys, tokens, passwords, DB URIs)
- SQL string interpolation or concatenation (use parameterised queries only)

### P1 — strongly recommend fixing before merge

- Real customer PII in code or tests (names, emails, phone numbers, IP addresses — including hashed)
- `aws_iam_policy_attachment` Terraform resource (use `aws_iam_role_policy_attachment`)
- AI/ML Helm services using `Service.type: LoadBalancer` without internal annotation
- Missing input validation or sanitisation at API boundaries
- HTML/template rendering without escaping all 5 special chars (`<` `>` `"` `'` `&`)
- `VARCHAR` for user-visible strings in SQL Server (use `NVARCHAR`)
- `varchar`/`utf8` charset for user-visible strings in MySQL (use `utf8mb4`)
- Redis clients without DNS TTL re-resolution
- Submit buttons with no disabled state during async operations
- UI navigation hiding used as sole access control (no backend auth check)
- K8s Deployments/Services missing `service-type: internal|edge|public` label
