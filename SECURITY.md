# Security policy

## Reporting a vulnerability

Please **do not** open a public issue for a security problem.

Report it privately through GitHub's private vulnerability reporting:

1. Go to <https://github.com/andresBR8/patchconi/security/advisories/new>.
2. Describe the problem, how to reproduce it and its impact.

Only the maintainers can see the report. We can discuss it, prepare a fix and publish an advisory together, with credit to you if you want it.

## What to expect

PatchConi is maintained by one person in their spare time, so responses are best effort:

- Acknowledgement within 7 days.
- An assessment and, if the report is confirmed, a plan for the fix within 30 days.
- A public advisory once a fix is available.

## Supported versions

There is no release yet. Until v0.1.0, only the `main` branch is supported. After that, security fixes go to the latest release.

## Scope

In scope: anything in this repository, including the CI configuration, the toolchain and dependency pins, and, once they exist, the API, the web UI, the agent and the deployment artifacts.

PatchConi's design rules are part of its security model. Once the components exist, breaking any of them is a vulnerability:

- The agent is read-only: it never installs packages and never runs commands received from the server.
- Agent tokens are stored only as hashes and never logged.
- The host always starts the connection; the server never connects to the hosts.

Also in scope: a monitored host, or anyone holding a valid agent token, attacking the server or other hosts, for example with crafted reports (injection, cross-site scripting through package names, denial of service). A compromised host must not be able to affect anything beyond its own data.

Out of scope: vulnerabilities in third-party dependencies with no impact on PatchConi (please report those upstream), and problems that require root access to the PatchConi server or an administrator account.
