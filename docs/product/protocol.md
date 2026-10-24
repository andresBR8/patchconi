# Agent protocol v1

How the agent reports to the server. The report schema, the OpenAPI draft and the transport rules are added to this document with the schema; this first part records what the [captures](../../protocol/captures/README.md) showed about `apt` and `dnf`, because several protocol fields depend on it.

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
- Still open: whether Debian writes the stamp, and which repository's age counts on `dnf` when the cached repositories differ.

### 2. The `apt-daily` delay after boot

**What the captures show.**

- `apt-daily.timer` on Ubuntu 24.04 runs at 06:00 and 18:00 with `RandomizedDelayUSec=12h` and `Persistent=yes`. When a host boots after missing runs, the timer fires, but the refresh can wait up to 12 hours.
- The Ubuntu host had been up for 80 minutes and its package lists were 9 days old.
- `apt-daily-upgrade.timer` has a delay of 1 hour, so it often runs first: `unattended-upgrades` ran at 20:59 with those 9-day-old lists.

**Consequences.**

- A host that is only switched on for a few hours, like Alex's machines ([vision](vision.md#who-it-is-for)), can spend most of its uptime with stale metadata. It shows as *no data* when the age exceeds `metadata_max_age` ([policy](policy.md#default-thresholds)).
- The panel has to say why the data is stale, and the documentation has to warn operators of such hosts.
- On `dnf`, `dnf-makecache.timer` has `RandomizedDelayUSec=1h`.

### 3. What counts as pending on `apt`

**What the captures show.**

- On the Ubuntu host, `apt list --upgradable` lists 21 packages, `apt-get -s upgrade` would install 18, and `apt-mark showhold` lists 5 held packages.
- The containers show the difference for a held package: after `apt-mark hold base-files`, `apt list --upgradable` still lists it, and `apt-get -s upgrade` keeps it back.
- The host capture holds counts only, so it does not say which 3 packages `apt-get` leaves out: held packages with an update, Ubuntu phased updates, or upgrades that need new packages. The containers have no phased updates.

**Still open.** Whether held packages and phased updates start a policy clock. The report v1 carries both lists: the updates, and the held packages.

### 4. Running without root on `dnf`, and advisories

**What the captures show.**

- On the Rocky host, as an unprivileged user, `dnf -C` reads the system cache. `check-update` lists 6 updates with or without `--setopt=cachedir=/var/cache/dnf`.
- `dnf needs-restarting -r` detects the pending reboot: the newest installed kernel is not the running one.
- The [ADR 0007](../adr/0007-agent-in-go.md) hypothesis holds for listing updates without root on both hosts.
- On the host, `dnf -C updateinfo list --updates` returns 0 advisories for the 6 updates, which come from `baseos`. The maintainer saw the same result as a user with more groups.
- In the containers, which refresh the metadata as root, every RHEL-family distribution returns advisories (95 on Rocky Linux 10).

**Still open.** Whether the host's cache lacks the advisory data, or those updates have no advisory yet. This decides whether `security` and advisory dates can be trusted on `dnf` without root.

### 5. A missing `dnf` plugin is not an error

**What the captures show.**

- Without the versionlock plugin, `dnf versionlock list` prints `No such command` and exits with 1.
- Without `dnf-plugins-core`, which is the case in the Rocky containers, `dnf needs-restarting -r` prints the same message and also exits with 1. Exit code 1 is also how `needs-restarting -r` says that a reboot is required.

**Rules for the agent.**

- No versionlock plugin means no held packages: the agent reports an empty list, not an error.
- The agent checks whether a plugin is installed before running its command. It never infers that from the exit code or from the message.
- Without `needs-restarting`, the agent sends `reboot_required` as unknown, not as `true`.

### 6. Times from `systemctl`

**What the captures show.** `systemctl show --timestamp=utc` still printed `LastTriggerUSec` in the host's local time zone (CEST).

**Rule for the agent.** It never parses formatted dates from command output. It reads the raw values in microseconds since the epoch, and sends times in UTC.
