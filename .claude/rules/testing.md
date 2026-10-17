---
paths:
  - "apps/**"
  - "agent/**"
  - "packages/**"
---

# Testing rules

- New behavior comes with tests in the same commit. A bug fix starts with a failing test.
- Unit tests for pure logic. Integration tests run against a real PostgreSQL through Testcontainers, never against ORM mocks.
- Agent collectors are tested with golden files captured from real `apt` and `dnf` output. Never invent fixtures from memory.
- Tests are deterministic: no real clock, network or randomness unless it is injected.
- Never skip, disable or weaken a test to get CI green. Explain the failure instead.
