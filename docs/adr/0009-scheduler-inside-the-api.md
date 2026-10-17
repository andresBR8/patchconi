# 0009. Periodic work inside the API with a PostgreSQL advisory lock

- Status: Accepted
- Date: 2026-10-16
- Deciders: maintainer

## Context

Some work is periodic: evaluating the patch policy, marking hosts that stopped reporting, sending alerts, pruning history. PatchConi runs on Docker Compose and on Kubernetes, possibly with several API replicas, and the machines involved are not always on.

## Decision

A scheduler inside the API process. Before running a job, a replica takes a PostgreSQL advisory lock, so only one replica runs it at a time. Jobs do not depend on running at an exact time: if one is missed because everything was switched off, the next run catches up.

The same mechanism works on Compose and on Kubernetes, tolerates shutdowns and is safe with several replicas.

## Alternatives considered

- **Kubernetes CronJob** — does not exist on Docker Compose, so Compose users would need a second mechanism.

## Consequences

- Positive: one implementation for every platform; no extra component to deploy.
- Positive: the lock makes horizontal scaling safe.
- Negative and trade-offs: periodic work shares resources with request handling; jobs must be idempotent.
- Follow-ups: policy engine and scheduler in phase 7.
