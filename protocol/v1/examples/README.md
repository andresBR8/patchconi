# Report examples, protocol v1

Reports that must pass [`report.schema.json`](../report.schema.json), built from the [captures](../../captures/README.md), and reports in `invalid/` that must fail. The `check-protocol` pre-commit hook checks both. Each invalid report changes one field of a valid one, and [`invalid/expected.tsv`](invalid/expected.tsv) lists the error it must fail with.

## Where each value comes from

Package lines are a few of the updates in the capture, copied as the package manager printed them, not the full list. Capture times are in UTC.

| Example | Capture | Updates shown | Not from the capture |
| --- | --- | --- | --- |
| `ubuntu-24.04.json` | `containers/ubuntu-24.04` | 5 of 38 from `apt-list-upgradable` | IDs, `sequence`, `agent.version`, `last_boot_at` |
| `ubuntu-24.04-held-inventory.json` | `containers/ubuntu-24.04`, after `apt-mark hold base-files` | 2 of 38 from `apt-list-upgradable-held`; 5 of 92 packages from `dpkg-inventory` | The same, and `collected_at` |
| `debian-13.json` | `containers/debian-13` | 5 of 24 from `apt-list-upgradable` | IDs, `sequence`, `agent.version`, `last_boot_at` |
| `rocky-10-held.json` | `containers/rocky-10`, after `dnf versionlock add attr` | 4 of 98 from `dnf-check-update-held`; installed versions from `rpm-inventory`, advisories from `dnf-updateinfo-list` and their dates from `dnf-updateinfo-info` | IDs, `sequence`, `agent.version`, `last_boot_at` |
| `rocky-10.2-host-parse-error.json` | `hosts/rocky-10.2.txt` | None: the parser failed (AC-8.7) | IDs, `sequence`, `machine_fingerprint` (random), `agent.version`, the error message |

What the values show:

- **Containers** have no kernel package (`kernel.newest_installed` is null) and no machine ID was captured (`machine_fingerprint` is null). `uname -r` in a container prints the kernel of the machine that ran it.
- **Rules, not captured values.** `reboot_required` is null on apt: no package in these images maintains `/var/run/reboot-required`. `esm_enabled` is false on Ubuntu: Ubuntu Pro is not installed (`pro-version` exits with 127). `metadata_age_seconds` of `rocky-10-held.json` is `collected_at` minus the oldest `repomd.xml` time in `dnf-repodata-mtime` ([protocol](../../../docs/product/protocol.md#report-fields)).
- **apt** has no advisories: `advisories` is empty and `security` comes from the suite (`noble-security`, `stable-security`). The apt containers have no stamp to measure the metadata age, so it is null and those reports would not be trusted ([protocol](../../../docs/product/protocol.md#1-the-age-of-the-package-metadata)).
- **Held packages** differ by package manager. `apt list --upgradable` still lists a held package, so `base-files` is in both `updates` and `held`. `dnf check-update` no longer lists a locked one, so `attr` is only in `held`. Whether held packages start a policy clock is an open question ([protocol](../../../docs/product/protocol.md#3-what-counts-as-pending-on-apt)).
- **`rocky-10-held.json`** has `reboot_required` null: the container has no `needs-restarting` ([protocol](../../../docs/product/protocol.md#5-a-missing-dnf-plugin-is-not-an-error)). The dates are the advisories' `Updated` field, the only date `dnf updateinfo info` prints; it can be later than the issue date ([#28](https://github.com/andresBR8/patchconi/issues/28)). `repoquery --upgrades` lists `curl` four times, once per newer version; the report has one entry, with the version `dnf check-update` would install.
- **`rocky-10.2-host-parse-error.json`** keeps everything the host capture measured: two kernels with the newest not running, a reboot required, and the age of the oldest cached repository (9 days).
