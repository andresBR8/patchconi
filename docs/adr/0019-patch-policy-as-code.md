# 0019. Patch policy as code, read-only in the UI

- Status: Accepted
- Date: 2026-10-24
- Deciders: maintainer

## Context

The [patch policy](../product/policy.md) decides which hosts are *out of policy*: every alert, metric and compliance answer depends on its thresholds. A change to a threshold can turn a red fleet green without patching anything. Auditors and reviewers need to know which policy was in force and who changed it. PatchConi is deployed with Docker Compose or Kustomize, where configuration already lives in versioned files and environment variables.

## Decision

The policy is configuration. The server reads it at startup from a file that can be kept in version control, and every setting can be overridden by an environment variable (precedence: environment variable, then file, then the documented defaults). The web UI and the API show the active policy, read-only, with the source of each value; no request can change it.

The file format and variable names are defined in phase 7, when the policy engine is built.

## Alternatives considered

- **Thresholds edited in the web UI and stored in the database** — the original plan (phase 6, "policy settings"). A change takes effect without review and leaves no history outside PatchConi, and an administrator account becomes enough to hide a breach. It also needs an audit log and a settings screen to get back what git already gives.
- **Both: a file with UI overrides** — two sources of truth, and the UI one silently wins.

## Consequences

- Positive: every policy change is a reviewed diff with history (git, GitOps); the same policy can be applied to several installations; the UI cannot be used to relax it.
- Negative and trade-offs: changing a threshold needs access to the deployment and a restart, not a click; people without access to the configuration cannot experiment with values.
- Follow-ups: phase 6 shows the policy read-only instead of a settings screen; phase 7 defines the file format, the variable names and whether a reload without restart is worth it.
