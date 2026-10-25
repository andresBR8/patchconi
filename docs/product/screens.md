# Screens

> Status: draft (phase 1). Low-fidelity sketches of the four main screens of the web UI. They fix **what each screen shows and allows**, not how it looks: layout, colors and components are decided in phase 6.

Each sketch lists where every value comes from (an entity or column of the [domain model](domain-model.md), or a document that defines it), the actions and who can take them, and the use cases and acceptance criteria from the [vision](vision.md#mvp-acceptance-criteria-v010) it covers. A value the model does not have is not drawn: it is an [open question](#open-questions).

The sketches use invented, generic data (`web-01`, `db-02`, `example` packages). Versions and dates are illustrative.

## Rules for every screen

- **Report text is untrusted.** Package names, versions, repositories, advisory IDs, kernel strings, operating system names and parser error messages come from the host, and a compromised host can write anything there. The web shows them as escaped text, never as HTML, Markdown or a link ([protocol, untrusted text](protocol.md#untrusted-text); [threat model](../threat-model.md), T-05). Host names and labels are written by administrators and are escaped the same way.
- **A viewer sees everything and changes nothing.** Write actions (marked **[admin]** below) are not rendered for a viewer: no disabled buttons, no hidden forms. The API still answers every write from a viewer with `403` (AC-5.2); hiding the button is a courtesy, not the control.
- **Every page needs a session.** There are no anonymous views ([threat model](../threat-model.md), T-08).
- **Times.** Shown in the browser's local time with its time zone visible (`2026-10-25 14:03 CEST`). The host detail also shows each time in UTC (`2026-10-25T12:03Z`). Nothing depends on hovering: every value is reachable by touch and keyboard. Times measured on the host (`agent_*` columns) are labelled *as reported by the host*.
- **No state is told apart by color alone.** Every state is written as a word, with an icon that has a text label. In the sketches: `[OUT]` out of policy, `[PEND]` pending updates, `[OK]` up to date, `[NO DATA]` no data, `[!]` agent alert, `[SEC]` security update.
- **The lifecycle data date is always visible** where an operating system support status is shown: «lifecycle data as of YYYY-MM-DD» (AC-3.4).
- **Lists show text, not counts alone.** A count always links to the list of what it counts.

## 1. Fleet overview

The landing page. Answers «which hosts need attention, and why», in that order.

```text
+--------------------------------------------------------------------------+
| PatchConi                         Fleet  Hosts  Policy      sam (admin)  |
+--------------------------------------------------------------------------+
| Fleet overview                 As of: [ now v ]  Times: CEST (UTC+2)     |
|                                                                          |
|  [OUT] Out of policy   3   [PEND] Pending  5   [OK] Up to date  12       |
|  [NO DATA] No data     2                       Total enrolled   22       |
|                                                                          |
|  ! 1 host with an agent alert                       -> show              |
|  ! 2 hosts on an unsupported OS  (lifecycle data as of 2026-10-01)       |
|  ? 1 host with unknown lifecycle                                         |
|  ~ 4 hosts, 37 updates pending before enrollment, real age unknown       |
|                                                                          |
|  Filter: state [all v]  label [env=prod v]  name [________]              |
|                                                                          |
|  STATE      HOST     WHY                                  LAST REPORT    |
|  [OUT]      db-02    security update pending > 14d        3 days ago     |
|                      (openssl:amd64, since 2026-10-03)                   |
|                      · data 3 days old                                   |
|  [OUT]      web-03   OS no longer supported               40 min ago     |
|                      (Ubuntu 20.04, ended 2025-05-31)                    |
|  [OUT][!]   app-07   reboot required > 14d (since 10-08)  1h ago         |
|                      agent alert: fingerprint_mismatch                   |
|  [NO DATA]  nas-01   package metadata too old (12 days)   3h ago         |
|                      last boot 3h ago (as reported)                      |
|  [NO DATA]  sbc-02   never reported                       -              |
|  [PEND]     web-01   4 pending (1 [SEC])                  25 min ago     |
|  ...                                                                     |
+--------------------------------------------------------------------------+
```

**Order of the list.** *Out of policy* first, then *no data*, *pending updates* and *up to date*; inside each state, the oldest breach or the oldest data first. A breach is never pushed below the fold by a long list of healthy hosts.

**Data.**

| Shown | Source |
| --- | --- |
| Counts per state, total enrolled | The state of each active host (not retired), from the policy evaluation ([domain model, from facts to a state](domain-model.md#from-facts-to-a-state)). Retired hosts are not counted ([retiring a host](domain-model.md#retiring-a-host)). |
| *Why* for out of policy | Every broken rule, from the evaluation's reasons (`host_state_transition.reasons` for the past), with the package, the clock it counts from (`pending_since`, `security_since`, `reboot_required_since`) and `effective_at`. |
| «· data N days old» | The host is also stale ([policy, states](policy.md#states)): age of the last report or of the package metadata. |
| *Why* for no data | One of the three causes in the [policy](policy.md#what-the-ui-shows-next-to-the-state): never reported, last report older than `stale_after`, or package metadata older than `metadata_max_age` (`report.agent_metadata_age`). For the metadata cause, the last boot (`report.agent_last_boot_at`) is shown next to it, because a host booted a few hours ago is often waiting for `apt-daily` ([protocol, finding 2](protocol.md#2-the-apt-daily-delay-after-boot); [#26](https://github.com/andresBR8/patchconi/issues/26)). |
| Unsupported OS, unknown lifecycle | The lifecycle rule of the evaluation, against the lifecycle table and its `snapshot_date` (AC-3.4). |
| Pending before enrollment | Hosts with at least one open episode with `pending_update.before_enrollment`, and the number of such episodes (AC-3.5). |
| Agent alert | `host.agent_alert_at`, `host.agent_alert_reason` ([invariant 1](domain-model.md#invariants-and-backend-rules)). |
| Last report | `report.received_at` of the host's last report (server clock). See [question 3](#open-questions). |
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
|  [ Enroll a host ]          <- admin only                                |
|                                                                          |
|  (viewer sees instead:) An administrator has not enrolled any host yet.  |
+--------------------------------------------------------------------------+
```

The counts are not drawn: four zeros and a total of zero say nothing useful.

## 2. Host detail and history

Everything PatchConi knows about one host, and its state on a past date.

```text
+--------------------------------------------------------------------------+
| < Fleet    db-02   env=prod team=db                   [OUT] Out of policy |
+--------------------------------------------------------------------------+
| ! Agent alert since 2026-10-24 09:12 CEST: fingerprint_mismatch          |
|   A report came from a machine whose fingerprint differs from the known  |
|   one. It was stored and not applied.                                    |
|   [ Rotate token ] (recovers the host)  [ Clear alert ]   <- admin only  |
+--------------------------------------------------------------------------+
| Why     security update pending > 14 days (openssl:amd64)                |
|         since 2026-10-03 · breach from 2026-10-17 14:00 CEST             |
|         data 3 days old: last report 2026-10-22 10:04 CEST               |
|                                                                          |
| OS      Ubuntu 24.04.3 LTS (ubuntu 24.04) · x86_64 · apt · ESM: off      |
|         supported until 2029-05-31 (lifecycle data as of 2026-10-01)     |
| Kernel  running        6.8.0-140-generic                                 |
|         newest install 6.8.0-147-generic   -> differs                    |
| Reboot  required since 2026-10-20 08:00 CEST (server clock)              |
| Boot    2026-10-12 07:41 CEST (as reported by the host)                  |
| Report  received 2026-10-22 10:04 CEST · 2026-10-22T08:04Z               |
|         package metadata 2 h old (as reported) · agent 0.1.0             |
+--------------------------------------------------------------------------+
| Pending updates (4)                     ~ = pending before enrollment    |
|                                                                          |
|  PACKAGE         INSTALLED    CANDIDATE    PENDING SINCE  SECURITY SINCE |
|  [SEC] openssl   3.0.13-0u1   3.0.13-0u2   2026-10-03     2026-10-03     |
|        :amd64    repo: noble-security · advisory: -                      |
|  [SEC] libexa    1.2-1        1.2-2        ~2026-10-01    ~2026-10-01    |
|        :amd64    repo: noble-security · real age unknown                 |
|  curl:amd64      8.5.0-2u1    8.5.0-2u4    2026-10-10     -              |
|  libfoo:amd64    2.0-1        2.1-1        2026-10-15     -   (held)     |
|                                                                          |
| Held packages (2): libfoo:amd64, linux-image-generic:amd64               |
+--------------------------------------------------------------------------+
| History                                    State on: [ 2026-10-10 v ]    |
|                                                                          |
|  On 2026-10-10: [PEND] Pending updates · 2 pending (1 [SEC])             |
|                 open that day: openssl:amd64, libexa:amd64               |
|                                                                          |
|  EFFECTIVE AT           STATE        WHY                                 |
|  2026-10-17 14:00 CEST  [OUT]        security update > 14d (openssl)     |
|  2026-10-03 09:05 CEST  [PEND]       1 pending                           |
|  2026-09-28 11:30 CEST  [OK]         -                                   |
|  ...                    history kept 90 days                             |
+--------------------------------------------------------------------------+
```

### Parser error (AC-8.7)

When the host's last applied report has `parse_status = error`, the update list is replaced by the error, and the rest of the page still shows what the report did carry:

```text
+--------------------------------------------------------------------------+
| Package list unavailable: the agent could not parse the package          |
| manager's output in the last report (2026-10-25 11:02 CEST).             |
|                                                                          |
|   command    dnf -C check-update                                         |
|   exit code  1                                                           |
|   message    Error: Failed to download metadata for repo 'example'       |
|                                                                          |
| The OS, kernel and reboot fields above come from this report, so the     |
| lifecycle rule still applies. Updates already pending stay open: a       |
| report with a parser error never resolves them.                          |
+--------------------------------------------------------------------------+
```

### Host without reports yet

```text
+--------------------------------------------------------------------------+
| < Fleet    sbc-02                                    [NO DATA] No data   |
|                                                                          |
|  Never reported. Enrolled 2026-10-25 10:00 CEST by sam.                  |
|  Install the agent with the token shown at enrollment.  <- admin only    |
|  Lost the token? [ Rotate token ]                       <- admin only    |
+--------------------------------------------------------------------------+
```

The token is never shown again (AC-1.1); the way forward for a lost token is rotation.

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
| Last report | `report.received_at`. |
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
| Clear alert | Admin | Clears `agent_alert_at` and `agent_alert_reason`. It does not change which reports are applied: the screen says so next to the button. See [question 4](#open-questions). |

**Covers.** UC-4, UC-5, UC-8 (a host switched off keeps its clocks; its state on any day is in the history); AC-4.1, AC-4.2, AC-4.3, AC-4.4, AC-8.2, AC-8.7.

## 3. Hosts and tokens

Enrollment and the life of each host's credentials.

```text
+--------------------------------------------------------------------------+
| Hosts                                  Show: (o) active  ( ) retired     |
|                                                    [ Enroll a host ] (a) |
|                                                                          |
|  HOST     LABELS          ENROLLED           TOKEN LAST USED             |
|  db-02    env=prod        2026-09-01 by sam  2026-10-22 10:04 CEST  [...]|
|  sbc-02   -               2026-10-25 by sam  never                  [...]|
|  ...                                                                     |
|                                                                          |
|  [...] menu (admin only): Edit name and labels · Rotate token ·          |
|        Revoke token · Retire host                                        |
+--------------------------------------------------------------------------+

Enroll a host (admin)
+--------------------------------------------------------------------------+
|  Name   [ sbc-02          ]   unique among active hosts                  |
|  Labels [ env=lab         ]   key=value                                  |
|                                              [ Cancel ] [ Create ]       |
+--------------------------------------------------------------------------+

After Create (shown once)
+--------------------------------------------------------------------------+
|  Token for sbc-02 — copy it now. It will not be shown again.             |
|                                                                          |
|  [ <token>                                             ] [ Copy ]        |
|                                                                          |
|  Leaving this page discards it. If it is lost, rotate the token.         |
|  Next: install the agent with this token (see the agent docs).           |
|                                                       [ Done ]           |
+--------------------------------------------------------------------------+

Token history of db-02
+--------------------------------------------------------------------------+
|  ID (public part)  CREATED            REVOKED            LAST USED       |
|  <lookup id>       2026-10-24 by sam  -                  2026-10-25      |
|  <lookup id>       2026-09-01 by sam  2026-10-24 by sam  2026-10-24      |
+--------------------------------------------------------------------------+
```

**Confirmations.** Rotate, revoke and retire each ask for confirmation and say what happens:

- **Rotate:** «The current token stops working now. The agent on db-02 will be rejected until it gets the new token.» Whether the old token keeps a short grace period is [#14](https://github.com/andresBR8/patchconi/issues/14); the text changes if it does.
- **Revoke:** «Reports from db-02 will be rejected with 401. Its history stays.» (AC-1.4)
- **Retire:** «db-02 leaves the fleet: its tokens are revoked, it is no longer evaluated or counted, and its pending updates are frozen as they are. This cannot be undone. The name can be reused by a new host.» ([retiring a host](domain-model.md#retiring-a-host))

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

**Covers.** UC-1, UC-7; AC-1.1, AC-1.2, AC-1.3, AC-1.4, AC-5.2. Install instructions: see [question 1](#open-questions).

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
|  web-03  unsupported OS      migration      <owner> 10-01     12-30      |
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
| Exceptions | The exceptions in the configuration: `id`, host `id` (shown by its name), what is skipped, reason, owner, `granted_at`, `expires_at` ([domain model, exceptions](domain-model.md#exceptions)). Built later ([roadmap](roadmap.md#designed-now-built-later)); in v0.1.0 the section is not drawn. |

**Actions.** None, for anyone (AC-6.2). An admin sees the same page as a viewer.

**Covers.** UC-9; AC-6.1 (the values after a restart), AC-6.2 (read-only with the source of each value), AC-6.5 (webhook from configuration only).

## Not in these sketches

Login, user management and the agent installation guide are separate screens or documents, designed with their phases (3, 5 and 6). Metrics live in Grafana, not in the web UI (AC-7.2).

## Open questions

Found while drawing; each one is tracked as an issue before the phase closes.

1. **Install command after enrollment.** The enrollment screen could show a ready-to-copy install command, but the server does not know the URL the hosts use to reach `/api/v1/agent/`: behind the split recommended in the [architecture](architecture.md#exposure) it is not the URL of the web UI. Either a configured *agent base URL* is added, or the screen only links to the agent documentation. Related: [#38](https://github.com/andresBR8/patchconi/issues/38).
2. **Clock skew.** The [vision](vision.md#requirements-from-other-peoples-environments) says a large clock skew is flagged. The data exists (`report.agent_collected_at` against `received_at`), but no threshold is defined in the policy or the model, so the sketches do not draw a flag.
3. **Which report refreshes *last report* and *stale*.** The policy counts from «the host's last valid report». A report that is valid but not applied (`fingerprint_mismatch`, `superseded_instance`, `sequence_regression`) is still a valid report: if it refreshes the stale clock, someone with a stolen token keeps a dead host from showing *no data*. The fleet overview has to say which report it means.
4. **Who cleared an agent alert.** Clearing an alert is an administrator action, but the model has no record of who cleared it or when (rotation and revocation record `revoked_by`). The same holds for renaming a host and editing its labels.
