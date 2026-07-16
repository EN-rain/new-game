# Oozeborne C# Migration Decision Log

This file records product and technical decisions that control the GDScript-to-C# migration. Do not treat an unresolved entry as permission to choose an implementation ad hoc.

## Status Values

- Proposed
- Investigating
- Approved
- Rejected
- Superseded

## Decision Template

```markdown
## ADR-XXX — Title

- Status: Proposed
- Date: YYYY-MM-DD
- Owner: Unassigned
- Required before: M0/M1/etc.

### Context

What must be decided and why it matters.

### Options

1. Option A
2. Option B

### Decision

Pending.

### Consequences

- Positive:
- Negative:
- Follow-up:

### Reversal Conditions

What evidence would cause this decision to be revisited.
```

---

## ADR-001 — Desktop Game Client Scope

- Status: Approved
- Date: 2026-07-16
- Owner: Project owner
- Required before: M0 completion

### Context

Oozeborne's playable Godot client is entirely desktop-only. The repository also contains web technology, but that web technology serves the backend administration layer rather than a browser version of the game.

### Decision

- `game/` targets desktop only.
- Windows is the required baseline for development, CI, and release export validation.
- Linux and macOS are optional future desktop targets and are not migration blockers unless explicitly added.
- Android, iOS, and browser-game exports are out of scope.

### Required Evidence

- Windows Debug and Release C# builds
- Windows desktop export launch
- Backend connectivity
- Save/load
- Solo flow
- Multiplayer room, match, disconnect, and reconnect flow

---

## ADR-002 — Web Architecture Boundary

- Status: Approved
- Date: 2026-07-16
- Owner: Project owner
- Required before: M0 completion

### Context

The term "web" in this repository refers to backend-facing services and administration tooling, not a playable web game client.

### Decision

- `moon_server/admin-portal/` remains a Next.js web application for administration and live tuning.
- `moon_server/lobby-api/` remains the REST backend.
- `moon_server/game-server/` remains the authoritative real-time server.
- None of these are Godot client export targets.
- The GDScript-to-C# migration must not introduce a separate web-client strategy or mobile export work.

---

## ADR-003 — Godot .NET and SDK Pin

- Status: Approved
- Date: 2026-07-16
- Owner: Migration agent
- Required before: C# project generation

### Context

`game/project.godot` targets Godot 4.6 and already declares the `NewGame` assembly, but `game/NewGame.csproj` does not yet exist.

### Decision Inputs

- Exact Godot 4.6 .NET build
- Compatible .NET SDK feature band
- CI runner availability
- Export template availability

### Decision

- Pin Godot `4.6.2.stable.mono.official.71f334935`.
- Pin the x64 .NET SDK to `8.0.401` with roll-forward disabled in repository `global.json`.
- Use `Godot.NET.Sdk/4.6.2` and `net8.0` for the Windows desktop client.
- Upgrade Godot and .NET independently from production migration packages.

---

## ADR-004 — C# Project and Assembly Layout

- Status: Approved
- Date: 2026-07-16
- Owner: Migration agent
- Required before: M1

### Proposed Decision

- One Godot gameplay assembly initially: `NewGame`.
- Source under `game/src/`.
- Pure tests in a separate test project.
- No multi-assembly split until dependency boundaries and Godot loading behavior are proven.

### Decision

Approved as proposed. `game/NewGame.csproj` is the single Godot gameplay assembly, source lives under `game/src/`, and pure tests live in `game/tests-csharp/Unit/` without being compiled into the Godot assembly.

---

## ADR-005 — Unit and Integration Test Framework

- Status: Approved
- Date: 2026-07-16
- Owner: Migration agent
- Required before: M1

### Options

1. xUnit for pure tests plus a custom Godot scene test harness.
2. NUnit for pure tests plus a custom Godot scene test harness.
3. Another Godot-compatible C# test framework after compatibility review.

### Required Capabilities

- Headless CI execution
- Async tests
- Fixture/golden-file tests
- Clear test reports
- No requirement to load Godot for pure domain tests

### Decision

Use xUnit for pure .NET tests and explicit Godot-hosted `.tscn` scenes for engine, lifecycle, and mixed-language integration tests. The M0 workflow runs both from PowerShell and Windows CI.

---

## ADR-006 — JSON Serialization Policy

- Status: Approved
- Date: 2026-07-16
- Owner: Migration agent
- Required before: M1 DTO work

### Required Behavior

- Explicit wire/save property names
- Tolerate unknown additive fields where required
- Detect missing required fields
- Culture-invariant numbers
- Reject non-finite values
- Preserve current double-encoded or object `data` network envelopes
- Compatible with the Windows desktop game build and any later approved desktop targets

### Options

1. `System.Text.Json` with explicit converters.
2. Godot JSON only at the adapter boundary.
3. Another package only after dependency review.

### Decision

Use `System.Text.Json` for typed C# network/save models with explicit property names and converters. Keep Godot JSON only in narrow GDScript/resource adapters during transition. Strict parsing rejects non-standard non-finite JSON values; unknown-field and current envelope compatibility remain explicit fixture-tested policies.

---

## ADR-007 — HTTP Transport

