# 0007. Read-only agent in Go, started by a systemd timer

- Status: Accepted
- Date: 2026-10-16
- Deciders: maintainer

## Context

The agent runs on every monitored host, across several distributions (Debian/Ubuntu with `apt`, RHEL family with `dnf`). It must collect pending updates reliably, never change the system, ideally run without root, and survive hosts that are switched off.

## Decision

The agent is written in Go and runs from a systemd timer with a randomized delay. It is read-only: it never installs packages and never runs commands received from the server.

It is meant to run as an unprivileged user. That is a hypothesis of the plan, not something verified yet: the agent would only read the package metadata that the distribution's own timers already refresh (`apt-daily` on Debian and Ubuntu, `dnf-makecache` on the RHEL family), without refreshing it itself. Phase 5 validates it on Ubuntu and Rocky. If the agent turns out to need root, that is a new ADR.

- One static binary works across distributions without a runtime to install.
- Parsing of `apt` and `dnf` output is ordinary code that can be unit-tested with golden files captured from real systems.
- Go is the language of the Kubernetes ecosystem, which fits the project's operators and the maintainer's learning goals.

## Alternatives considered

- **A Bash script** — quick to start, but fragile across distributions and versions, and its parsing is hard to test.

## Consequences

- Positive: one binary per architecture, packaged as `.deb` and `.rpm`; testable collectors.
- Positive: a timer instead of a daemon: nothing runs between reports, and missed runs after a shutdown are fine.
- Negative and trade-offs: a second language and toolchain in the project; Go is new to the maintainer.
- Follow-ups: collectors, packaging and a distribution matrix in phase 5, including the check that the agent works without root. Changing the read-only rule, or running as root, needs a new ADR.
