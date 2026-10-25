# Prior art

> Status: draft (phase 1). Sources consulted on 2026-10-25. Projects change: every statement below is what the linked page said on that date, and anything the sources did not say is marked *not stated*.

PatchConi is not the first tool to answer «which hosts are behind on updates». This page looks at six existing tools to learn what they do well, what PatchConi takes from them, and what it leaves out on purpose. It goes deeper than the short comparison of Patchman and PatchMon in the [vision](vision.md#other-tools-already-do-part-of-this): the vision says what they are; this page says what PatchConi learns from them.

Rules for this page: only ideas are taken, never code, text or screenshots; each section links the official sources it is based on (the project's repository, documentation or website); community forums and third-party reviews are not used as sources.

## Patchman

**What it is.** A Linux patch status monitoring system with a Django web interface ([repository](https://github.com/furlongm/patchman)).

**License.** GPL-3.0 ([repository](https://github.com/furlongm/patchman)).

**Model.**

- Read-only, with the server working out the updates, as the [vision](vision.md#other-tools-already-do-part-of-this) says. Besides packages and repositories, the client report carries the running kernel and the operating system, and the server downloads the repositories' update information itself ([README](https://github.com/furlongm/patchman/blob/main/README.md)).
- `yum`, `apt` and `zypper` plugins can send a report when packages are installed or removed. A periodic schedule for the client is *not stated* in the README.

**What it does well.** Security updates are identified from errata, and CVE and CVSS data are added on top. Repositories can be marked as security or not, which matters on Debian and Ubuntu. Reports in JSON (protocol 2) fall back to plain text when `jq` is missing.

**What we take.** A report right after a package transaction, not only on a timer: the [domain model](domain-model.md#what-v1-already-allows) already orders such reports. Classifying security updates by repository on `apt` matches what the [protocol](protocol.md#report-fields) does with suites that end in `-security`.

**What we do not take.** Resolving updates on the server from its own copy of the repositories. It is a sound design, but the server then needs internet access or mirrors, and it can disagree with the host about pins, held packages and private repositories. PatchConi asks the host's own package manager ([vision](vision.md#what-patchconi-focuses-on), point 2).

## PatchMon

**What it is.** A Linux patch and server management platform, with agents also for FreeBSD and Windows ([repository](https://github.com/PatchMon/PatchMon)).

**License.** AGPLv3 ([repository](https://github.com/PatchMon/PatchMon)).

**Model.**

- Outbound-only agents and patching after a preview and an approval, as the [vision](vision.md#other-tools-already-do-part-of-this) says. The agent sends reports over HTTPS and live events over a WebSocket. A patch run can cover selected packages, security updates only or a full upgrade, with live output and an audit history.
- Beyond the terminal and benchmarks the vision lists: an AI assistant panel and Docker inventory.
- Server: Go with an embedded React frontend, PostgreSQL and Redis. Docker is the supported way to self-host; a managed cloud offering is also listed.

**What it does well.** Outbound-only agents with no inbound ports. Broad package manager coverage (apt, dnf, yum, apk, pacman, FreeBSD pkg). An audit history of every patch run.

**What we take.** The connection direction: the host always starts it ([architecture](../architecture.md#what-runs-where-and-who-opens-each-connection)).

**What we do not take.** Patching, remote terminals and command execution. A server that can change every host is the most valuable target in the fleet; PatchConi stays read-only ([ADR 0007](../adr/0007-agent-in-go.md), [vision](vision.md#patchconi-does-not-patch)). Benchmarks and container scanning are out of scope.

**Not checked.** Whether PatchMon tracks how long each update has been pending against a compliance deadline: its «patch policies» described in the README schedule patch runs (immediately, in a maintenance window or delayed), which is a different thing.

## Canonical Landscape

**What it is.** Canonical's systems management tool for Ubuntu: patching, auditing, access management and compliance from one dashboard ([product page](https://ubuntu.com/landscape)).

**License and cost.**

- The client is GPL-2.0 ([landscape-client](https://github.com/canonical/landscape-client)).
- Landscape is licensed through an Ubuntu Pro subscription. A free SaaS account manages up to 5 machines ([licenses](https://ubuntu.com/landscape/docs/explanation/landscape/licenses/)).
- Editions: SaaS, managed and self-hosted, the last one able to run without internet ([pricing](https://ubuntu.com/landscape/pricing)).
- Whether the server's source code is published is *not stated* in the pages consulted.

**Model.**

- A client on each machine enrolls with the server and reports health metrics ([product page](https://ubuntu.com/landscape)).
- It **applies updates** and manages users remotely.
- The client runs as `root` and a `landscape` user; a `monitor_only` mode disables the administrative features and runs without root ([landscape-client](https://github.com/canonical/landscape-client)).
- Support for operating systems other than Ubuntu is *not stated*; the pages describe Ubuntu instances only.

**What it does well.** A monitor-only mode that drops root, which shows a vendor treating observation and administration as separate privileges. Offline (air-gapped) deployment. First-class awareness of Ubuntu Pro.

**What we take.** The split between monitoring and administration, taken further: PatchConi has only the monitoring half. The agent's non-root target ([ADR 0007](../adr/0007-agent-in-go.md)) and the ESM flag in the report (AC-8.5) cover the same ground for Ubuntu hosts.

**What we do not take.** Remote administration, a single-vendor scope and a subscription to run it.

## Foreman with Katello

**What it is.** Foreman manages the lifecycle of servers (provisioning, configuration, orchestration, monitoring) ([repository](https://github.com/theforeman/foreman)). Katello is a Foreman plugin for content management: it syncs yum and deb repositories into versioned *content views* and promotes them through *lifecycle environments* such as Dev, QE and Production ([Katello](https://github.com/Katello/katello), [plugin page](https://theforeman.org/plugins/katello/)).

**License.** Foreman: GPL-3.0 or later, with some files under other licenses ([repository](https://github.com/theforeman/foreman)). Katello: GPL-2.0 ([repository](https://github.com/Katello/katello)).

**Model.**

- It distinguishes **applicable** errata (they fix packages on the host) from **installable** errata (applicable, and available in the host's content view environment) ([Managing Content, chapter 14](https://docs.theforeman.org/nightly/Managing_Content/index-katello.html)).
- It **installs** errata on selected hosts from the web UI ([same guide](https://docs.theforeman.org/nightly/Managing_Content/index-katello.html)). The guide sections read do not say which mechanism runs the installation.
- The API lists the errata of a host and can force applicability to be recalculated ([Katello 4.16 API, errata](https://apidocs.theforeman.org/katello/4.16/apidoc/v2/errata.html)).
- How hosts send their package profile is *not stated* in the sections read.

**What it does well.** Controlled promotion of content from test to production, and a precise vocabulary for «a fix exists» versus «a fix is available to this host».

**What we take.** That distinction, as a definition. PatchConi only counts what the host's package manager would install, which is close to *installable* for that host: an update that exists upstream but not in the host's repositories is not pending ([policy](policy.md#what-the-policy-looks-at)). The [glossary](domain-model.md#glossary) should keep the two words apart if vulnerability data ever adds the other one ([roadmap](roadmap.md)).

**What we do not take.** Content management, provisioning and remote execution. They need a much larger installation than a small fleet wants to run, and they are the job of the tools that patch.

## Vuls

**What it is.** A vulnerability scanner in Go for Linux, FreeBSD, containers, WordPress, language libraries and network devices ([repository](https://github.com/future-architect/vuls)).

**License.** GPL-3.0 ([repository](https://github.com/future-architect/vuls)).

**Model.**

- **Remote scan:** one Vuls machine connects to the targets over SSH.
- **Local scan** on each server, and a **server mode** where targets send command output over HTTP, so no SSH is needed.
- **Fast scan** without root and without dependencies; **fast root scan** adds checks such as processes that need a restart after an update. It warns when a kernel was updated and the server not restarted.
- It does not update the vulnerable packages.
- Data sources include NVD, JVN, the distributions' OVAL feeds and security trackers, the package managers' advisory commands, and the CISA and VulnCheck KEV catalogs.

**What it does well.** Vulnerability data from many sources in one result, prioritization by known exploitation, and a scan mode that needs no root.

**What we take.** For later: known-exploited catalogs are how risk-aware thresholds can replace the single `security_max_age` ([policy](policy.md#security_max_age-why-14-days), [roadmap](roadmap.md)). Now: the kernel installed-but-not-running check matches AC-4.2.

**What we do not take.** SSH from the server into the hosts: the server would hold credentials for every host, which PatchConi rules out ([vision](vision.md#what-patchconi-focuses-on), point 3). Vulnerability databases in v0.1.0: they need regular downloads, and the server may have no internet access.

## apt metrics for Prometheus (node exporter textfile collector)

**What it is.** `apt_info.py`, a script in the Prometheus community's collection of textfile collector scripts. It prints apt metrics in the Prometheus text format; the node exporter's textfile collector exposes them, and Prometheus scrapes the node exporter ([repository](https://github.com/prometheus-community/node-exporter-textfile-collector-scripts), [script](https://github.com/prometheus-community/node-exporter-textfile-collector-scripts/blob/master/apt_info.py)).

**License.** The repository is Apache-2.0; the script's header has no license line of its own.

**Model.**

- Runs on the host and reads apt's local cache with `python3-apt`. It deliberately does not refresh the cache: something else must (its header points at apt's periodic update setting).
- Metrics: upgrades pending and upgrades held, by origin and architecture (phased and excluded packages are not counted as pending); obsolete and auto-removable packages; installed packages per origin; the time of an apt stamp file as a proxy for the last refresh; and whether a reboot is required.
- How to schedule it and whether it needs root are *not stated*; the README recommends writing the output atomically with `sponge`.
- Read-only. Prometheus pulls from the node exporter.

**What it does well.** Small, read-only and built on what the host already has. It never refreshes the cache itself, it reports the cache's age, and its labels are few (origin and architecture, never package names), so cardinality stays low.

**What we take.** Three things the [protocol](protocol.md) already does: read the system's cache without refreshing it, report when the cache was last refreshed (it exports a timestamp; PatchConi sends an age), and read the reboot flag from the `reboot-required` file. Low-cardinality fleet metrics, as in AC-7.1. Its choice to leave phased updates out of *pending* is one input for [#27](https://github.com/andresBR8/patchconi/issues/27).

**What we do not take.** Metrics as the whole answer. A gauge says how many updates are pending now, not since when, so it cannot tell a host that has been behind for a day from one behind for three months, and Prometheus history is usually shorter than an audit needs. PatchConi keeps per-package clocks and transitions, and exports only fleet-level numbers to Prometheus.

## Comparison

From the sources above. *Not stated* means the sources consulted did not say.

| | License | On the host | Who starts the connection | Applies updates | What decides «pending» | Pending age against a deadline |
| --- | --- | --- | --- | --- | --- | --- |
| Patchman | GPL-3.0 | Client | Host (push) | No | Server, from repository data it downloads | Not stated |
| PatchMon | AGPLv3 | Agent | Host (outbound only) | Yes | Not stated | Not stated (its patch policies schedule runs) |
| Landscape | Client GPL-2.0; Ubuntu Pro subscription | Client (root, or monitor-only) | Not stated | Yes | Not stated | Not stated |
| Foreman + Katello | GPL-3.0+ / GPL-2.0 | Not stated in the sections read | Not stated | Yes | Server, errata applicability against content views | Not stated |
| Vuls | GPL-3.0 | Nothing (SSH), or a local scan | Server (SSH) or host (server mode) | No | Vulnerability databases | Not stated |
| `apt_info.py` | Apache-2.0 (repository) | Script and node exporter | Prometheus (pull) | No | Host's apt cache | No (a count, not an age) |
| **PatchConi** | Apache-2.0 | Agent, without root (target) | Host (push) | **No, by design** | **Host's package manager** | **Yes: *pending since*, *security since*** |

## What PatchConi does differently

Each point is in the [vision](vision.md#what-patchconi-focuses-on); this page shows where the other tools stand.

1. **A patch SLA, not only a list.** Every pending update has *pending since* and *security since*, and the [policy](policy.md) turns those ages into one state per host. None of the sources consulted describes ages of pending updates checked against a declared deadline.
2. **The host's package manager is the source of truth.** Patchman and Katello resolve updates on the server from repository data; Vuls matches packages against vulnerability databases. PatchConi reports what `apt` or `dnf` on the host would install, so pins, held packages and private repositories count.
3. **Read-only as a property you can check.** PatchMon, Landscape and Foreman/Katello install updates; Vuls can connect over SSH. PatchConi's server has no way to run anything on a host, and the agent's `--dry-run` shows the exact report (AC-8.1).
4. **Small and cloud-native.** Policy as code, an OpenAPI contract, Prometheus metrics with low cardinality (as `apt_info.py` keeps them), and deployment with Docker Compose or Kustomize, without a subscription.

What PatchConi does not try to do, and these tools do well: patching (PatchMon, Landscape, Katello), content promotion (Katello), vulnerability matching (Vuls), and a wide range of operating systems (PatchMon).
