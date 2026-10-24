#!/usr/bin/env bash
# Capture real apt and dnf output from the official container images listed
# in images.txt, for the protocol examples and the agent's parser tests.
#
# Usage: protocol/captures/capture-containers.sh [name...]
#
# Runs on the maintainer's machine, which needs Docker and internet access to
# the distribution mirrors. With no names, every image in images.txt is
# captured. Each capture goes to protocol/captures/containers/<name>/:
#   commands.tsv      one line per command: name, exit code, command
#   <name>.stdout     what the command printed (absent when it printed nothing)
#   <name>.stderr     its error output (absent when empty)
#   capture.txt       image, capture time and script
#
# What runs where:
#   - On this machine: `docker run` and file writes under containers/ only.
#   - Inside each throwaway container (as root, removed afterwards with --rm):
#     refresh the package metadata, list updates and installed packages,
#     and hold one package, so that held packages show up in the output.
# Nothing from this machine goes into the container: no environment, no
# volumes, no credentials. Read check-capture.sh before committing the output.

set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
images_file="$script_dir/images.txt"
out_root="$script_dir/containers"

# Runs inside the container, read from standard input by bash. Every command
# is wrapped by `section`, which prints its exit code, output and errors
# between markers that split_sections reads back.
collector() {
  cat <<'COLLECTOR'
set -u
export LC_ALL=C DEBIAN_FRONTEND=noninteractive

section() {
  local name=$1 out err rc
  shift
  out=$(mktemp)
  err=$(mktemp)
  rc=0
  "$@" >"$out" 2>"$err" || rc=$?
  printf '@@patchconi-capture begin %s exit=%d\n' "$name" "$rc"
  printf '@@cmd %s\n' "$*"
  printf '@@stdout\n'
  sed -e '$a\' "$out"
  printf '@@stderr\n'
  sed -e '$a\' "$err"
  printf '@@patchconi-capture end %s\n' "$name"
  rm -f "$out" "$err"
}

section os-release cat /etc/os-release
section uname-m uname -m
section uname-r uname -r
section date date -u +%Y-%m-%dT%H:%M:%SZ

if command -v apt-get >/dev/null; then
  section apt-version apt --version
  section apt-get-update apt-get update
  section apt-list-upgradable apt list --upgradable
  section apt-get-s-upgrade apt-get -s upgrade
  section apt-get-s-dist-upgrade apt-get -s dist-upgrade
  section apt-cache-policy apt-cache policy
  section apt-lists-mtime sh -c 'stat -c "%Y %s %n" /var/lib/apt/lists/* /var/cache/apt/*.bin'
  section apt-periodic-stamps sh -c 'stat -c "%Y %n" /var/lib/apt/periodic/*-stamp'
  section dpkg-inventory dpkg-query -W -f '${binary:Package}\t${Version}\t${Architecture}\n'
  section dpkg-kernels dpkg-query -W -f '${binary:Package}\t${Version}\t${db:Status-Abbrev}\n' 'linux-image-*'
  section reboot-required sh -c 'cat /var/run/reboot-required /var/run/reboot-required.pkgs'
  section pro-version sh -c 'command -v pro && pro version'
  held=$(apt list --upgradable 2>/dev/null | awk -F/ 'NR > 1 { print $1; exit }')
  if [ -n "$held" ]; then
    section apt-mark-hold apt-mark hold "$held"
    section apt-mark-showhold apt-mark showhold
    section apt-get-s-upgrade-held apt-get -s upgrade
    section apt-list-upgradable-held apt list --upgradable
  fi
elif command -v dnf >/dev/null; then
  section dnf-version dnf --version
  section dnf-makecache dnf makecache
  section dnf-check-update dnf -C check-update
  section dnf-updateinfo-list dnf -C updateinfo list --updates
  section dnf-updateinfo-list-security dnf -C updateinfo list --updates --security
  section dnf-updateinfo-info dnf -C updateinfo info --updates
  section dnf-repoquery-upgrades dnf -C -q repoquery --upgrades --qf '%{name}\t%{arch}\t%{epoch}:%{version}-%{release}\t%{repoid}\n'
  section dnf-repolist dnf -C repolist
  section dnf-repodata-mtime sh -c 'stat -c "%Y %s %n" /var/cache/dnf/*/repodata/*'
  section rpm-inventory rpm -qa --qf '%{NAME}\t%{ARCH}\t%{EPOCHNUM}:%{VERSION}-%{RELEASE}\n'
  section rpm-kernels rpm -q kernel kernel-core
  section dnf-needs-restarting dnf -C needs-restarting -r
  held=$(dnf -C -q check-update 2>/dev/null | awk 'NF == 3 && $1 ~ /\./ { sub(/\.[^.]+$/, "", $1); print $1; exit }')
  if [ -n "$held" ]; then
    section dnf-install-versionlock dnf -y install python3-dnf-plugin-versionlock
    section dnf-versionlock-add dnf -C versionlock add "$held"
    section dnf-versionlock-list dnf -C versionlock list
    section dnf-check-update-held dnf -C check-update
  fi
fi
COLLECTOR
}

# Reads the collector's output and writes one file per stream into $1.
# Section names come from inside the container, so they are checked before
# they become file names.
split_sections() {
  awk -v dir="$1" '
    /^@@patchconi-capture begin / {
      name = $3; code = $4; sub(/^exit=/, "", code); mode = ""
      if (name !~ /^[a-z0-9-]+$/) { print "bad section name: " name > "/dev/stderr"; exit 1 }
      next
    }
    /^@@cmd / { printf "%s\t%s\t%s\n", name, code, substr($0, 7) >> (dir "/commands.tsv"); next }
    /^@@stdout$/ { mode = "stdout"; next }
    /^@@stderr$/ { mode = "stderr"; next }
    /^@@patchconi-capture end / { close(dir "/" name ".stdout"); close(dir "/" name ".stderr"); mode = ""; next }
    mode != "" { print >> (dir "/" name "." mode) }
  '
}

# The capture in progress, removed if the script stops before moving it to
# its final place (docker fails, or a bad section name).
tmp=''
trap 'if [ -n "$tmp" ]; then rm -rf -- "$tmp"; fi' EXIT

capture() {
  local name=$1 image=$2 dest="$out_root/$1"
  if [ -e "$dest" ]; then
    echo "$dest already exists; remove it to capture $name again" >&2
    return 1
  fi
  tmp=$(mktemp -d "$out_root/.tmp-$name.XXXXXX")
  echo "== $name ($image)" >&2
  collector | docker run --rm -i --network bridge "$image" bash -s | split_sections "$tmp"
  {
    printf 'image=%s\n' "$image"
    printf 'captured_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'script=protocol/captures/capture-containers.sh\n'
  } >"$tmp/capture.txt"
  mv "$tmp" "$dest"
  tmp=''
}

main() {
  mkdir -p "$out_root"
  local found=0 name image
  while read -r name image; do
    case $name in '' | '#'*) continue ;; esac
    if [ $# -gt 0 ]; then
      case " $* " in *" $name "*) ;; *) continue ;; esac
    fi
    found=1
    capture "$name" "$image"
  done <"$images_file"
  if [ "$found" -eq 0 ]; then
    echo "no matching image in $images_file" >&2
    return 1
  fi
}

main "$@"
