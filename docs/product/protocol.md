# Agent protocol v1

How the agent reports to the server. The contract is in [`protocol/v1/`](../../protocol/v1/): [`report.schema.json`](../../protocol/v1/report.schema.json) (JSON Schema 2020-12) is the source of truth for the report, and [`openapi.yaml`](../../protocol/v1/openapi.yaml) is the draft of the endpoint ([ADR 0022](../adr/0022-report-schema-first.md)). This document explains the rules the schema cannot express. The [findings](#findings-from-the-captures) at the end record what the captures of `apt` and `dnf` showed, because several fields depend on them.

## Transport

- `POST /api/v1/agent/reports` with `Authorization: Bearer <token>`, the host's agent token ([ADR 0006](../adr/0006-per-host-agent-tokens.md)). The token is valid only for this endpoint: on any other route it is answered with `401`, and the user API accepts only a session ([threat model](../threat-model.md), T-03).
- **HTTPS only.** The agent refuses a server URL with `http://` unless its host is `localhost`, `127.0.0.1` or `::1`, for development. It verifies the certificate against the system's CA store, or against a CA file set in its configuration.
- The body is one report, `Content-Type: application/json`, at most **1 MiB**. No `Content-Encoding`: a compressed body could expand far beyond the limit after it is accepted (a decompression bomb), and reports are small.
- **A report over 1 MiB** is never sent as it is, since a `413` is not retried and the host would never report. The agent drops `inventory` first. If the report is still too large, it sends `packages` as an error ("report larger than 1 MiB, N updates"), so the operating system, kernel and reboot fields still arrive.
- One run of the agent sends one report. There is no queue on disk: a report that cannot be delivered is dropped, and the next run sends a new one with the current state.

## Responses and what the agent does

| Status | When | Agent |
| --- | --- | --- |
| `201` | The report is stored for the first time. | Done. |
| `200` | A report with the same `report_id` and the same body was already stored for this host (AC-2.4). Nothing changes. | Done. |
| `400` | The body is not a valid report. [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457) problem details, with a JSON Pointer per error. | Logs it, no retry. |
| `400`, type `/problems/unsupported-schema-version` | `schema_version` is newer than the server knows. The body lists the versions it supports. | Logs that the server must be upgraded first, no retry. |
| `401` | Missing, unknown or revoked token, or a retired host. | Stops and logs it, no retry. |
| `409`, type `/problems/report-id-conflict` | A report with the same `report_id` but a different body was already stored for this host. | Logs it, no retry. |
| `413` | Body over 1 MiB. | Logs it, no retry. |
| `415` | Not `application/json`, or a `Content-Encoding`. | Logs it, no retry. |
| `429` | Too many requests, with `Retry-After`. | Retries. |
| `5xx`, or no response | Server or network error. | Retries. |

**Duplicates.** The server stores the SHA-256 of each report's body. A report whose `report_id` is already stored for the host is compared by that hash: the same body is a retry (`200`), a different one is a bug or a forgery (`409`). Either way the stored report does not change.

**Retries** send the same bytes, so the same `report_id` and the same hash: a report that was stored but whose response was lost is answered with `200`. Within one run the agent makes at most 5 attempts, waiting a random time between 0 and min(60 s, 2 s × 2^attempt) before each retry (exponential backoff with full jitter, so that hosts that lost the server at the same moment do not come back at the same moment). With a `Retry-After`, it waits that long instead, unless the wait would end after the next scheduled run of its timer: then it gives up, and the next run's report replaces this one (there is no queue on disk). After the last attempt it gives up until the next run.

The response carries nothing the agent acts on besides those rules. The agent never runs commands from the server ([ADR 0007](../adr/0007-agent-in-go.md)).

## Report fields

The schema is strict: every object rejects unknown properties, strings have maximum lengths and lists maximum sizes. Times are UTC with a `Z` suffix.

| Field | Source on the host |
| --- | --- |
| `schema_version` | `"1.0"` |
| `report_id` | A random UUID per report, reused by its retries. |
| `agent_instance_id`, `sequence` | The agent's state directory; see [ordering](#ordering-and-identity). |
| `machine_fingerprint` | `systemd-id128 machine-id --app-specific=1a05fda4-d773-446d-80c6-ca4266e023d4`, which is the HMAC-SHA-256 of that fixed application ID keyed by the machine ID in `/etc/machine-id`, cut to 128 bits and marked as a version 4 UUID. As documented in [sd_id128_get_machine_app_specific(3)](https://www.freedesktop.org/software/systemd/man/latest/sd_id128_get_machine_app_specific.html), and checked against `systemd-id128` on Ubuntu 24.04, so the agent can compute it without the tool. The raw machine ID never leaves the host. Null when there is no readable machine ID. |
| `agent.version` | Built into the agent. |
| `collected_at` | Host clock when collection started. Shown, never used to order reports or for policy clocks. |
| `os` | `ID`, `VERSION_ID`, `PRETTY_NAME` and `ID_LIKE` from `/etc/os-release` (AC-8.3). |
| `arch` | `uname -m`. |
| `kernel.running` | `uname -r`. |
| `kernel.newest_installed` | The highest installed version of `dpkg-query -W 'linux-image-[0-9]*'` (the `[0-9]` leaves out metapackages such as `linux-image-generic`), compared with dpkg's rules; or of `rpm -q kernel-core --qf '%{VERSION}-%{RELEASE}.%{ARCH}'`, compared with rpm's. Sent in the form `uname -r` prints (`6.8.0-147-generic`, `6.12.0-211.68.1.el10_2.x86_64`), so that the server can compare it with `kernel.running` for equality only. Null when no kernel package is installed (containers). |
| `reboot_required` | dnf: `dnf needs-restarting -r`, when the command is installed ([finding 5](#5-a-missing-dnf-plugin-is-not-an-error)). apt: true when `/var/run/reboot-required` exists. False only when an installed package maintains that file on kernel and library updates (expected to be `update-notifier-common` on Ubuntu; which package does it on Ubuntu and Debian is checked in phase 5, [#25](https://github.com/andresBR8/patchconi/issues/25)); otherwise null, because a missing file proves nothing. |
| `last_boot_at` | Host clock minus `/proc/uptime`. |
| `metadata_age_seconds` | apt: age of `/var/lib/apt/periodic/update-success-stamp`; dnf: age of the oldest `repodata/repomd.xml` in the system cache, the conservative choice until [#25](https://github.com/andresBR8/patchconi/issues/25) decides ([finding 1](#1-the-age-of-the-package-metadata)). Null when there is no reliable signal, or when the source is in the future of the host clock. |
| `esm_enabled` | Ubuntu only (AC-8.5): `/var/lib/ubuntu-advantage/status.json` and the ESM apt sources; false when Ubuntu Pro is not installed. The agent never runs `pro status`: on Ubuntu 24.04, run without root while writing the capture script, it wrote a log under `~/.cache` and contacted Canonical's servers. |
| `package_manager` | `apt --version`, `dnf --version`. |
| `packages.updates` | One entry per package name and architecture, with the version the package manager would install; the API rejects a report with two entries for the same pair (`400`). apt: `apt list --upgradable`. dnf: `dnf -C check-update` for the candidates (`repoquery --upgrades` lists every newer version, four for `curl` in the Rocky 10 capture), `rpm -q` for the installed version, and `dnf -C updateinfo` for advisories (AC-8.6). `security` is true for an apt suite ending in `-security`, or a dnf security advisory. Versions are opaque text. |
| `packages.held` | `apt-mark showhold`; `dnf versionlock list` when the plugin is installed (AC-8.2). |
| `packages.updates[].advisories[].issued_on` | The date `dnf updateinfo info` prints for the advisory. It is the `Updated` field, which can be later than the issue date, so clocks that use it can start late. Reading the `issued` date from `updateinfo.xml` is part of [#28](https://github.com/andresBR8/patchconi/issues/28). |
| `packages.error` | Instead of the lists when the agent cannot parse the output (AC-8.7): the message, the command and its exit code. |
| `inventory` | Optional: `dpkg-query -W`, `rpm -qa`. |

The agent runs every command with `LC_ALL=C`, so that the output it parses does not depend on the host's language.

## Ordering and identity

Reports can arrive out of order (a slow retry, a host that was off) or at the same time (the timer and a run after a package transaction). The host clock cannot order them: it may be wrong. So the agent numbers its reports:

- On first run the agent creates `agent_instance_id`, a random UUID, in its state directory. A reinstall or a lost state directory creates a new one.
- Each run takes a lock (`flock`) on the state directory, so two runs never overlap, adds one to `sequence`, writes it to disk and only then sends the report. A report that is not delivered leaves a gap, which is harmless.

The server keeps, per host, its **identity**: the known fingerprint, the current instance and the last applied `sequence`. All three are unset after enrollment and after a token rotation, and are set together by the first report applied after that.

Under a per-host lock, after the [duplicate check](#responses-and-what-the-agent-does), the server first records the report's instance if the host has never seen it, whether or not the report is then applied. An instance is *new to the host* when it had no record before this report. Then the report is decided by the first rule that matches:

| # | The report | Result | Alert |
| --- | --- | --- | --- |
| 0 | Arrives while the host has no identity (after enrollment or a token rotation), from any instance, new or seen | Applied. Its fingerprint becomes the known one (two nulls count as equal), its instance the current one, its `sequence` the last applied | No |
| 1 | Has a fingerprint different from the known one, from any instance | Not applied: `fingerprint_mismatch` | Yes: the token is used from another machine, or from a clone with a new machine ID |
| 2 | Comes from an instance new to the host, with the known fingerprint | Applied; the instance becomes current. A reinstall on the same machine | No |
| 3 | Comes from the current instance with a higher `sequence` | Applied | No |
| 4 | Comes from the current instance with a lower or equal `sequence` | Not applied: `sequence_regression` | When the host's previous report was also a `sequence_regression`. One alone is a late retry; two in a row is a restored snapshot or a copied state directory |
| 5 | Comes from an instance seen before that is not the current one | Not applied: `superseded_instance` | Yes, immediately: someone with the token created a new instance, and this is the real agent being ignored |

`superseded_instance` only happens when the host has a current instance: without one, rule 0 applies. A report that is not applied is stored with `applied = false` and changes neither episodes nor state.

**Resolving an alert.** An administrator can clear an alert in the host detail, but clearing it does not change which reports are applied: the identity stays as it is. **To recover the host, rotate its token.** Rotation unsets the whole identity and clears the alert, and the first report with the new token is applied by rule 0, whatever its instance and `sequence`. That covers every case above:

- someone with the old token created an instance that became current: the real agent's next report is applied again;
- someone sent a huge `sequence` (up to 2^53 − 1) from a copied state directory: the counter starts again from the real agent's report;
- a reinstall created a new `/etc/machine-id` and raised a false alarm by rule 1: its fingerprint becomes the known one.

The old token stops working, which also locks out whoever had it. If [#14](https://github.com/andresBR8/patchconi/issues/14) adds a grace period with two valid tokens, only a report with the new token can set the identity; otherwise the holder of the old token could get in first.

**Limits.** A clone that keeps `/etc/machine-id` and the state directory is not detected. After a restored snapshot, the instance reports again once its `sequence` passes the last applied one, or at once after a reinstall or a token rotation. How the server stores this is in the [domain model](domain-model.md#invariants-and-backend-rules).

## Untrusted text

Everything in a report is data written by the host, and a compromised host can write anything there. The server stores it as data and never interprets it. The web escapes every value, and never renders one as HTML or Markdown. Before sending, the agent removes credentials from URLs in `packages.error.message` (`https://user:password@mirror/` becomes `https://mirror/`), because package manager errors can quote a repository URL.

## Versioning

- `schema_version` is `major.minor`. A minor version only adds optional properties; anything else is a new major version, with a new schema file and endpoint.
- **Servers are upgraded before agents**, as in Kubernetes' version skew policy. A server accepts every version it knows, and answers a newer one with `/problems/unsupported-schema-version`. The API reads `schema_version` before validating, so that the agent gets that answer instead of a list of unknown properties.
- Strict validation is deliberate: a misspelled or unknown property fails loudly (AC-2.2) instead of being silently ignored.

## Findings from the captures

Captured on 2026-10-24: the nine supported distributions in containers (`protocol/captures/containers/`), and two virtual machines, an Ubuntu 24.04 host and a Rocky Linux 10.2 host (`protocol/captures/hosts/`). Both hosts were captured as an unprivileged user with no supplementary groups and no sudo. Times below are UTC.

### 1. The age of the package metadata

**What the captures show.**

- On `apt`, the modification time of the files in `/var/lib/apt/lists/` is the `Last-Modified` time of the file on the mirror, not when the host downloaded it. On the Ubuntu host the oldest `Release` file is from 2024-04-25. In the containers, `apt-get update` ran seconds before the listing, yet the Debian 13 `trixie` `InRelease` file is dated 2026-09-12, 42 days earlier. These times say how old the repository is, not how old the host's copy is.
- `/var/cache/apt/pkgcache.bin` is rebuilt without downloading anything: on the Ubuntu host it was rewritten at 20:59, when `apt-daily-upgrade` ran, while the lists were 9 days old.
- On Ubuntu, `/var/lib/apt/periodic/update-success-stamp` is written after a successful refresh. On the host it is from 2026-10-15 at 19:10, 9 days before the capture, which matches the age of the lists.
- In the Debian and Ubuntu containers, `/var/lib/apt/periodic/` has no stamp files at all: no daily job has ever run there. Containers cannot show whether a real Debian host writes `update-success-stamp`.
- On `dnf`, the modification time of `repodata/repomd.xml` in the system cache is when the host downloaded it: in the containers it matches the `dnf makecache` run. On the Rocky host the four cached repositories range from 9 days old to 73 minutes old.

**Consequences for the protocol.**

- On `apt`, the agent measures the metadata age from `update-success-stamp`. It never uses the times of the list files or of `pkgcache.bin`.
- When there is no reliable signal, the agent sends a null age. A report with a null age is never trusted ([domain model](domain-model.md#nullable-columns)).
- Still open: whether Debian writes the stamp, and which repository's age counts on `dnf` when the cached repositories differ ([#25](https://github.com/andresBR8/patchconi/issues/25)).

### 2. The `apt-daily` delay after boot

**What the captures show.**

- `apt-daily.timer` on Ubuntu 24.04 runs at 06:00 and 18:00 with `RandomizedDelayUSec=12h` and `Persistent=yes`. When a host boots after missing runs, the timer fires, but the refresh can wait up to 12 hours.
- The Ubuntu host had been up for 80 minutes and its package lists were 9 days old.
- `apt-daily-upgrade.timer` has a delay of 1 hour, so it often runs first: `unattended-upgrades` ran at 20:59 with those 9-day-old lists.

**Consequences.**

- A host that is only switched on for a few hours, like Alex's machines ([vision](vision.md#who-it-is-for)), can spend most of its uptime with stale metadata. It shows as *no data* when the age exceeds `metadata_max_age` ([policy](policy.md#default-thresholds)).
- The panel has to say why the data is stale, and the documentation has to warn operators of such hosts ([#26](https://github.com/andresBR8/patchconi/issues/26)).
- On `dnf`, `dnf-makecache.timer` has `RandomizedDelayUSec=1h`.

### 3. What counts as pending on `apt`

**What the captures show.**

- On the Ubuntu host, `apt list --upgradable` lists 21 packages, `apt-get -s upgrade` would install 18, and `apt-mark showhold` lists 5 held packages.
- The containers show the difference for a held package: after `apt-mark hold base-files`, `apt list --upgradable` still lists it, and `apt-get -s upgrade` keeps it back.
- The host capture holds counts only, so it does not say which 3 packages `apt-get` leaves out: held packages with an update, Ubuntu phased updates, or upgrades that need new packages. The containers have no phased updates.

**Still open.** Whether held packages and phased updates start a policy clock ([#27](https://github.com/andresBR8/patchconi/issues/27)). The report v1 carries both lists: the updates, and the held packages.

### 4. Running without root on `dnf`, and advisories

**What the captures show.**

- On the Rocky host, as an unprivileged user, `dnf -C` reads the system cache. `check-update` lists 6 updates with or without `--setopt=cachedir=/var/cache/dnf`.
- `dnf needs-restarting -r` detects the pending reboot: the newest installed kernel is not the running one.
- The [ADR 0007](../adr/0007-agent-in-go.md) hypothesis holds for listing updates without root on both hosts.
- On the host, `dnf -C updateinfo list --updates` returns 0 advisories for the 6 updates, which come from `baseos`. The maintainer saw the same result as a user with more groups, outside the capture.
- In the containers, which refresh the metadata as root, every RHEL-family distribution returns advisories (61 distinct advisories in 95 package lines on Rocky Linux 10).

**Still open.** Whether the host's cache lacks the advisory data, or those updates have no advisory yet. This decides whether `security` and advisory dates can be trusted on `dnf` without root ([#28](https://github.com/andresBR8/patchconi/issues/28)).

### 5. A missing `dnf` plugin is not an error

**What the captures show.**

- Without the versionlock plugin, `dnf versionlock list` prints `No such command` and exits with 1.
- Without `dnf-plugins-core`, which is the case in the Rocky containers, `dnf needs-restarting -r` prints the same message and also exits with 1. Exit code 1 is also how `needs-restarting -r` says that a reboot is required.

**Rules for the agent.**

- No versionlock plugin means no held packages: the agent reports an empty list, not an error.
- The agent checks whether a plugin is installed before running its command, from the package that provides it (`rpm -q --whatprovides 'dnf-command(versionlock)'`). It never infers that from the exit code or from the message.
- Without `needs-restarting`, the agent sends `reboot_required` as unknown, not as `true`.

### 6. Times from `systemctl`

**What the captures show.** `systemctl show --timestamp=utc` still printed `LastTriggerUSec` in the host's local time zone (CEST).

**Rule for the agent.** It never parses formatted dates from command output. It reads the raw values in microseconds since the epoch, and sends times in UTC.
