# Product vision

> Status: draft (phase 1). Thresholds, the support matrix and the acceptance criteria may change until the phase is approved.

## The problem

Small teams run Linux servers they cannot watch one by one. Updates arrive every day, unattended upgrades fail silently, a host is left out of the patch run, a kernel is installed but never booted. Nobody notices until an audit or an incident asks: *which hosts are behind, on what, and since when?*

Large tools answer that question (configuration management suites, commercial vulnerability scanners), but they cost money, need agents with root, or open inbound access to every host. Small fleets need a smaller answer.

## Vision

PatchConi is a self-hosted, read-only patch compliance dashboard for small Linux fleets. A small agent on each host reports what updates are pending; the server shows which hosts are behind, since when, and which ones break the patch policy.

It **observes and never acts**: it does not install updates, it does not run commands it receives, and the server never connects to the hosts. That is what makes it safe to install on machines that matter.

## Who it is for

**Sam, sysadmin at a small company.** Runs 10–200 Linux servers (a mix of Ubuntu, Debian and RHEL-family), alone or in a team of two or three. Patching is one job among many. Needs to know every morning which hosts need attention, and to answer an auditor or a customer questionnaire with evidence. The servers sit behind an HTTPS proxy and most of them have no direct internet access.

**Alex, homelab operator.** Runs 5–30 machines: VMs, a NAS, a couple of single-board computers. Some are switched off at night or for weeks. Wants to see at a glance what is behind without logging into each machine, and does not want a tool that needs a server running 24/7 to stay correct.

**Robin, reviewer.** An auditor, a manager or a colleague from another team. Never changes anything. Needs read-only access to see the state of the fleet and its history, and to trust that the numbers mean what the policy says.

## Use cases

| ID | Persona | Use case |
| --- | --- | --- |
| UC-1 | Sam, Alex | Enroll a new host: create it in the UI, copy a one-time token, install the agent. |
| UC-2 | Sam, Alex | See the fleet at a glance: how many hosts are up to date, have pending updates, are out of policy or have no data. |
| UC-3 | Sam | Find the hosts that break the patch policy and why (which updates, since when). |
| UC-4 | Sam, Alex | Open one host: pending updates (security first), running and installed kernel, reboot required, last boot, last report. |
| UC-5 | Robin | Check the state of a host or the fleet on a past date (history). |
| UC-6 | Sam | Get a notification when a host starts breaking the policy, once, not every hour. |
| UC-7 | Sam | Rotate or revoke a host's token after a leak or when the host is retired. |
| UC-8 | Alex | Switch hosts off for days without being paged for it, and see their real state again when they come back. The policy clocks keep running while a host is off: an update left pending still counts. |
| UC-9 | Sam | Adjust the policy thresholds to match the organization's own rules. |
| UC-10 | Sam | Feed fleet-level numbers to an existing Prometheus and Grafana. |

## What PatchConi is not, and how it fits

### Other tools already do part of this

