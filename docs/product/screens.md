# Screens

> Status: v1 (phase 1), approved when phase 1 closed. Later changes go through a pull request. Low-fidelity sketches of the four main screens of the web UI. They fix **what each screen shows and allows**, not how it looks: layout, colors and components are decided in phase 6.

Each sketch lists where every value comes from (an entity or column of the [domain model](domain-model.md), or a document that defines it), the actions and who can take them, and the use cases and acceptance criteria from the [vision](vision.md#mvp-acceptance-criteria-v010) it covers. A value the model does not have is not drawn: it is an [open question](#open-questions).

The sketches use invented, generic data (`web-01`, `db-02`, `example` packages) and one scenario: *now* is 2026-10-23 around 12:00 CEST, and the [policy screen](#4-policy) shows the thresholds in force. Versions are illustrative.

## Rules for every screen

- **Report text is untrusted.** Package names, versions, repositories, advisory IDs, kernel strings, operating system names and parser error messages come from the host, and a compromised host can write anything there. The web shows them as escaped text, never as HTML, Markdown or a link ([protocol, untrusted text](protocol.md#untrusted-text); [threat model](../threat-model.md), T-05). Unicode direction-control characters are shown neutralized, so a value cannot reorder the text around it, and long values are cut visually with the full value one tap away. Host names and labels are written by administrators and are escaped the same way.
- **A viewer sees everything and changes nothing.** Write actions, marked **[admin]** in the sketches, are not rendered for a viewer: no disabled buttons, no hidden forms, no empty menus. The API still answers every write from a viewer with `403` (AC-5.2); hiding the button is a courtesy, not the control.
- **Every page needs a session.** There are no anonymous views ([threat model](../threat-model.md), T-08).
- **Times.** Shown in the browser's local time with its time zone visible (`2026-10-20 14:03 CEST`). The host detail also shows each time in UTC (`2026-10-20T12:03Z`). The zone is printed with each time, not once per page, because a list can cross a daylight saving change. Nothing depends on hovering: every value is reachable by touch and keyboard. Times measured on the host (`agent_*` columns) are labelled *as reported by the host*.
- **No state is told apart by color alone.** Every state is written as a word, with an icon that has a text label. In the sketches: `[OUT]` out of policy, `[PEND]` pending updates, `[OK]` up to date, `[NO DATA]` no data, `[!]` agent alert, `[SEC]` security update.
- **The lifecycle data date is always visible** where an operating system support status is shown: «lifecycle data as of YYYY-MM-DD» (AC-3.4).
- **Lists show text, not counts alone.** A count always links to the list of what it counts.

## 1. Fleet overview

The landing page. Answers «which hosts need attention, and why», in that order.

```text
+--------------------------------------------------------------------------+
| PatchConi                         Fleet  Hosts  Policy      sam (admin)  |
+--------------------------------------------------------------------------+
| Fleet overview                                         As of: [ now v ]  |
|                                                                          |
|  [OUT] Out of policy   3   [PEND] Pending  5   [OK] Up to date  12       |
|  [NO DATA] No data     2                       Total enrolled   22       |
|                                                                          |
|  [!] 1 host with an agent alert                                          |
|  [OUT] 1 host on an unsupported OS (lifecycle data as of 2026-10-01)     |
|  [?] 1 host with unknown lifecycle                                       |
|  [~] 3 hosts, 9 updates pending before enrollment, real age unknown      |
|                                                                          |
|  Filter: state [all v]  label [env=prod v]  name [________]              |
|                                                                          |
|  STATE      HOST     WHY                                  LAST REPORT    |
|  [OUT]      web-03   OS no longer supported               40 min ago     |
|                      (Ubuntu 20.04, ended 2025-05-31)                    |
|  [OUT][!]   db-02    security update pending > 14d        3 days ago     |
|                      (openssl:amd64, since 2026-10-03)                   |
|                      · data 3 days old                                   |
|                      agent alert: fingerprint_mismatch                   |
|  [OUT]      app-07   reboot required > 14d                1h ago         |
|                      (since 2026-10-08)                                  |
|  [NO DATA]  sbc-02   never reported                       -              |
|  [NO DATA]  nas-01   package metadata too old (12 days)   3h ago         |
|                      last boot 3h ago (as reported)                      |
|  [PEND]     web-01   4 pending (1 [SEC])                  25 min ago     |
|  ...                                                                     |
+--------------------------------------------------------------------------+
```

**Order of the list.** *Out of policy* first, oldest breach first (web-03 since 2025-05-31, db-02 since 2026-10-17, app-07 since 2026-10-22). Then *no data*: hosts that never reported first, because nothing at all is known about them, then the oldest data first. Then *pending updates* and *up to date*. A breach is never pushed below the fold by a long list of healthy hosts.

**Data.**

| Shown | Source |
| --- | --- |
| Counts per state, total enrolled | The state of each active host (not retired), from the policy evaluation ([domain model, from facts to a state](domain-model.md#from-facts-to-a-state)). Retired hosts are not counted ([retiring a host](domain-model.md#retiring-a-host)). |
| *Why* for out of policy | Every broken rule, from the evaluation's reasons (`host_state_transition.reasons` for the past), with the package, the clock it counts from (`pending_since`, `security_since`, `reboot_required_since`) and `effective_at`. |
| «· data N days old» | The host is also stale ([policy, states](policy.md#states)): age of the last report or of the package metadata. |
| *Why* for no data | One of the three causes in the [policy](policy.md#what-the-ui-shows-next-to-the-state): never reported, last report older than `stale_after`, or package metadata older than `metadata_max_age` (`report.agent_metadata_age`). For the metadata cause, the last boot (`report.agent_last_boot_at`) is shown next to it, because a host booted a few hours ago is often waiting for `apt-daily` ([protocol, finding 2](protocol.md#2-the-apt-daily-delay-after-boot); [#26](https://github.com/andresBR8/patchconi/issues/26)). |
| Unsupported OS, unknown lifecycle | The lifecycle rule of the evaluation, against the lifecycle table and its `snapshot_date` (AC-3.4). An unsupported OS is always *out of policy*, so its count is part of the *out of policy* count. |
| Pending before enrollment | Hosts with at least one open episode with `pending_update.before_enrollment`, and the number of such episodes (AC-3.5). |
| Agent alert | `host.agent_alert_at`, `host.agent_alert_reason` ([invariant 1](domain-model.md#invariants-and-backend-rules)). |
| Last report | `report.received_at` of the host's last applied report (server clock). Which report counts is [question 3](#open-questions), [#43](https://github.com/andresBR8/patchconi/issues/43). |
| As of a past date | The last `host_state_transition` of each host before that date, for the hosts enrolled and not retired on that date (`host.created_at`, `host.retired_at`), inside the retention window (AC-4.3). |
| Labels for the filter | `host_label`. |

**Actions.** Everyone: filter, change the date, open a host. No write actions on this screen.

**Covers.** UC-2, UC-3, UC-5 (fleet on a past date); AC-3.1, AC-3.2 (one state per host, counts add up to the total), AC-3.3 (reason and since when), AC-3.4 (unsupported OS, unknown lifecycle, lifecycle date), AC-3.5 (pending before enrollment).

### Empty fleet

```text
+--------------------------------------------------------------------------+
| Fleet overview                                                           |
|                                                                          |
|  No hosts enrolled yet.                                                  |
|                                                                          |
|  [ Enroll a host ]                                               [admin] |
|                                                                          |
|  A viewer sees instead: «An administrator has not enrolled any host      |
|  yet.»                                                                   |
+--------------------------------------------------------------------------+
```

The counts are not drawn: four zeros and a total of zero say nothing useful. A filter that matches no host says «No host matches this filter» and offers to clear it.

## 2. Host detail and history

Everything PatchConi knows about one host, and its state on a past date. In the scenario, db-02 was enrolled on 2026-10-01; its first report was trusted and already listed `libexa`, so that update carries the *pending before enrollment* mark. On 2026-10-22 a report arrived from a machine with a different fingerprint: it was stored, not applied, and opened an agent alert.

```text
+--------------------------------------------------------------------------+
| < Fleet    db-02   env=prod team=db                  [OUT] Out of policy |
+--------------------------------------------------------------------------+
| [!] Agent alert since 2026-10-22 09:12 CEST: fingerprint_mismatch        |
|   A report came from a machine whose fingerprint differs from the known  |
|   one. It was stored and not applied.                                    |
|   [ Rotate token ]  recovers the host: the next report with the new      |
|                     token is applied as the host's first.        [admin] |
|   [ Clear alert ]   hides the alert only; reports from the other         |
|                     machine are still not applied.               [admin] |
+--------------------------------------------------------------------------+
| Why     security update pending > 14 days (openssl:amd64)                |
|         since 2026-10-03 · breach from 2026-10-17 14:00 CEST             |
|         data 3 days old                                                  |
|                                                                          |
| OS      Ubuntu 24.04.3 LTS (ubuntu 24.04) · x86_64 · apt · ESM: off      |
|         supported until 2029-05-31 (lifecycle data as of 2026-10-01)     |
| Kernel  running        6.8.0-140-generic                                 |
|         newest install 6.8.0-147-generic   -> differs                    |
| Reboot  required since 2026-10-20 08:00 CEST (server clock)              |
| Boot    2026-10-12 07:41 CEST (as reported by the host)                  |
| Report  last applied 2026-10-20 10:04 CEST · 2026-10-20T08:04Z           |
|         last received 2026-10-22 09:12 CEST, not applied:                |
|         fingerprint_mismatch                                             |
|         package metadata 2 h old (as reported) · agent 0.1.0             |
+--------------------------------------------------------------------------+
| Pending updates (4)                     ~ = pending before enrollment    |
|                                                                          |
|  PACKAGE         INSTALLED    CANDIDATE    PENDING SINCE  SECURITY SINCE |
|  [SEC] openssl   3.0.13-0u1   3.0.13-0u2   2026-10-03     2026-10-03     |
|        :amd64    repo: noble-security · advisory: -                      |
|  libexa:amd64    1.2-1        1.2-2        ~2026-10-01    -              |
|                  repo: noble-updates · real age unknown                  |
|  curl:amd64      8.5.0-2u1    8.5.0-2u4    2026-10-12     -              |
|  libfoo:amd64    2.0-1        2.1-1        2026-10-15     -   (held)     |
|                                                                          |
| Held packages (2): libfoo:amd64, linux-image-generic:amd64               |
+--------------------------------------------------------------------------+
| History                                    State on: [ 2026-10-10 v ]    |
|                                                                          |
|  On 2026-10-10: [PEND] Pending updates · 2 pending (1 [SEC])             |
|                 open that day: openssl:amd64 [SEC], libexa:amd64 [~]     |
|                                                                          |
|  EFFECTIVE AT           STATE        WHY                                 |
|  2026-10-17 14:00 CEST  [OUT]        security update > 14d (openssl)     |
|  2026-10-01 10:20 CEST  [PEND]       1 pending (libexa, [~])             |
|  2026-10-01 10:00 CEST  [NO DATA]    enrolled, never reported            |
|                         history kept 90 days                             |
+--------------------------------------------------------------------------+
```

Notes on the scenario: the openssl update appeared on 2026-10-03 without changing the state (still *pending updates*) until its 14 days ran out. «Data 3 days old» counts from the last applied report; whether the not-applied report of 2026-10-22 should count instead is [question 3](#open-questions), [#43](https://github.com/andresBR8/patchconi/issues/43).

### Parser error (AC-8.7)

On another host, web-05 (Rocky Linux 10), the last applied report has `parse_status = error`. The update list is replaced by the error, and the rest of the page still shows what the report did carry:

```text
+--------------------------------------------------------------------------+
| Package list unavailable: the agent could not parse the package          |
| manager's output in the last report (2026-10-23 11:02 CEST).             |
|                                                                          |
|   Error: Failed to download metadata for repo 'example'                  |
|                                                                          |
| The OS, kernel and reboot fields above come from this report, so the     |
| lifecycle rule still applies. Updates already pending stay open: a       |
| report with a parser error never resolves them.                          |
+--------------------------------------------------------------------------+
```

The report also carries the command and its exit code (`packages.error` in the [schema](../../protocol/v1/report.schema.json)), but the model stores only `parse_error`: [question 5](#open-questions), [#44](https://github.com/andresBR8/patchconi/issues/44).

### Host without reports yet

```text
+--------------------------------------------------------------------------+
| < Fleet    sbc-02                                    [NO DATA] No data   |
|                                                                          |
|  Never reported. Enrolled 2026-10-23 10:00 CEST by sam.                  |
|  Install the agent with the token shown at enrollment.                   |
|  Lost the token? [ Rotate token ]                                [admin] |
+--------------------------------------------------------------------------+
```

The token is never shown again (AC-1.1); the way forward for a lost token is rotation.

### Other empty cases

- **No pending updates:** «No pending updates in the last trusted report», with the report's time; the held packages line still shows, with `(0)` when there are none.
- **History date outside the window:** a date before the retention window or before enrollment says «No history for this date: kept for 90 days» or «Not enrolled yet on this date», never an empty state that looks like *up to date*.

**Data.**

| Shown | Source |
| --- | --- |
| Name, labels | `host.name`, `host_label` |
| State and *why* | Policy evaluation and its reasons, as on the fleet overview, with `effective_at` of the breach. |
| Agent alert | `host.agent_alert_at`, `agent_alert_reason`; the explanation is fixed text per reason ([invariant 1](domain-model.md#invariants-and-backend-rules)). |
| OS, arch, package manager, ESM | `report.os_pretty_name`, `os_id`, `os_version_id`, `arch`, `package_manager`, `esm_enabled` (Ubuntu only), from the last applied report. |
| Support until | Lifecycle table and its `snapshot_date`. |
| Kernels | `report.kernel_running`, `kernel_newest_installed`, compared for equality only ([invariant 5](domain-model.md#invariants-and-backend-rules)). |
| Reboot | `report.reboot_required` (unknown when null) and `host.reboot_required_since`. |
| Boot, metadata age, agent version | `report.agent_last_boot_at`, `agent_metadata_age`, `agent_version`, labelled as reported by the host. |
| Last applied, last received | `report.received_at` of `host.last_applied_report_id`, and of the host's latest report with its `applied` and `not_applied_reason`. |
| Pending updates | Open `pending_update` episodes; for each, its most recent `update_candidate` (`installed_version`, `candidate_version`, `repository`, `is_security`), `pending_since`, `security_since`, `before_enrollment`, and its `advisory_ref` (`advisory_id`, `agent_issued_on`; an ignored date is marked as such). Security first, then the oldest clock first (AC-4.1, AC-4.4). |
| Held packages | `report.held_packages` (AC-8.2). An update whose package is in that list is marked *(held)*. Whether a held update starts a policy clock is [#27](https://github.com/andresBR8/patchconi/issues/27): the sketch shows the clock it has today. |
| Parser error | `report.parse_status`, `parse_error` (AC-8.7). |
| State on a past date | The last `host_state_transition` before that date (`state`, `stale`, `reasons`, `applied_exceptions`); the episodes open on that date (`first_seen_at` before it, `resolved_at` null or after it). Limited to the retention window (AC-4.3). |
| Enrolled by | `host.created_at`, `created_by`. |

**Actions.**

| Action | Who | Effect |
| --- | --- | --- |
| Change the history date | Everyone | Read only. |
| Rotate token | Admin | New token shown once; the alert is cleared and the host identity reset ([invariant 1](domain-model.md#invariants-and-backend-rules)). Same flow as on the [hosts screen](#3-hosts-and-tokens). |
| Clear alert | Admin | Clears `agent_alert_at` and `agent_alert_reason`. It does not change which reports are applied: the screen says so next to the button. See [question 4](#open-questions), [#33](https://github.com/andresBR8/patchconi/issues/33). |

**Covers.** UC-4, UC-5, UC-8 (a host switched off keeps its clocks; its state on any day is in the history); AC-4.1, AC-4.2, AC-4.3, AC-4.4, AC-8.2, AC-8.7.

## 3. Hosts and tokens

Enrollment and the life of each host's credentials.

```text
+--------------------------------------------------------------------------+
| Hosts                                  Show: (o) active  ( ) retired     |
|                                              [ Enroll a host ]   [admin] |
|                                                                          |
|  HOST     LABELS          ENROLLED           TOKEN LAST USED             |
|  db-02    env=prod        2026-10-01 by sam  2026-10-22 09:12 CEST [...] |
|  sbc-02   -               2026-10-23 by sam  never                 [...] |
|  ...                                                                     |
|                                                                          |
|  [...] row menu, not rendered for a viewer:                      [admin] |
|        Edit name and labels · Rotate token · Revoke token · Retire host  |
+--------------------------------------------------------------------------+

Enroll a host                                                      [admin]
+--------------------------------------------------------------------------+
|  Name   [ sbc-02          ]   unique among active hosts                  |
|  Labels [ env=lab         ]   key=value                                  |
|                                              [ Cancel ] [ Create ]       |
+--------------------------------------------------------------------------+

After Create (shown once)                                          [admin]
+--------------------------------------------------------------------------+
|  Token for sbc-02. Copy it now: it will not be shown again.              |
|                                                                          |
|  [ <token>                                             ] [ Copy ]        |
|                                                                          |
|  Leaving this page discards it. If it is lost, rotate the token.         |
|  Next: install the agent with this token (see the agent docs).           |
|                                                       [ Done ]           |
+--------------------------------------------------------------------------+

Token history of db-02
+--------------------------------------------------------------------------+
|  ID (public part)  CREATED            REVOKED   LAST USED                |
|  <lookup id>       2026-10-01 by sam  -         2026-10-22 09:12 CEST    |
+--------------------------------------------------------------------------+
```

The token of db-02 was last used by the not-applied report of 2026-10-22: a stolen token authenticates, and the report is then stopped by the identity rules. After a rotation, the history shows two rows: the old one with *revoked*, the new one with its own *last used*.

**Confirmations.** Rotate, revoke and retire each ask for confirmation and say what happens:

- **Rotate:** «The current token stops working now. The agent on db-02 will be rejected until it gets the new token.» Whether the old token keeps a short grace period is [#14](https://github.com/andresBR8/patchconi/issues/14); the text changes if it does.
- **Revoke:** «Reports from db-02 will be rejected with 401. Its history stays.» (AC-1.4)
- **Retire:** «db-02 leaves the fleet: its tokens are revoked, it is no longer evaluated or counted, and its pending updates are frozen as they are. This cannot be undone. The name can be reused by a new host.» ([retiring a host](domain-model.md#retiring-a-host))

**Empty cases.** No retired hosts: «No retired hosts.» No hosts at all: the same message as the [empty fleet](#empty-fleet).

**Data.**

| Shown | Source |
| --- | --- |
| Hosts, active or retired | `host` (`name`, `created_at`, `created_by`, `retired_at`, `retired_by`), `host_label`. |
| Token history | `agent_token` (`lookup_id`, `created_at`, `created_by`, `revoked_at`, `revoked_by`, `last_used_at`). The secret part is never stored in clear, so it cannot be shown again (AC-1.2). |
| The token, once | The response to the create or rotate request; the web keeps it in memory only, never in browser storage. |

**Actions.**

| Action | Who | Covers |
| --- | --- | --- |
| Enroll a host | Admin | UC-1, AC-1.1 |
| Edit name and labels | Admin | Domain model: `name` is editable, labels are `key=value` |
| Rotate token | Admin | UC-7, AC-1.3 |
| Revoke token | Admin | UC-7, AC-1.4 |
| Retire host | Admin | UC-7 (host retired) |
| See hosts and token history | Everyone | AC-5.2 |

**Covers.** UC-1, UC-7; AC-1.1, AC-1.2, AC-1.3, AC-1.4, AC-5.2. Install instructions: see [question 1](#open-questions), [#41](https://github.com/andresBR8/patchconi/issues/41).

## 4. Policy

The active policy, read-only. Nothing on this screen can change it: the policy is configuration ([ADR 0019](../adr/0019-patch-policy-as-code.md)).

```text
+--------------------------------------------------------------------------+
| Policy (read-only)                     fingerprint: <policy fingerprint> |
|  Change it in the configuration file or the environment, then restart.   |
|                                                                          |
|  SETTING              VALUE   SOURCE                                     |
|  security_max_age     14d     default                                    |
|  other_max_age        30d     file                                       |
|  reboot_max_age       14d     default                                    |
|  stale_after          12h     environment                                |
|  metadata_max_age     7d      default                                    |
|  unsupported OS rule  on      default                                    |
|                                                                          |
|  Lifecycle data as of 2026-10-01 (shipped with this release)             |
|                                                                          |
|  Webhook: configured  (URL and secret are not shown)                     |
+--------------------------------------------------------------------------+
| Exceptions (later: not in v0.1.0)                                        |
|                                                                          |
|  HOST    SKIPS               REASON         OWNER   GRANTED   EXPIRES    |
|  db-02   curl:amd64          vendor patch   <owner> 10-20     11-19      |
|  app-09  reboot rule         maintenance    <owner> 10-15     11-14      |
|                                                                          |
|  Expired exceptions are not listed here; the host history keeps the      |
|  exceptions that applied to each state.                                  |
+--------------------------------------------------------------------------+
```

**Data.**

| Shown | Source |
| --- | --- |
| Settings, values, `off` | The loaded policy ([policy, configuration](policy.md#configuration-policy-as-code)). |
| Source of each value | Precedence in the policy: environment variable, then file, then default. The file format and variable names are defined in phase 7. |
| Fingerprint | The `policy_fingerprint` that new transitions record. |
| Lifecycle date | The lifecycle table's `snapshot_date` (AC-3.4). |
| Webhook | Whether a webhook is configured. The URL and the secret are never sent to the browser (AC-6.5; [threat model](../threat-model.md), T-14). |
| Exceptions | The exceptions in the configuration: `id`, host `id` (shown by its name), what is skipped, reason, owner, `granted_at`, `expires_at` ([domain model, exceptions](domain-model.md#exceptions)). Built later ([roadmap](roadmap.md#designed-now-built-later)); in v0.1.0 the section is not drawn. The rows are illustrative. |

**Actions.** None, for anyone (AC-6.2). An admin sees the same page as a viewer.

**Covers.** UC-9; AC-6.1 (the values after a restart), AC-6.2 (read-only with the source of each value), AC-6.5 (webhook from configuration only).

## Not in these sketches

Login, user management and the agent installation guide are separate screens or documents, designed with their phases (3, 5 and 6). Metrics live in Grafana, not in the web UI (AC-7.2).

## Open questions

Found while drawing, each one with its issue.

1. **Install command after enrollment.** The enrollment screen could show a ready-to-copy install command, but the server does not know the URL the hosts use to reach `/api/v1/agent/`: behind the split recommended in the [architecture](../architecture.md#exposure) it is not the URL of the web UI. Either a configured *agent base URL* is added, or the screen only links to the agent documentation. Related: [#38](https://github.com/andresBR8/patchconi/issues/38). Tracked in [#41](https://github.com/andresBR8/patchconi/issues/41).
2. **Clock skew.** The [vision](vision.md#requirements-from-other-peoples-environments) says a large clock skew is flagged. The data exists (`report.agent_collected_at` against `received_at`), but no threshold is defined in the policy or the model, so the sketches do not draw a flag. Tracked in [#42](https://github.com/andresBR8/patchconi/issues/42).
3. **Which report refreshes *last report* and *stale*.** The policy counts from «the host's last valid report». A report that is valid but not applied (`fingerprint_mismatch`, `superseded_instance`, `sequence_regression`) is still a valid report: if it refreshes the stale clock, someone with a stolen token keeps a dead host from showing *no data*. The sketches count from the last applied report and show the last received one next to it. Tracked in [#43](https://github.com/andresBR8/patchconi/issues/43).
4. **Who cleared an agent alert.** Clearing an alert is an administrator action, but the model has no record of who cleared it or when (rotation and revocation record `revoked_by`). The same holds for renaming a host and editing its labels. Tracked in [#33](https://github.com/andresBR8/patchconi/issues/33).
5. **Parser error details.** The report's `packages.error` carries the message, the command and its exit code (which can be null), but the model stores only `report.parse_error`. The host detail needs the command to tell a broken repository from a missing tool: either the model stores the three fields, or the screen shows the message only. Tracked in [#44](https://github.com/andresBR8/patchconi/issues/44).