- Status: Proposed
- Date: 2026-07-16
- Owner: Unassigned
- Required before: M3

### Options

1. Preserve `HTTPRequest` semantics through a C# node adapter first.
2. Use `HttpClient` with a shared handler/client and explicit lifecycle.

### Required Evaluation

- Godot Windows desktop export behavior
- Cancellation and timeout handling
- TLS behavior
- Connection reuse
- Scene-tree dependency
- Testability
- Error normalization

### Decision

Pending. Behavioral parity takes priority over transport replacement.

---

## ADR-008 — WebSocket Transport and Threading

- Status: Proposed
- Date: 2026-07-16
- Owner: Unassigned
- Required before: M4

### Proposed Decision

Use Godot `WebSocketPeer` initially to preserve polling, export compatibility, queue behavior, and main-thread integration. Reconsider only after parity and profiling.

### Required Guarantees

- 20 Hz input send loop
- Existing envelope compatibility
- Outbox cap/backpressure behavior
- Main-thread scene mutations
- Reconnect behavior
- Token redaction

### Decision

Pending.

---

## ADR-009 — Resource Migration Strategy

- Status: Approved
- Date: 2026-07-16
- Owner: Migration agent
- Required before: M2

### Proposed Decision

1. Keep existing GDScript `Resource` scripts and `.tres` files initially.
2. Map them into typed C# runtime models.
3. Convert actual resource scripts only in M9 after runtime consumers are stable.

### Consequences

- Temporary mixed-language adapter layer
- Lower risk of mass `.tres` data loss
- Resource conversion remains a separate critical work package

### Decision

Approved as proposed. M0 proved that C# can read an existing GDScript `SkillDefinition` resource without changing its `.tres` or script path.

---

## ADR-010 — Allowed Remaining GDScript

- Status: Approved
- Date: 2026-07-16
- Owner: Migration agent
- Required before: M1

### Proposed Allowed Exceptions

- LimboAI task adapters until C# compatibility is proven
- Existing editor/tool scripts during early phases
- Thin temporary compatibility facades
- Third-party plugin code

### Required Rule

Every retained project-owned GDScript file must have a documented reason, owner, and review date. "Not migrated yet" is not a permanent exception.

### Decision

Approved with the listed exceptions. M0 also proved that a project-owned GDScript LimboAI task can call a stable C# enemy-facing method, so LimboAI adapters may remain only where each retained file has a documented reason and removal/review condition.

---

## ADR-011 — Save Backup and Recovery

- Status: Proposed
- Date: 2026-07-16
- Owner: Unassigned
- Required before: M3

### Proposed Decision

- Read version 1 formats indefinitely unless a deprecation decision is made.
- Back up before the first C# write.
- Use temporary-file validation and atomic replacement where supported.
- Keep a last-known-good backup.
- Rename legacy saves to a migration backup after verified conversion rather than deleting immediately.
- Make all migrations idempotent.

### Decision

Pending.

---

## ADR-012 — Performance Regression Gates

- Status: Proposed
- Date: 2026-07-16
- Owner: Unassigned
- Required before: M1 activation

### Proposed Initial Gates

- Median hot-path time regression: no more than 5%.
- p95 hot-path time regression: no more than 10%.
- Snapshot/interpolation/mob cost regression: no more than 10%.
- No new sustained allocations in frame/physics loops.
- No unbounded queue, task, node, or subscription growth.

### Decision

Pending after baseline measurements.

---

## ADR-013 — NuGet Dependency Approval

- Status: Approved
- Date: 2026-07-16
- Owner: Migration agent
- Required before: first external package

### Proposed Decision

No package without documented need, license, platform/export support, maintenance status, native/AOT implications, security update plan, and alternatives. Commit package locks for approved dependencies.

### Decision

Approved. M0 adds only test-scoped xUnit, Visual Studio runner, and Microsoft Test SDK packages. Their exact transitive dependency graph is committed in a lock file. Runtime code has no external package beyond the exactly pinned Godot.NET.Sdk; its editor/export restore graph is conditional and is not forced into the test package lock.

---

## ADR-014 — Logging, Telemetry, and Crash Reporting

- Status: Proposed
- Date: 2026-07-16
- Owner: Unassigned
- Required before: M3/M4

### Required Behavior

- Structured subsystem categories
- Unhandled exception reporting
- Unobserved task failure reporting
- No JWT/password/authenticated URL logging
- Synthetic/sanitized fixtures only
- Release-safe verbosity

### Decision

Pending. Select local logs only or an approved remote crash/telemetry provider.

---

## ADR-015 — Migration Activation and Rollback

- Status: Approved
- Date: 2026-07-16
- Owner: Migration agent
- Required before: first production replacement

### Proposed Decision

- Low-risk components: scene reassignment with old script retained until parity.
- High-risk networking/save/autoload paths: debug comparison followed by an explicit activation switch.
- Never delete old high-risk code in the first activation commit.
- Every work package documents a tested rollback.

### Decision

Approved as proposed. M0 uses an explicit test scene only and does not change production scenes or autoloads. Production replacement begins in M1 only after the remaining M0 export/baseline gates close.
