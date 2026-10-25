# Threat model

> Status: v1 (phase 1). It covers the design for v0.1.0; none of the components exists yet. It is reviewed when each phase closes, and the [revision log](#revision-log) records what changed.

What can go wrong with PatchConi, what the design does about it, and what it deliberately does not. It uses a light version of [STRIDE](#method): each trust boundary is checked for spoofing, tampering, repudiation, information disclosure, denial of service and elevation of privilege. The components and connections are the ones in the [architecture](architecture.md).

## Method

- Threats are listed per trust boundary, each with one STRIDE category: the one that names the attacker's goal.
- A mitigation always links to the document that defines it (an ADR, an acceptance criterion, the protocol or the domain model). This file does not repeat those rules.
- Every threat has one of these statuses:
  - **By design**: the rule is decided and written down. When it is not built yet, the phase that builds it is named, for example *by design (phase 4)*.
  - **Planned (phase N)**: the mitigation is chosen, the details are decided in that phase.
  - **Accepted risk**: PatchConi does not mitigate it, and [accepted risks](#accepted-risks) says why.
  - **Issue #N**: no mitigation is decided yet. The issue holds the question until it is.

## Assets

| Asset | Why it matters |
| --- | --- |
| Fleet state: hosts, pending updates, security advisories, kernels, reboot status | A list of which machines are vulnerable and to what. The most sensitive thing PatchConi holds. |
| Compliance history: episodes, state transitions, reports | Evidence for an audit; worthless if it can be edited after the fact. |
| Agent tokens | Let someone write reports as a host. |
| User credentials and sessions | Give access to the fleet state and, for an administrator, to enrollment and tokens. |
| Server HMAC key | Used to store agent tokens as keyed hashes ([domain model, invariant 4](product/domain-model.md#invariants-and-backend-rules)). |
| Webhook secret | Lets a receiver trust that an alert came from PatchConi. |
| Policy and exceptions | Decide which hosts are *out of policy*. |
| The agent binary | Runs on every monitored host. |

## Actors

| Actor | Can do | Trusted for |
| --- | --- | --- |
| Administrator | Enroll, rotate, revoke, retire, manage users | Everything in the UI |
| Viewer | Read the fleet and its history | Reading only |
| Operator | Deploys PatchConi; sets its configuration, policy and Secrets | Everything. Attacks by the operator are [out of scope](#out-of-scope) |
| Legitimate agent | Report its own host's state | Its own host's data only |
| Compromised host | Anything a legitimate agent can do, with any content | Nothing beyond its own data |
| Holder of a stolen agent token | Send reports as that host | Nothing |
| Network attacker | Watch or change traffic between the components | Nothing |
| Someone with a copy of the database or a backup | Read every table | Nothing |
| Webhook receiver | Read the alerts it is sent | The alert content |
| Compromised upstream | A dependency, an action or a data source PatchConi builds from | Nothing |

## Trust boundaries

| ID | Boundary | What crosses it |
| --- | --- | --- |
| TB-1 | Monitored host → API | Agent reports, with a bearer token |
| TB-2 | Browser → web and API | The SPA, JSON requests, a session cookie |
| TB-3 | API → PostgreSQL | Every stored fact, token hashes, sessions |
| TB-4 | API → webhook receivers | Alerts, signed with HMAC |
| TB-5 | Release build → lifecycle data and dependencies | The lifecycle table snapshot, packages, actions, base images |

TB-1 and TB-2 both pass through the reverse proxy, which terminates TLS. Everything behind the proxy (proxy to API and web, API to PostgreSQL) runs on the platform's network: see [out of scope](#out-of-scope).

## Threats

### TB-1: monitored host → API

| ID | STRIDE | Threat | Mitigation | Status |
| --- | --- | --- | --- | --- |
| T-01 | Tampering | **A compromised host lies about its packages** and reports that it is up to date. | None is possible from the report alone: see [accepted risks](#t-01-a-compromised-host-can-lie). | Accepted risk |
| T-02 | Spoofing | Someone with a stolen agent token sends reports from another machine, or from a copy of the host. | Identity rules: machine fingerprint, agent instance and sequence, with alerts on `fingerprint_mismatch` and `superseded_instance`, and recovery by token rotation ([protocol](product/protocol.md#ordering-and-identity), [domain model, invariant 1](product/domain-model.md#invariants-and-backend-rules)). Limit: a clone that keeps `/etc/machine-id` and the agent's state directory is not detected ([accepted risks](#t-02-a-full-clone-is-not-detected)). | By design (phase 4); clone: accepted risk |
| T-03 | Elevation of privilege | An agent token is used against the user API. | **An agent token is valid only for `POST /api/v1/agent/reports`**; on any other route it is `401`, and the user API accepts only a session ([protocol, transport](product/protocol.md#transport)). A leaked token can at most write reports for one host. | By design (phase 4) |
| T-04 | Tampering | A host writes data for another host. | The host is taken from the token, never from the report body: there is no host ID in the report ([ADR 0006](adr/0006-per-host-agent-tokens.md), [report schema](../protocol/v1/report.schema.json)). | By design (phase 4) |
| T-05 | Elevation of privilege | A report carries HTML or script in a package name, version or error message (stored XSS), which runs with the session of whoever opens the dashboard. | Every value in a report is untrusted text: stored as data, never interpreted, escaped by the web, never rendered as HTML or Markdown ([protocol, untrusted text](product/protocol.md#untrusted-text)); strict schema with maximum lengths ([ADR 0022](adr/0022-report-schema-first.md)). | By design (phases 4 and 6) |
| T-06 | Denial of service | A host or a token holder floods the API or sends huge reports. | 1 MiB limit, no `Content-Encoding` (no decompression bombs), `429` per token, list sizes capped by the schema ([protocol, transport](product/protocol.md#transport), AC-2.3). | By design (phase 4) |
| T-07 | Information disclosure | The agent token leaks on the network or in logs. | HTTPS only, with certificate verification ([protocol, transport](product/protocol.md#transport)); tokens never logged and carry a prefix secret scanners can match ([ADR 0006](adr/0006-per-host-agent-tokens.md), [SECURITY.md](../SECURITY.md#scope)). On the host, the token file is readable only by the agent's user (`0600`). | By design; token file: planned (phase 5) |
| T-23 | Tampering | A compromised host reports false advisory dates to move the policy clocks of other hosts. | Advisory references belong to one host and one candidate; there is no shared advisory table ([domain model, entities](product/domain-model.md#stored-in-the-database)). A false date only changes the lying host's own clocks, which T-01 already covers. Dates later than the server's receive time are ignored ([policy](product/policy.md#how-pending-since-is-set)). | By design (phase 4) |
| T-24 | Information disclosure | A report leaks a secret from the host, such as credentials in a repository URL. | The agent removes credentials from URLs in `packages.error.message` before sending ([protocol, untrusted text](product/protocol.md#untrusted-text)). The agent fills `repository` with the apt suite or the dnf repository ID, never a URL ([report schema](../protocol/v1/report.schema.json)); the schema's pattern does not reject a URL yet: [issue #39](https://github.com/andresBR8/patchconi/issues/39). | By design (phase 5); schema pattern: [issue #39](https://github.com/andresBR8/patchconi/issues/39) |

### TB-2: browser → web and API

| ID | STRIDE | Threat | Mitigation | Status |
| --- | --- | --- | --- | --- |
| T-08 | Information disclosure | **The dashboard is a map of vulnerable hosts.** Exposed to the internet, or seen by the wrong person, it tells an attacker which machines to attack and with what. | Every page and every user API route needs a session; there are no anonymous views. `/metrics` is never routed through the public Ingress ([platform contract §3](platform-contract.md#3-health-and-metrics-endpoints)). Exposure guidance: only `/api/v1/agent/` is reachable from the hosts' networks; the UI and the user API stay internal or behind a VPN, and the proxy separates them by path ([architecture, exposure](architecture.md#exposure)). The Kustomize base has to allow that split: [issue #38](https://github.com/andresBR8/patchconi/issues/38). Browser-side hardening is in [issue #32](https://github.com/andresBR8/patchconi/issues/32). | Planned (phases 2 and 3); separate agent path: [issue #38](https://github.com/andresBR8/patchconi/issues/38); hardening: [issue #32](https://github.com/andresBR8/patchconi/issues/32) |
| T-09 | Spoofing | Someone guesses a password, steals a session or makes a logged-in browser send a request (CSRF). | Better Auth with email and password and a cookie session ([ADR 0005](adr/0005-better-auth-for-users.md)); failed logins rate-limited (AC-5.3); no default passwords (AC-5.1). Cookie flags, CSRF protection and security headers: [issue #32](https://github.com/andresBR8/patchconi/issues/32). | Planned (phase 3); cookie and CSRF: [issue #32](https://github.com/andresBR8/patchconi/issues/32) |
| T-10 | Elevation of privilege | A viewer changes something. | Every write request from a viewer returns `403` (AC-5.2), tested end to end. | Planned (phase 3) |
| T-11 | Repudiation | An administrator rotates a token, retires a host or clears an agent alert, and later nobody can tell who did it. | Reports are stored with their body hash and the server's receive time, and history only grows ([domain model, invariant 3](product/domain-model.md#invariants-and-backend-rules)). Creating hosts and tokens, retiring hosts and revoking tokens record who did it (`created_by`, `retired_by`, `revoked_by`), and users are never deleted, so those records survive ([domain model, entities](product/domain-model.md#stored-in-the-database)). Other actions (clearing an agent alert, managing users, logins) have no record yet: [issue #33](https://github.com/andresBR8/patchconi/issues/33). | Reports: by design (phase 4); admin actions: [issue #33](https://github.com/andresBR8/patchconi/issues/33) |
| T-22 | Tampering | Someone relaxes the policy or adds exceptions to hide hosts that break it. | The policy and its exceptions are code, read from the configuration and reviewed in the operator's repository, never changed in the UI ([ADR 0019](adr/0019-patch-policy-as-code.md)); each state transition keeps `policy_fingerprint` and `applied_exceptions`; exceptions last 90 days at most by default ([domain model, exceptions](product/domain-model.md#exceptions)); the UI shows the active policy and where each value comes from (AC-6.2). | By design (phases 6 and 7) |

### TB-3: API → PostgreSQL

| ID | STRIDE | Threat | Mitigation | Status |
| --- | --- | --- | --- | --- |
| T-12 | Information disclosure | A copy of the database or a backup leaks. | Agent tokens are stored only as keyed hashes ([domain model, invariant 4](product/domain-model.md#invariants-and-backend-rules)) and user passwords are hashed by Better Auth, so the leak gives no working credentials. **The fleet state itself does leak**: [accepted risks](#t-12-the-fleet-state-leaks-with-the-database). Separate database roles for migrations and for the running API: [issue #34](https://github.com/andresBR8/patchconi/issues/34). | Credentials: by design (phases 3 and 4); fleet data: accepted risk; roles: [issue #34](https://github.com/andresBR8/patchconi/issues/34) |
| T-13a | Information disclosure | The server HMAC key leaks. | Low impact. The key alone reveals no token. With the key and a copy of the database, an attacker can test guesses offline, but tokens are random with high entropy, so guessing is infeasible. The key should still be rotated after a leak (`hmac_key_id` allows it). How it is supplied and rotated, and whether it is worth having at all: [issue #31](https://github.com/andresBR8/patchconi/issues/31). | [Issue #31](https://github.com/andresBR8/patchconi/issues/31) |
| T-13b | Denial of service | The server HMAC key is lost. | Every agent token stops working at once, and every host has to be given a new token. Backing up the key and recovering from its loss: [issue #31](https://github.com/andresBR8/patchconi/issues/31). | [Issue #31](https://github.com/andresBR8/patchconi/issues/31) |

### TB-4: API → webhook receivers

| ID | STRIDE | Threat | Mitigation | Status |
| --- | --- | --- | --- | --- |
| T-14 | Elevation of privilege | **Server-side request forgery (SSRF):** a webhook URL pointing at the internal network or a cloud metadata endpoint makes the API send requests there on someone's behalf. | The risk depends on who sets the URL. **The webhook URL and its secret come from the configuration, never from the UI** (AC-6.5 in the [vision](product/vision.md#policy-and-alerts-important-uc-6-uc-9), as the policy does in [ADR 0019](adr/0019-patch-policy-as-code.md)), so changing them needs operator access, which is [out of scope](#out-of-scope). Defense in depth: no redirects followed, connect and response timeouts, and egress limited by the platform's NetworkPolicy. Recorded in [issue #30](https://github.com/andresBR8/patchconi/issues/30). | Planned (phase 7): [issue #30](https://github.com/andresBR8/patchconi/issues/30) |
| T-15 | Spoofing | Someone sends a forged alert to a receiver, or replays a captured one. | HMAC-SHA256 over a timestamp and the body, in their own headers; the documented receiver check rejects a bad signature and any message older than 5 minutes (AC-6.4). | By design (phase 7) |
| T-16 | Information disclosure | Alerts carry host names and states to a third-party service (a chat, a ticketing system). | Keep the payload to what the receiver needs to act; what exactly goes in it is part of [issue #30](https://github.com/andresBR8/patchconi/issues/30). | [Issue #30](https://github.com/andresBR8/patchconi/issues/30) |
| T-25 | Spoofing | A stolen token in use (T-02) goes unnoticed, because agent alerts (`fingerprint_mismatch`, `superseded_instance`) are only shown in the UI. | Whether an agent alert also sends a webhook is open in the [domain model](product/domain-model.md#invariants-and-backend-rules): [issue #36](https://github.com/andresBR8/patchconi/issues/36). | [Issue #36](https://github.com/andresBR8/patchconi/issues/36) |

### TB-5: release build → lifecycle data and dependencies

| ID | STRIDE | Threat | Mitigation | Status |
| --- | --- | --- | --- | --- |
| T-17 | Tampering | The lifecycle table snapshot is wrong or tampered with, so a supported operating system shows *out of policy*, or an unsupported one does not. | The snapshot is taken at build time, never queried at run time, and its date is shown in the UI and the API ([policy, unsupported operating systems](product/policy.md#unsupported-operating-systems)). How it is fetched, checked and reviewed: [issue #35](https://github.com/andresBR8/patchconi/issues/35). | [Issue #35](https://github.com/andresBR8/patchconi/issues/35) |
| T-18 | Tampering | A compromised dependency, action, base image or release. **The agent binary runs on every monitored host, so a malicious agent release is the path with the highest impact.** | Signed images with SBOM and provenance ([ADR 0010](adr/0010-signed-images-and-releases.md)). **Agent releases only carry checksums** from the same release, which the install script verifies: they detect a corrupted download, not a malicious release published from a compromised CI or account. Signing agent releases: [issue #37](https://github.com/andresBR8/patchconi/issues/37). The agent runs as an unprivileged user, which limits what a malicious release can do (T-20). Toolchain and dependency rules: [ADR 0017](adr/0017-mise-paranoid-toolchain.md), [ADR 0018](adr/0018-supply-chain-policy.md), [ADR 0020](adr/0020-pre-commit-hooks-as-pinned-binaries.md). | Images: by design (phase 8); agent signing: [issue #37](https://github.com/andresBR8/patchconi/issues/37) |

### On the host

| ID | STRIDE | Threat | Mitigation | Status |
| --- | --- | --- | --- | --- |
| T-19 | Elevation of privilege | The server, or someone who controls it, makes agents run commands on the hosts. | The agent is read-only: it never installs packages and never runs commands received from the server, and the host always opens the connection; breaking either rule is a vulnerability ([SECURITY.md](../SECURITY.md#scope), [ADR 0007](adr/0007-agent-in-go.md)). The response to a report carries nothing the agent acts on besides the retry rules ([protocol](product/protocol.md#responses-and-what-the-agent-does)). | By design (phase 5) |
| T-20 | Elevation of privilege | A bug in the agent, or a malicious release, becomes root on the host. | The agent runs as a dedicated unprivileged user, to be validated in phase 5 ([vision](product/vision.md#requirements-from-other-peoples-environments), [ADR 0007](adr/0007-agent-in-go.md)). | Planned (phase 5) |

### Later

| ID | STRIDE | Threat | Mitigation | Status |
| --- | --- | --- | --- | --- |
| T-21 | Elevation of privilege | The optional AWX or Ansible Automation Platform integration stores a token that can cause changes on hosts. | A dedicated account whose only permission is to run one job template, and its own ADR when it is built, because it changes this model ([roadmap](product/roadmap.md#designed-now-built-later)). | Later (after v0.1.0) |

## Accepted risks

### T-01: a compromised host can lie

PatchConi trusts what each agent declares about its own host. A host whose root account is compromised can run a modified agent, or edit the package database, and report that it is up to date. No self-reporting agent can prevent this: the evidence and the liar are the same machine. Detecting it needs something outside the host, such as a network vulnerability scanner or an image built from a known state.

What the design does: a lying host can only change its own data (T-04, T-23), never other hosts or the server (T-05, T-06), and stale or missing reports are flagged by the policy (*no data*, old metadata). These catch honest failures, not a deliberate liar. The dashboard shows what hosts *say*, and the documentation says so.

### T-02: a full clone is not detected

A copy of a host that keeps `/etc/machine-id` and the agent's state directory has the same fingerprint, instance and sequence counter, so its reports are indistinguishable from the original's ([protocol, limits](product/protocol.md#ordering-and-identity)). Telling them apart needs a secret the clone cannot copy: a key that cannot be exported, such as one held in a TPM, which is out of reach for a small, unprivileged agent. mTLS alone does not help, because a disk clone copies the client certificate's private key too; mTLS with the key in a TPM would. Accepted for v1; mTLS is a candidate for v2 ([ADR 0006](adr/0006-per-host-agent-tokens.md)).

### T-12: the fleet state leaks with the database

PatchConi does not encrypt the fleet state at the application level: the API has to read it to evaluate the policy, so the key would sit next to the data. Protecting the database, its volumes and its backups (encryption at rest, access control) is the platform's job.

## Out of scope

- **The platform**: networks, TLS between the proxy and the services, the database server and its backups, Secrets, NetworkPolicy and the Ingress controller. The [platform contract](platform-contract.md) lists what PatchConi requires from it.
- **The operator**: whoever sets the configuration, the policy and the Secrets is trusted with everything. Problems that need root on the PatchConi server or an administrator account are out of scope, as in [SECURITY.md](../SECURITY.md#scope).
- **Vulnerabilities in third-party dependencies** with no impact on PatchConi: reported upstream.
- **The monitored hosts' own security**, beyond what the agent does there (T-19, T-20, T-24).

## Revision log

| Date | Phase | Change |
| --- | --- | --- |
| 2026-10-25 | 1 | First version: assets, actors, five trust boundaries, threats T-01 to T-25 with their status, three accepted risks. Issues #30 to #39. |
