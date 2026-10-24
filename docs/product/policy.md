# Patch policy

> Status: draft (phase 1).

The patch policy turns what the agents report into one state per host. It is the definition behind every number on the fleet overview, every alert and every metric.

## What the policy looks at

For each host, from its last report and the server's own records:

- **Pending updates**, each with a flag saying whether it is a security update (from the distribution's security repository or advisory data).
- **Pending since** and **security since**: the two clocks for the update thresholds, and the basis for measuring exposure time later (see the [roadmap](roadmap.md)). How they are set is explained [below](#how-pending-since-is-set).
- **Reboot required**, and since when the server has seen it required.
- **Operating system and version**, from `/etc/os-release`, checked against the lifecycle table (see [Unsupported operating systems](#unsupported-operating-systems)).
- **Last report**: when the server received the host's last valid report (server clock).
- **Package metadata age**: how old the host's package lists were when the agent ran.

### How *pending since* is set

Compliance frameworks count from the day a patch was released. PatchConi cannot always know that day: `apt` does not report a release date for an update, and `dnf` reports an advisory date only when advisory data exists. So, for each package with an update pending on a host:

- **With an advisory date** (the advisory's *issued* date from `dnf updateinfo`): *pending since* is the earlier of the advisory date and the first time the server saw the update pending on that host.
- **Without an advisory date** (`apt`, or `dnf` without advisory data): *pending since* is the first time the server saw the update pending, measured with the server's clock, which does not depend on host clocks.
- **The clock is per package, not per version.** A package is identified by its name and architecture: `libc6:amd64` and `libc6:i386` (or `glibc.x86_64` and `glibc.i686`) have separate clocks. If a newer version of the package arrives before the old update is installed, the clock keeps running: the host has been behind on that package since the first pending version.
- **Security updates have their own clock, *security since*.** It is the earlier of the first time the server saw a security update pending for the package and the advisory date of that update (when there is one). `security_max_age` counts from *security since*; `other_max_age` counts from *pending since*. Without a separate clock, a security update that appears today on a package that has had a bug-fix update pending for 20 days would be *out of policy* on its first day.
- **Clocks only move earlier, and *pending since* is never later than *security since*.** If a security update arrives with an advisory date earlier than the package's *pending since*, *security since* moves back to that date and *pending since* moves with it: the host has been behind on the package at least since then.
- **Any report whose parser succeeded can start a clock; only a trusted report can stop one.** An update listed as pending is real even when the package metadata is old: at worst the list is incomplete. An update missing from the list only means it was installed when the metadata is recent. So a clock stops when a trusted report (see below) no longer lists any update for the package; a report whose parser failed, or whose package metadata is older than `metadata_max_age`, never stops a clock. Otherwise deleted package lists (`/var/lib/apt/lists`) would make every update look installed.
- **Advisory dates are checked.** They come from the repository metadata, not from the host clock, but the agent reports them. A date later than the server's receive time is ignored and the first-seen time is used. Taking the earlier of the two dates means a wrong advisory date can make an update look older, never younger.

The first-seen time alone would let a host that has gone unpatched for months spend another `security_max_age` (14 days by default) without being *out of policy*, just because it was enrolled today. To avoid hiding that:

- Updates without an advisory date that are still pending when a host's **first trusted report** arrives are marked **pending before enrollment, real age unknown**. A trusted report is one whose parser succeeded and whose package metadata is within `metadata_max_age`; the first trusted report is the first such report from the host. This includes updates first seen in earlier reports with stale metadata: until the first trusted report, PatchConi cannot tell what else was pending. A marked update keeps its clocks, which start at the first time the server saw it pending, the only date PatchConi can prove; the mark stays until no update for the package is pending.
- The fleet overview shows how many hosts and how many updates carry that mark, and the host detail shows it on each update. A reviewer can see that the age is a lower bound, not the real one.

## States

Every host is in exactly one state. The rules are evaluated in this order; the first that matches wins.

| Order | State | The host is in this state when |
| --- | --- | --- |
| 1 | **No data** | It has never sent a valid report. |
| 2 | **Out of policy** | At least one rule below is broken, judged on the last report received. |
| 3 | **No data** | Its last report is older than `stale_after`, **or** its package metadata was older than `metadata_max_age` when the agent ran. |
| 4 | **Pending updates** | It has pending updates, or a reboot required, but no rule is broken yet. |
| 5 | **Up to date** | No pending updates and no reboot required. |

Rules for *out of policy*:

- A **security update** has been pending longer than `security_max_age`, counted from *security since*.
- **Any update**, security or not, has been pending longer than `other_max_age`, counted from *pending since*.
- A **reboot** has been required for longer than `reboot_max_age`.
- The **operating system is no longer supported** by its vendor, even with zero pending updates: it no longer receives patches, so *up to date* would be misleading.

A host is **stale** when it matches row 3: it has reported before, but its data is too old to trust. Stale is not a state of its own; it shows as *no data*, or next to *out of policy* (see below).

Why this order:

- **Out of policy wins over stale.** The clocks run on the server, so a known breach keeps counting while the host is silent. Otherwise a broken agent, or an attacker who stops it, would turn a breach into *no data* just by stopping the reports. The consequence: a host switched off for weeks with an update pending becomes *out of policy* while it is off. That is intended, because the update is still not installed.
- **Stale wins over pending and up to date.** PatchConi cannot vouch for a host it has not heard from recently, or one whose package lists are too old to know what is pending. *No data* is not a policy breach, and in v0.1.0 it raises no alert, so a switched-off host does not page anyone. Alerts on *no data* for hosts marked as always on are in the [roadmap](roadmap.md#candidates-for-v020).

### What the UI shows next to the state

The state is one word, but the UI never hides the other facts:

- Every broken rule of an *out of policy* host.
- The age of the data when it is stale, also for *out of policy* hosts: «out of policy · data 3 days old».
- The reason for *no data*: never reported, last report too old, or package metadata too old.
- *Unknown lifecycle* when the operating system is not in the lifecycle table (see below).
- *Pending before enrollment, real age unknown* on the updates that carry that mark (see [How pending since is set](#how-pending-since-is-set)).

States are evaluated when a report arrives **and** when the state is read, because time alone changes them: a host can move to *out of policy* or *no data* without sending anything.

## Unsupported operating systems

Each PatchConi release ships a **lifecycle table**: for every distribution and version, the date its vendor stops publishing security updates. It is a snapshot taken when the release is built, from [endoflife.date](https://endoflife.date/) (MIT License, credited in the release notes). PatchConi never queries it at run time: the server may have no internet access, and an external API should not change a host's state.

- The web UI and the API show the snapshot date: «lifecycle data as of YYYY-MM-DD».
- This is about the **vendor's** security support for the operating system. Which distributions the PatchConi agent works on is a different list: the [support matrix](vision.md#support-matrix).
- **Supported by the vendor** means the vendor still publishes security updates in repositories the host can use. Free long-term support that comes from the standard repositories counts (for example, Debian LTS). Extended support that needs enrollment, such as Ubuntu Pro's Expanded Security Maintenance (free for personal use on up to 5 machines, paid otherwise), counts only if the host reports that its ESM repositories are enabled.
- An operating system that is **not in the table** (a new release, a distribution the table does not know) is **unknown lifecycle**: the UI flags it, but it is not *out of policy*. A new distribution must not show up in red because the table in the release is older.

## Default thresholds

| Setting | Default | Reasoning |
| --- | --- | --- |
| `security_max_age` | 14 days | See below. |
| `other_max_age` | 30 days | CIS Controls v8, Safeguard 7.3 asks for operating system updates through automated patch management "on a monthly, or more frequent, basis" ([CIS Controls Assessment Specification, 7.3](https://controls-assessment-specification.readthedocs.io/en/latest/control-7/control-7.3.html)). Non-security updates carry bug fixes; a monthly cycle is the common baseline. |
| `reboot_max_age` | 14 days | A required reboot usually means a new kernel or core library is installed but not running: the fix is not active until the host reboots. It is treated like a pending security update. |
| `stale_after` | 24 hours | See below. |
| `metadata_max_age` | 7 days | The distributions refresh package metadata on their own timers: `dnf-makecache.timer` runs about every hour ([upstream unit file](https://github.com/rpm-software-management/dnf/blob/829fa0a6187bd449b8fc9b51d2e3d11a470bd9bb/etc/systemd/dnf-makecache.timer): `OnUnitInactiveSec=1h`), and `apt-daily.timer` runs daily or more often (the exact schedule is checked in the phase 1 captures). Metadata a week old means the refresh is broken or the host cannot reach its repositories, so "no pending updates" cannot be trusted. |

### `security_max_age`: why 14 days

v0.1.0 knows whether an update is a security update, but not how severe it is, whether it is being exploited, or whether the host is exposed to the internet (that needs vulnerability data, planned in the [roadmap](roadmap.md)). So one threshold covers every security update, and it has to work for the worst and the most harmless ones alike.

- **Upper bound, 30 days.** PCI DSS v4.0.1, Requirement 6.3.3, requires patches for **critical** vulnerabilities to be installed within one month of release. A default of 30 days for *every* security update would be exactly the deadline for critical ones, with no margin.
- **Lower bound, 3 days.** CISA's BOD 26-04 (June 2026) requires the **highest-risk** vulnerabilities (exposed, exploited, automatable, full control) to be patched within three days, and allows longer timelines for lower-risk ones ([CISA, "Patch Smarter, Not Harder"](https://www.cisa.gov/news-events/news/patch-smarter-not-harder)). Applied to every security update without knowing the risk, 3 days would keep most of a small fleet out of policy all the time, and an alert that is always on gets ignored.
- **14 days** sits between the two: two weekly maintenance windows, and the same deadline the previous CISA directive, BOD 22-01, set for known exploited vulnerabilities ([BOD 22-01, revoked](https://www.cisa.gov/news-events/directives/bod-22-01-reducing-significant-risk-known-exploited-vulnerabilities-revoked)).

Alternatives: **7 days** (stricter, fits teams that patch weekly) or **30 days** (only the PCI DSS deadline). Risk-aware thresholds come with vulnerability data.

> Note: the PCI DSS text is behind the PCI SSC document library's license agreement; the wording above is to be checked against the official v4.0.1 document before the phase closes ([issue #15](https://github.com/andresBR8/patchconi/issues/15)).

### `stale_after`: why 24 hours

The agent reports every hour from a systemd timer that catches up after boot. A host is *stale* when the server has not heard from it for a while, but "a while" depends on who runs the fleet:

- Sam's servers are always on: three missed hours already mean something is wrong.
- Alex's machines are switched off at night or for days: a short threshold turns every night into a wall of *no data*.

24 hours covers a machine switched off overnight and still flags a server that missed a whole day. Teams with always-on fleets can lower it. Because *no data* is not a breach and raises no alert, a powered-off host does not page anyone.

Alternative: **3 × the agent interval** (3 hours by default), better for always-on fleets, noisy for the others.

## Configuration: policy as code

The policy is configuration, not data edited in the UI ([ADR 0019](../adr/0019-patch-policy-as-code.md)):

- It is read from a **file** that can live in version control, and each setting can be overridden by an **environment variable**. Precedence: environment variable, then file, then the defaults above. The file format and the variable names are defined in phase 7.
- The web UI **shows** the active policy, read-only, with where each value comes from.
- Thresholds are durations (`14d`, `24h`). The value `off` disables a rule; `0` is not accepted, because it could be read as "zero tolerance". The unsupported operating system rule can be turned `off` too.
- Changing the policy and restarting the server recalculates every host.
- v0.1.0 has one global policy. Policies per group of hosts are in the [roadmap](roadmap.md).
