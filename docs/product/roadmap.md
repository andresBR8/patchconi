# Roadmap

> Status: v1 (phase 1), approved when phase 1 closed. Later changes go through a pull request. Nothing here is a commitment; it is where ideas go instead of growing the v0.1.0 scope.

What v0.1.0 includes is defined in the [product vision](vision.md#mvp-acceptance-criteria-v010). What PatchConi will never do is listed under [out of scope](vision.md#out-of-scope).

## Designed now, built later

These features are not in v0.1.0, but the [data model](domain-model.md) and the agent protocol v1 are designed so that adding them does not need a breaking change. Each item says what v1 must already allow.

| Feature | What it does | What v1 must allow |
| --- | --- | --- |
| **Exposure time** | When each update was resolved, and the mean time to patch per host and for the fleet. | Each pending update keeps *pending since* and gets a *resolved at* when it disappears from the reports. |
| **Exceptions that expire** | Accept a pending update or a rule for a host, with a reason, an owner and an end date. When it expires, it counts for the policy again. Exceptions are policy as code ([ADR 0019](../adr/0019-patch-policy-as-code.md)): declared in the policy file, never created in the UI, with a mandatory end date and a configurable maximum duration (90 days by default). | The policy evaluation has a place to skip a rule for a host until a date; an exception points at the host's stable ID; each state transition keeps a copy of the exceptions that applied, so an expired exception stays visible in the history ([domain model](domain-model.md#exceptions)). |
| **Installed package inventory** | Search "which hosts have package X at version Y", for example `xz-utils` during [CVE-2024-3094](https://nvd.nist.gov/vuln/detail/CVE-2024-3094). | An optional inventory section in the report, which v1 can add without breaking older agents or servers. |
| **Watched software** | The user picks the packages that matter (php, nginx, openssl, postgresql…) and sees which version each host runs and whether its branch is still supported. Distribution packages are not compared with the latest upstream version: distributions backport security fixes without changing the version, so what counts is what is pending in the distribution's repositories and whether the branch is supported. | Same as the inventory, plus the lifecycle table. |
| **Prioritization by exploited vulnerabilities** | Use [OSV](https://osv.dev/) data with CISA's [Known Exploited Vulnerabilities](https://www.cisa.gov/known-exploited-vulnerabilities-catalog) catalog (and perhaps EPSS) to rank pending updates, and thresholds by risk. Optional, and if possible without sending the inventory outside the installation. | The report carries the advisory IDs the package manager provides (for example from `dnf updateinfo`). |
| **Report after package changes** | An apt hook and a dnf plugin that only start the agent's service after a package transaction, so a patch run is confirmed at once. Idea taken from Patchman. | The agent can be started at any time; the server handles reports that arrive close together. |
| **Host labels and groups** | Labels on hosts now; policies per group, alert routing per group and scheduled reports later. | Hosts have labels in the data model from v0.1.0. |
| **Exportable compliance report** | CSV or JSON for an audit; signed, later. | History keeps enough to rebuild the state of a host on a past date. |
| **Remediation through integrations** | PatchConi detects and verifies; Ansible acts, with its own credentials. Export a dynamic Ansible inventory with groups such as `out_of_policy` and `security_pending`, and optionally start an AWX or Ansible Automation Platform job template through its API. Starting a job means PatchConi stores a token that can cause changes on hosts: that part is optional, uses the token of a dedicated account whose only permission (through AWX/AAP role-based access control) is to execute that one job template, and gets its own ADR when it is built, because it changes the threat model. | A read-only API that lists hosts by state. |

A patching module inside PatchConi was considered and rejected for v1: see [PatchConi does not patch](vision.md#patchconi-does-not-patch).

## Candidates for v0.2.0

- **Policy and alerts, metrics**, if they do not make it into v0.1.0 (they are marked *Important* in the MVP).
- **Hosts marked as always on**, so that *no data* can alert for them without paging anyone for a laptop that is switched off.
- The first items of the table above, starting with exposure time and exceptions.

## Later

- More package managers: zypper (openSUSE, SLES), apk (Alpine), pacman (Arch).
- More distributions moving from *supported* to *tested in CI* (see the [support matrix](vision.md#support-matrix)).
- Helm chart, next to the Kustomize base.
- Single sign-on with OIDC.
- OpenTelemetry traces.
- Ingestion as a separate service with a queue, for fleets well above the v0.1.0 target of 200 hosts.
