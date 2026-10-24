#!/usr/bin/env bash
# Capture what a container cannot show, from a real host: the running and
# installed kernels, a pending reboot, the last boot, how old the package
# metadata is, the timers that refresh it, and whether the package manager
# answers without root (the hypothesis of ADR 0007).
#
# Usage, from the maintainer's machine:
#   ssh <user>@<host> 'LC_ALL=C bash -s' < protocol/captures/capture-host.sh > capture.txt
#   protocol/captures/check-capture.sh --deny-patterns <file outside the repo> capture.txt
#
# The script arrives on standard input and reads no file from the repository.
# It must run as an unprivileged user without sudo, and refuses to run as root.
#
# What it reads and runs on the host, all read-only:
#   - /etc/os-release (identification fields only), uname, /proc/uptime,
#     whether /etc/machine-id is readable and the app-specific ID format;
#   - apt: apt list, apt-get -s, dpkg-query, apt-mark showhold, and three
#     fields of Ubuntu Pro's status cache;
#   - dnf: dnf -C (cache only, never downloads), rpm -q, needs-restarting;
#   - systemctl show for the metadata and automatic update timers;
#   - modification times of the package metadata files.
# What it prints: counts, times, versions and states, never package lists,
# repository names, mirror URLs, host names or addresses. Error output is
# printed with quoted strings, URLs and IPv4 addresses replaced.
#
# What it may leave behind: nothing. Temporary files live in a private
# directory removed on exit. dnf run as a normal user may create its own
# cache directory under /var/tmp; the script removes the ones it created.

set -u
export LC_ALL=C

# Fixed application ID for systemd's app-specific machine ID. The agent
# reports this hash instead of /etc/machine-id (docs/product/protocol.md).
app_id=1a05fda4-d773-446d-80c6-ca4266e023d4

if [ "$(id -u)" -eq 0 ]; then
  echo "capture-host.sh must not run as root" >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# Any tool that keeps a per-user cache or log under ~/.cache writes it here
# instead, and it is removed on exit (`pro status` does, without root; the
# script no longer runs it, see pro_esm).
export XDG_CACHE_HOME="$work/cache"

redact() {
  sed -E \
    -e "s/'[^']*'/'<redacted>'/g" \
    -e 's/"[^"]*"/"<redacted>"/g' \
    -e 's#[A-Za-z][A-Za-z0-9+.-]*://[^[:space:]]*#<url>#g' \
    -e 's/[0-9]{1,3}(\.[0-9]{1,3}){3}/<ipv4>/g' |
    head -n 20
}

# run CMD...: stdout to $work/out, stderr appended to $work/err, exit code
# to $work/rc. The section's summary is built from $work/out.
run() {
  local rc=0
  "$@" >"$work/out" 2>>"$work/err" || rc=$?
  echo "$rc" >"$work/rc"
}

# section NAME DESCRIPTION FUNCTION: same markers as capture-containers.sh.
section() {
  local name=$1 desc=$2
  shift 2
  : >"$work/err"
  echo 0 >"$work/rc"
  "$@" >"$work/summary"
  printf '@@patchconi-capture begin %s exit=%s\n' "$name" "$(cat "$work/rc")"
  printf '@@cmd %s\n' "$desc"
  printf '@@stdout\n'
  # sed's "$a\" adds a final newline only when it is missing; not a quote.
  # shellcheck disable=SC1003
  sed -e '$a\' "$work/summary"
  printf '@@stderr\n'
  redact <"$work/err"
  printf '@@patchconi-capture end %s\n' "$name"
}

count() { grep -c -E "$1" "$work/out" || true; }

# Oldest and newest modification time of the files given, without names.
mtimes() {
  local f n=0 oldest='' newest='' t
  for f in "$@"; do
    [ -e "$f" ] || continue
    t=$(stat -c %Y "$f") || continue
    n=$((n + 1))
    if [ -z "$oldest" ] || [ "$t" -lt "$oldest" ]; then oldest=$t; fi
    if [ -z "$newest" ] || [ "$t" -gt "$newest" ]; then newest=$t; fi
  done
  printf 'files=%s\noldest_mtime=%s\nnewest_mtime=%s\nnow=%s\n' "$n" "$oldest" "$newest" "$(date +%s)"
}

timers() {
  local unit
  for unit in "$@"; do
    run systemctl show --timestamp=utc \
      -p Id -p LoadState -p UnitFileState -p ActiveState -p TimersCalendar \
      -p RandomizedDelayUSec -p Persistent -p LastTriggerUSec "$unit"
    cat "$work/out"
  done
}

# --- Common -----------------------------------------------------------------

