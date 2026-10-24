# Captured package manager output

Real output of `apt` and `dnf`, kept for two uses: the protocol v1 examples are built from it, and the agent's parser tests (phase 5) read it as golden files ([ADR 0008](../../docs/adr/0008-openapi-contract-checked-in-ci.md)). Why containers and virtual machines: [vision](../../docs/product/vision.md#why-the-examples-come-from-containers).

| Path | What it holds | How it is made |
| --- | --- | --- |
| `images.txt` | One image per supported distribution, pinned by digest | By hand; digests checked against the registry |
| `containers/<name>/` | Full command output from a throwaway container | `capture-containers.sh` |
| `hosts/<name>.txt` | Counts, times and states from a real host | `capture-host.sh` |

Every capture is checked with `check-capture.sh` before it is committed.

## Output format

Both capture scripts print sections between markers:

```text
@@patchconi-capture begin <section> exit=<exit code>
@@cmd <command>
@@stdout
...
@@stderr
...
@@patchconi-capture end <section>
```

`capture-containers.sh` splits them into `<section>.stdout` and `<section>.stderr` files, plus `commands.tsv` (section, exit code, command). A host capture stays in one file, because it holds summaries, not output to parse. A final newline is added to a stream that lacks one.

## Containers

Needs Docker and internet access to the distribution mirrors. Each container runs as root, refreshes its package metadata, lists updates and installed packages, holds one package (so that held packages appear in the output) and is removed. Nothing from the machine that runs the script goes into the container.

```sh
protocol/captures/capture-containers.sh                 # every image
protocol/captures/capture-containers.sh rocky-10        # one image
protocol/captures/check-capture.sh protocol/captures/containers
```

The script refuses to overwrite an existing capture: remove `containers/<name>/` to capture it again.

## Hosts

What a container cannot show (kernels, a pending reboot, the last boot, the metadata timers, running without root) comes from virtual machines. `capture-host.sh` runs on the host as an unprivileged user without sudo and refuses to run as root. It arrives on standard input, reads no file from this repository and leaves nothing on the host. It prints counts and times only: no package lists, repository names, mirror URLs, host names or addresses.

Replace `<user>`, `<host>` and the output name:

```sh
ssh <user>@<host> 'LC_ALL=C bash -s' < protocol/captures/capture-host.sh > ~/patchconi-capture-ubuntu-24.04.txt
protocol/captures/check-capture.sh --deny-patterns ~/patchconi-deny.txt ~/patchconi-capture-ubuntu-24.04.txt
```

The deny patterns file lists, one per line, the strings that must never reach the repository: host names, domains, addresses, user names. It must live outside the repository; the script refuses one inside it. A match fails the check. Lines that look like IPv4, MAC or email addresses are listed for review but do not fail the check, because package versions can look like addresses.

Only after the check passes, and after reading the file, copy it to `protocol/captures/hosts/<distribution>-<version>.txt`.