Being read-only is not, on its own, what makes PatchConi different (features as described in each project's README, October 2026):

- [Patchman](https://github.com/furlongm/patchman) (GPL-3.0) is read-only too: its clients send the list of installed packages and enabled repositories, and the server works out which updates each host needs and whether they are security updates. It does not install updates.
- [PatchMon](https://github.com/PatchMon/PatchMon) (AGPLv3) also uses agents that only connect outwards. It goes further than monitoring: it can apply updates after a preview and an approval, opens SSH terminals from the browser, and runs OpenSCAP CIS benchmarks and Docker Bench.

Both are mature projects worth considering. PatchConi aims at a narrower problem, with a different source of truth.

### What PatchConi focuses on

1. **Compliance with a patch SLA.** The question is not only "what is pending" but "for how long, against which declared policy". Every pending update has a *pending since* date; the [policy](policy.md) turns ages into states. Exposure time and exceptions that expire are designed now and built later (see the [roadmap](roadmap.md#designed-now-built-later)).
2. **The host's own package manager is the source of truth.** The agent asks `apt` or `dnf` on the host what it would update, so private repositories, pins, held packages and local configuration are taken into account. The server does not resolve updates on its own copy of the repositories.
3. **Read-only as a guarantee you can check**, not a promise. This is the design target; none of it exists until the agent and the first release are built:
   - the agent will run without root (the target in [ADR 0007](../adr/0007-agent-in-go.md), to be confirmed in phase 5);
   - `--dry-run` will print the exact report the agent would send;
   - the server will store no credentials for the hosts and will have no way to run anything on them (the only planned exception is an optional AWX/AAP integration, which needs its own ADR: see the [roadmap](roadmap.md#designed-now-built-later));
   - releases will be signed, with an SBOM and provenance ([ADR 0010](../adr/0010-signed-images-and-releases.md)).
4. **Cloud-native operation.** Policy as code, Prometheus metrics, an OpenAPI contract, and deployment with Docker Compose or Kustomize.

### PatchConi does not patch

It works with whatever already patches the fleet (unattended upgrades, Ansible, AWX), and tells you whether patching actually happened. Remediation through integrations is in the [roadmap](roadmap.md#designed-now-built-later). A patching module inside PatchConi was considered and rejected for v1: a server that can change every host is the most valuable target in the fleet, and that breaks the read-only principle in [ADR 0007](../adr/0007-agent-in-go.md).

### Out of scope

These are out of scope for PatchConi, not just for v0.1.0:

- **Installing updates or running commands on hosts.** Changing this needs an ADR.
- **Remote terminals, and inbound connections to hosts.** The host always starts the connection.
- **CIS benchmark or container image scanning.** Other tools do this well.
- **Windows and macOS.**
- **Multi-tenant SaaS.** One installation serves one organization.

Features planned for later releases are in the [roadmap](roadmap.md).

## MVP acceptance criteria (v0.1.0)

Each criterion must be demonstrable with a test or a command. Sections marked *Important* move to v0.2.0 if the schedule slips.

### Host enrollment and tokens (UC-1, UC-7)

- AC-1.1 An administrator creates a host; the UI shows its token **once**. Reloading the page does not show it again.
- AC-1.2 The database stores only a hash of the token. The token has an identifiable prefix, so a secret scanner can recognize a leaked one.
- AC-1.3 Rotating a token returns a new one; the old one is rejected from then on. Whether the old token gets a short grace period is open: [issue #14](https://github.com/andresBR8/patchconi/issues/14).
- AC-1.4 A revoked token is rejected with `401` on the next report, and the host keeps its history.

### Report ingestion (UC-1, UC-4)

- AC-2.1 A valid report from an enrolled host is accepted and visible in the UI.
- AC-2.2 An invalid report is rejected with `400` and a message that names the failing field; nothing is stored.
- AC-2.3 A report larger than the size limit is rejected with `413`; too many reports from one token are rejected with `429`.
- AC-2.4 Sending the same report twice (same report ID) stores it once.
- AC-2.5 Reports from every distribution marked *tested in CI* in the [support matrix](#support-matrix) are accepted (contract tests with the captured examples).

### Fleet overview (UC-2, UC-3)

- AC-3.1 Every host is in exactly one state from the [patch policy](policy.md): up to date, pending updates, out of policy or no data.
- AC-3.2 The counts per state add up to the number of enrolled hosts.
- AC-3.3 A host that breaks the policy shows the reason (which rule, since when).
- AC-3.4 A host whose operating system is past its vendor's security support is *out of policy*, even with no pending updates. An operating system missing from the lifecycle table is flagged *unknown lifecycle* and is not *out of policy*. The web UI and the API show the date of the lifecycle data.
- AC-3.5 The fleet overview shows how many hosts and how many updates are marked *pending before enrollment, real age unknown* ([policy](policy.md#how-pending-since-is-set)).

### Host detail and history (UC-4, UC-5, UC-8)

- AC-4.1 The detail lists each pending update with installed version, candidate version, whether it is a security update, and *pending since* (see AC-4.4).
- AC-4.2 The detail shows running kernel, newest installed kernel, whether a reboot is required, last boot time and last report time.
- AC-4.3 History is kept for 90 days by default (configurable) and shows the state of the host on any day in that window.
- AC-4.4 *Pending since* follows the [policy](policy.md#how-pending-since-is-set): the earlier of the advisory date and the first time seen when there is an advisory date; otherwise the first time seen, and updates already pending in the host's first trusted report are marked *pending before enrollment, real age unknown* in the detail. Security updates also show *security since*, the clock that `security_max_age` counts from.

### Users (all personas)

- AC-5.1 On first start the server creates one administrator from its configuration; it does not create default passwords.
- AC-5.2 A viewer can see everything and change nothing: every write request returns `403`.
- AC-5.3 Repeated failed logins are rate-limited.

### Policy and alerts (*Important*, UC-6, UC-9)

- AC-6.1 The policy is read from a configuration file and environment variables (policy as code); after a change, the states of all hosts are recalculated.
- AC-6.2 The web UI shows the active policy read-only, with the source of each value; no request can change it.
- AC-6.3 A generic webhook fires once when a host enters *out of policy*, not again while it stays there, and respects a cooldown.
- AC-6.4 Every webhook is signed with HMAC-SHA256 over a timestamp and the body, with a secret shared with the receiver. The timestamp and the signature travel in their own headers. The documented receiver check rejects a bad signature and any message older than 5 minutes, so a captured message cannot be replayed later.

### Metrics (*Important*, UC-10)

- AC-7.1 `/metrics` exposes the number of hosts per state and the ingestion counters, with no per-host or per-package labels (low cardinality).
- AC-7.2 The Grafana dashboard in the repository imports without errors.

### Agent (UC-1, UC-4)

- AC-8.1 `--dry-run` prints to standard output the exact JSON report the agent would send, and sends nothing.
- AC-8.2 The report includes held packages (`apt-mark hold`; `dnf versionlock` when that plugin is installed), and the host detail shows them.
- AC-8.3 The report includes the operating system fields from `/etc/os-release`.
- AC-8.4 The report includes the age of the package metadata the agent read (the policy's `metadata_max_age` depends on it).
- AC-8.5 On Ubuntu, the report says whether the Expanded Security Maintenance (ESM) repositories are enabled (the lifecycle check depends on it).
- AC-8.6 When the package manager provides them, the report includes each update's advisory ID and advisory date (*pending since* depends on the date).
- AC-8.7 If the agent cannot parse the package manager's output, it still sends a valid report with the operating system fields and an error marker instead of the update list. The server stores it, so the lifecycle check still applies, and the host detail shows the error. The protocol v1 schema allows this report.

## Support matrix

This is the target for v0.1.0: which distributions the PatchConi agent works on. It is not the same as the vendor's security support for each operating system, which the [policy](policy.md#unsupported-operating-systems) checks. Three levels:

- **Supported**: the agent is expected to work, and bug reports are accepted. Before v0.1.0, the output format of every supported distribution is captured at least once.
- **Tested in CI**: every pull request runs the agent's tests against that distribution.
- **Best effort**: older releases of the distributions in the table, with the same package manager, that their vendor no longer supports (for example, an Ubuntu LTS or Debian release past its security support). The agent must at least report the operating system fields, so the host shows as *out of policy* (unsupported operating system) and not as *no data* (AC-8.7). No CI, and no guarantee that the update parser works. Non-LTS Ubuntu releases and distributions that use another tool (such as `yum` on RHEL 7 or CentOS 7) are not included.

| Family | Package manager | Distribution | Supported | Tested in CI |
| --- | --- | --- | --- | --- |
| Debian | apt | Ubuntu 22.04 LTS | Yes | Later |
| Debian | apt | Ubuntu 24.04 LTS | Yes | **Yes** |
| Debian | apt | Ubuntu 26.04 LTS | Yes | Later |
| Debian | apt | Debian 12 | Yes | Later |
| Debian | apt | Debian 13 | Yes | **Yes** |
| RHEL | dnf | Rocky Linux 9 | Yes | Later |
| RHEL | dnf | Rocky Linux 10 | Yes | **Yes** |
| RHEL | dnf | AlmaLinux 9 | Yes | Later |
| RHEL | dnf | AlmaLinux 10 | Yes | Later |

- **Why these three in CI:** one per family to start with. Ubuntu 24.04 and Debian 13 together cover apt 2.x and apt 3, and Rocky Linux 10 covers dnf on the current RHEL major.
- **Architectures:** amd64 and arm64 are supported; CI tests amd64.
- **Later:** a distribution moves up to *tested in CI* when its job is added; no new code should be needed if the family already works.
- **Not supported in v0.1.0:** zypper (openSUSE, SLES), apk (Alpine), pacman (Arch) and non-LTS Ubuntu releases. See the [roadmap](roadmap.md).
- A distribution stays *supported* while its vendor supports it with security updates, as the [policy](policy.md#unsupported-operating-systems) defines it; then it moves to *best effort*.

### Why the examples come from containers

The format of `apt` and `dnf` output changes between versions, and the agent parses that output. So the project keeps real output from every supported distribution, captured from the **official container images, pinned by digest**. Old images are chosen on purpose, so that they have pending updates.

- Anyone can reproduce the captures; they contain no data from anyone's machines.
- The same capture script is reused in phase 5 to test the agent in CI against each distribution.
- What a container cannot show (a running kernel different from the installed one, a pending reboot, the systemd timers that refresh the package metadata, running without root on a real host) is captured once from virtual machines and anonymized before it is committed.

## Requirements from other people's environments

PatchConi runs in environments its maintainer does not control. The agent and the server must work when:

- **Outbound traffic goes through an HTTPS proxy.** The agent honors `HTTPS_PROXY` and `NO_PROXY`, and accepts an extra CA certificate for proxies and servers with a private CA.
- **Hosts have no internet access except to the PatchConi server.** The agent never downloads anything itself: it reads the package metadata that the system already has (refreshed by the distribution's own timers or from a local mirror) and reports how old that metadata is. Old metadata makes the result untrustworthy, and the [policy](policy.md) says so instead of reporting *up to date*.
- **Hosts and server are in different time zones.** Every timestamp in the protocol and the API is UTC in RFC 3339 format. The UI shows local time.
- **The system language is not English.** The agent runs package managers with `LC_ALL=C`, so the output it parses is always the same.
- **Host clocks are wrong.** The server uses its own clock for *received at* and for the first time it saw each update pending; advisory dates come from repository metadata, and one later than the server's receive time is ignored ([policy](policy.md#how-pending-since-is-set)); times reported by the agent (last boot, metadata age) are shown as reported, and a large clock skew is flagged.
- **The agent cannot be root.** It is designed to run as a dedicated unprivileged user (confirmed in phase 5). Anything that needs root is out of scope or must be provided by the system (for example, refreshing package metadata).
- **Hosts are switched off for days.** Nothing depends on the host being on at a given time; a host that comes back reports its real state on its next run.

## Open questions

Tracked as issues in the phase 1 milestone before the phase closes:

1. Token rotation: should the old token keep working for a short grace period, so an automated rotation does not lose a report? [Issue #14](https://github.com/andresBR8/patchconi/issues/14).