os_release() {
  grep -E '^(NAME|ID|ID_LIKE|VERSION_ID|VERSION_CODENAME|PRETTY_NAME)=' /etc/os-release
}

identity() {
  printf 'uid_is_root=no\nsupplementary_groups=%s\n' "$(($(id -G | wc -w) - 1))"
}

kernel_and_boot() {
  local up
  up=$(cut -d' ' -f1 /proc/uptime)
  printf 'kernel_running=%s\narch=%s\n' "$(uname -r)" "$(uname -m)"
  printf 'now_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'last_boot_utc=%s\n' "$(date -u -d "@$(($(date +%s) - ${up%.*}))" +%Y-%m-%dT%H:%M:%SZ)"
  printf 'virtualization=%s\n' "$(systemd-detect-virt 2>/dev/null || echo none)"
  if command -v getenforce >/dev/null; then printf 'selinux=%s\n' "$(getenforce)"; fi
}

machine_fingerprint() {
  if [ -r /etc/machine-id ]; then echo 'machine_id_readable=yes'; else echo 'machine_id_readable=no'; fi
  run systemd-id128 machine-id --app-specific="$app_id"
  if grep -q -E '^[0-9a-f]{32}$' "$work/out"; then
    echo 'app_specific_id_format=32-hex'
  else
    echo 'app_specific_id_format=other'
  fi
}

# --- apt --------------------------------------------------------------------

apt_version() { run apt --version; head -n 1 "$work/out"; }

apt_upgradable() {
  run apt list --upgradable
  printf 'packages=%s\nsecurity=%s\n' "$(count '\[upgradable from')" "$(count '^[^/]+/[^ ]*-security')"
}

apt_simulate() {
  run apt-get -s "$1"
  printf 'inst=%s\nconf=%s\n' "$(count '^Inst ')" "$(count '^Conf ')"
}

apt_lists_age() {
  mtimes /var/lib/apt/lists/*Release
  printf 'pkgcache_mtime=%s\n' "$(stat -c %Y /var/cache/apt/pkgcache.bin 2>/dev/null)"
}

apt_periodic() {
  local f
  for f in /var/lib/apt/periodic/*-stamp; do
    [ -e "$f" ] && printf '%s=%s\n' "$(basename "$f")" "$(stat -c %Y "$f")"
  done
  return 0
}

dpkg_kernels() {
  run dpkg-query -W -f '${binary:Package}\t${Version}\t${db:Status-Abbrev}\n' 'linux-image-[0-9]*'
  cat "$work/out"
}

apt_reboot() {
  if [ -e /var/run/reboot-required ]; then echo 'reboot_required=yes'; else echo 'reboot_required=no'; fi
  if [ -e /var/run/reboot-required.pkgs ]; then
    printf 'reboot_required_pkgs=%s\n' "$(wc -l </var/run/reboot-required.pkgs)"
  else
    echo 'reboot_required_pkgs=0'
  fi
}

apt_held() { run apt-mark showhold; printf 'held=%s\n' "$(count .)"; }

unattended() {
  run dpkg-query -W -f '${db:Status-Abbrev}\n' unattended-upgrades
  printf 'unattended_upgrades=%s\n' "$(cat "$work/out")"
}

# Only whether Ubuntu Pro is attached and the two ESM services' status. Read
# from the status cache that pro keeps world-readable, not from `pro status`:
# without root, that command contacts Canonical's servers when its cache is
# old (seen on Ubuntu 24.04). The cache also holds the account, the contract
# and a machine ID, which are never printed.
pro_esm() {
  local status=/var/lib/ubuntu-advantage/status.json f
  if [ -r "$status" ]; then
    printf 'status_json_mtime=%s\n' "$(stat -c %Y "$status")"
    python3 -I -c '
import json, sys
d = json.load(sys.stdin)
print("attached=%s" % d.get("attached"))
for s in d.get("services", []):
    if s.get("name") in ("esm-infra", "esm-apps"):
        print("%s=%s" % (s["name"], s.get("status")))
' <"$status" 2>>"$work/err" || echo 'parse=failed'
  else
    echo 'status_json=absent'
  fi
  for f in ubuntu-esm-infra ubuntu-esm-apps; do
    if compgen -G "/etc/apt/sources.list.d/$f.*" >/dev/null; then
      printf '%s_apt_source=present\n' "$f"
    else
      printf '%s_apt_source=absent\n' "$f"
    fi
  done
}

# --- dnf --------------------------------------------------------------------

dnf_version() { run dnf --version; head -n 1 "$work/out"; }

# dnf as a normal user may create /var/tmp/dnf-<user>-*; remove only the
# directories that did not exist before the command.
dnf_user_caches() { find /var/tmp -maxdepth 1 -name "dnf-$(id -un)-*" -user "$(id -u)" 2>/dev/null | sort; }

dnf_cached() {
  local before
  before=$(dnf_user_caches)
  run dnf -C "$@"
  comm -13 <(printf '%s\n' "$before") <(dnf_user_caches) | while read -r d; do
    [ -n "$d" ] && rm -rf "$d" && echo 'user_cache_created=yes'
  done
}

dnf_check_update() {
  dnf_cached "$@" check-update
  printf 'packages=%s\n' "$(count '^[^ ]+\.[^ .]+ +[^ ]+ +[^ ]+$')"
}

dnf_updateinfo() {
  dnf_cached "$@"
  printf 'advisories=%s\n' "$(count '^[A-Z]+-[0-9]{4}:')"
}

dnf_repodata_age() { mtimes /var/cache/dnf/*/repodata/repomd.xml; }

dnf_automatic_conf() {
  grep -E '^[[:space:]]*(upgrade_type|download_updates|apply_updates)[[:space:]]*=' /etc/dnf/automatic.conf 2>/dev/null || echo 'automatic_conf=absent'
}

rpm_kernels() { run rpm -q kernel-core --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n'; cat "$work/out"; }

dnf_needs_restarting() {
  dnf_cached needs-restarting -r
  printf 'reboot_required=%s\n' "$(if [ "$(cat "$work/rc")" = 1 ]; then echo yes; else echo no; fi)"
}

dnf_versionlock() { dnf_cached versionlock list; printf 'locks=%s\n' "$(count '^[^ ]+-[0-9]')"; }

# --- Main -------------------------------------------------------------------

printf '@@patchconi-capture host script=protocol/captures/capture-host.sh\n'
section os-release 'grep identification fields of /etc/os-release' os_release
section identity 'id -u; id -G (counts only)' identity
section kernel-and-boot 'uname -r; uname -m; /proc/uptime; systemd-detect-virt; getenforce' kernel_and_boot
section machine-fingerprint "systemd-id128 machine-id --app-specific=$app_id (format only)" machine_fingerprint

if command -v apt-get >/dev/null; then
  section apt-version 'apt --version' apt_version
  section apt-list-upgradable 'apt list --upgradable (counts only)' apt_upgradable
  section apt-get-s-upgrade 'apt-get -s upgrade (counts only)' apt_simulate upgrade
  section apt-get-s-dist-upgrade 'apt-get -s dist-upgrade (counts only)' apt_simulate dist-upgrade
  section apt-lists-age 'stat /var/lib/apt/lists/*Release, pkgcache.bin' apt_lists_age
  section apt-periodic-stamps 'stat /var/lib/apt/periodic/*-stamp' apt_periodic
  section apt-timers 'systemctl show apt-daily.timer apt-daily-upgrade.timer' timers apt-daily.timer apt-daily-upgrade.timer
  section dpkg-kernels "dpkg-query -W 'linux-image-[0-9]*'" dpkg_kernels
  section reboot-required '/var/run/reboot-required, .pkgs (count)' apt_reboot
  section apt-mark-showhold 'apt-mark showhold (count only)' apt_held
  section unattended-upgrades 'dpkg-query -W unattended-upgrades' unattended
  section pro-esm 'read /var/lib/ubuntu-advantage/status.json (attached, esm-infra, esm-apps); ESM apt sources' pro_esm
fi

if command -v dnf >/dev/null; then
  section dnf-version 'dnf --version' dnf_version
  section dnf-check-update 'dnf -C check-update (count only)' dnf_check_update
  section dnf-check-update-system-cache 'dnf -C --setopt=cachedir=/var/cache/dnf check-update (count only)' dnf_check_update --setopt=cachedir=/var/cache/dnf
  section dnf-updateinfo-list 'dnf -C updateinfo list --updates (count only)' dnf_updateinfo updateinfo list --updates
  section dnf-updateinfo-list-security 'dnf -C updateinfo list --updates --security (count only)' dnf_updateinfo updateinfo list --updates --security
  section dnf-repodata-age 'stat /var/cache/dnf/*/repodata/repomd.xml' dnf_repodata_age
  section dnf-timers 'systemctl show dnf-makecache.timer dnf-automatic*.timer' timers dnf-makecache.timer dnf-automatic.timer dnf-automatic-install.timer
  section dnf-automatic-conf 'grep upgrade_type, download_updates, apply_updates in /etc/dnf/automatic.conf' dnf_automatic_conf
  section rpm-kernels 'rpm -q kernel-core' rpm_kernels
  section dnf-needs-restarting 'dnf -C needs-restarting -r' dnf_needs_restarting
  section dnf-versionlock 'dnf -C versionlock list (count only)' dnf_versionlock
fi
