# Oozeborne C# Migration Agent Instructions

Use this file when an AI coding agent is assigned to execute the Oozeborne GDScript-to-C# migration.

## Mission

Migrate the desktop Godot client under `game/` from GDScript to C# incrementally, while preserving current gameplay, scenes, resources, saves, multiplayer compatibility, and Windows desktop export behavior.

This is not a rewrite.

The following remain in their current languages unless a separate task explicitly changes them:

- `moon_server/game-server/` — Go authoritative game server
- `moon_server/lobby-api/` — Node.js/Express backend API
- `moon_server/admin-portal/` — Next.js web admin portal
- PostgreSQL migrations and Redis integration

The web code is backend/admin infrastructure. There is no browser game client. Android and iOS are out of scope.

## Mandatory Reading Order

Before making migration changes, read:

1. `AGENTS.md`
2. `docs/csharp-migration-plan.md`
3. `docs/csharp-decisions.md`
4. `docs/csharp-contract-manifest.md`
5. `docs/csharp-migration-status.md`
6. The architecture document for the subsystem being changed
7. Every relevant source file, scene, resource, caller, signal subscriber, and autoload dependency

Do not begin coding from this file alone.

## Core Rules

1. Work on one migration package or one tightly related subsystem at a time.
2. Preserve behavior before refactoring architecture.
3. Do not perform a line-for-line blind translation.
4. Do not combine migration, feature development, balance changes, and redesign in the same change.
5. Do not delete the old GDScript implementation when first activating a high-risk C# replacement.
6. Do not migrate unrelated backend or admin code merely for language consistency.
7. Do not modify third-party LimboAI source.
8. Do not manually edit `.import` or `.uid` files.
9. Do not move authoritative multiplayer decisions into the client.
10. Never log JWTs, passwords, authorization headers, complete authenticated WebSocket URLs, or sensitive save data.

## Required Scope Check

Before every work package, state:

- Migration package ID
- Target GDScript files
- Proposed C# replacements
- Scenes and resources affected
- Autoloads involved
- Save or network contracts involved
- Tests required
- Activation method
- Rollback method

Do not proceed when the scope is unclear or includes unrelated systems.

## Phase Gate Rules

Follow the package order in `docs/csharp-migration-plan.md`.

### M0 — Migration foundation

Complete before production script migration:

- Generate the real Godot .NET project using the Godot 4.6 .NET editor.
- Create and review `game/NewGame.csproj`.
- Pin the compatible .NET SDK in `global.json`.
- Add `.editorconfig` and warning/nullability rules.
- Establish unit and Godot integration test workflows.
- Capture sanitized save, network, resource, and settings fixtures.
- Capture Windows Debug and Release baselines.
- Prove a minimal Windows desktop C# export launches.
- Prove GDScript can call C# and C# can call GDScript.
- Prove a GDScript LimboAI task can safely call a C# enemy-facing method.
- Update all relevant decision records from `Proposed` to an approved or rejected state.

Do not begin broad conversion if M0 is incomplete.

### M1 — Pilot components and contracts

Initial production targets:

- Typed network and save contracts without activation
- `health_component.gd`
- `mana_component.gd`
- `hit_box.gd`
- Narrow interop utilities

The pilot must prove:

- C# compilation
- Scene attachment
- Exported property retention
- Signal compatibility
- GDScript consumers calling C# nodes
- C# code reading existing GDScript resources
- Windows export behavior
- Rollback to GDScript

Do not migrate major managers before this pilot passes.

### Later packages

Proceed only when all dependencies and exit criteria in the migration plan are satisfied.

Never skip directly to:

- `player.gd`
- `main.gd`
- `multiplayer_manager.gd`
- `multiplayer_utils.gd`
- `skill_tree_ui.gd`
- actual `.tres` resource script replacement

## Per-Script Workflow

For every target script:

### 1. Characterize the existing implementation

Inspect and record:

- Base class
- `class_name`
- Tool/editor execution
- Exported fields, defaults, ranges, enums, and resource types
- Signals and argument order
- Public methods and callers
- Node paths
- Groups
- Autoload dependencies
- Loaded/preloaded resources
- Save keys
- Network fields
- Deferred calls
- Awaited signals/tasks
- Pause behavior
- Scene lifecycle behavior
- Solo behavior
- Multiplayer behavior

Add the information to `docs/csharp-contract-manifest.md` before replacing the script.

### 2. Add characterization tests

Create tests that prove current behavior before conversion.

Tests must cover the behavior that could be lost, not merely whether the scene loads.

Examples:

- Exact health and mana signal delivery
- Damage, healing, death, and clamp behavior
- Skill cost and prerequisite rules
- Save round trips
- Network payload serialization
- Reconnect and interpolation behavior
- Duplicate signal subscription prevention
- Pause and scene exit behavior

### 3. Implement the C# replacement

Requirements:

- Use a stable `Oozeborne` namespace.
- Use `partial` Godot classes where required.
- Enable nullable-safe code.
- Use `[Export]` and `[Signal]` correctly.
- Keep Godot-facing names compatible during transition.
- Keep `Variant`, Godot dictionaries, and dynamic string calls at narrow boundaries.
- Convert external data into typed C# models immediately.
- Avoid per-frame LINQ and avoid allocations in hot loops.
- Do not access scene-tree APIs from background threads.
- Cancel or ignore asynchronous work after node disposal or scene exit.

### 4. Activate safely

For low-risk components, update only the required scene scripts.

For high-risk systems:

- Keep the old implementation available.
- Use a feature flag, alternate scene, facade, or autoload path switch.
- Do not run two authoritative implementations simultaneously.
- When dual-run comparison is used, the secondary path must be read-only and debug-only.

### 5. Verify

Run the smallest complete verification set:

- `dotnet build` Debug
- `dotnet build` Release
- Relevant unit tests
- Relevant Godot scene/integration tests
- Missing script/resource scan
- Solo test when gameplay is affected
- Multiplayer test when networking or shared gameplay is affected
- Save fixtures when persistence is affected
- Network fixtures when protocol parsing/serialization is affected
- Windows export when scene/resource/runtime attachment changes
- Performance comparison for hot-path systems

### 6. Update documentation

Update:

- `docs/csharp-migration-status.md`
- `docs/csharp-contract-manifest.md`
- Relevant decision records
- Relevant architecture documentation
- `AGENTS.md` only when project-wide guidance changes

### 7. Remove old code only after parity

The GDScript file may be removed only when:

- All consumers use the C# replacement.
- All required tests pass.
- Scenes and resources reopen cleanly.
- Windows export launches.
- Rollback has been tested or remains trivial.
- No string-based calls reference the old implementation.
- No `.tscn` or `.tres` references the old script.
- No new errors, leaked subscriptions, orphan nodes, or unobserved tasks appear.

## Scene and Resource Rules

When replacing a script attached to a `.tscn` or `.tres`:

1. Build C# first so Godot can discover the class.
2. Back up or commit the original scene/resource state.
3. Replace one script family at a time.
4. Reopen every affected scene/resource in Godot.
5. Verify every exported value survived.
6. Inspect file diffs for lost properties or changed resource references.
7. Run dependency scans for missing scripts/resources.
8. Keep resource UIDs and paths stable whenever possible.

Never mass-replace `.tres` script references without an automated validation pass.

## Resource Migration Policy

During early migration:

- Keep existing GDScript `Resource` scripts and `.tres` files.
- Read them through narrow C# mappers.
- Use typed C# runtime models internally.

Actual C# resource conversion occurs late, after all runtime consumers are stable.

Before converting a resource family:

- Capture all `.tres` files using it.
- Capture exported values and inheritance.
- Create validation tooling.
- Convert one family only.
- Verify registry output before and after.
- Confirm no values, icons, scenes, enums, arrays, or dictionaries were lost.

## Autoload Migration Rules

Autoload names and initialization behavior are public contracts.

For each autoload:

1. Inventory all direct references.
2. Document dependencies on other autoloads.
3. Separate domain/service logic from the Godot singleton facade.
4. Keep the existing singleton name during migration.
5. Keep initialization idempotent.
6. Avoid assuming another singleton completed `_Ready()` unless guaranteed.
7. Preserve signals and public compatibility methods.
8. Add an explicit rollback path to the old autoload.

Do not translate a large GDScript manager into one equally large C# singleton.

## Networking Rules

The Go game server remains authoritative.

The C# client must preserve:

- Existing op codes
- Existing JSON field names
- Current envelope formats
- 20 Hz input send behavior
- Input sequence handling
- Pending input replay
- Local reconciliation
- Remote interpolation
- Backpressure and queue caps
- Reconnect grace behavior
- Host/non-host behavior

Network migration requires:

- Captured sanitized payload fixtures
- Typed DTOs
- Explicit wire names
- Unknown-field tolerance where appropriate
- Missing-required-field handling
- NaN/infinity rejection
- Collection and packet size limits
- Main-thread scene mutations
- Debug-only old/new parser comparison
- Two-client authentication, room, match, disconnect, and reconnect tests

Do not alter the Go protocol unless the task explicitly includes coordinated server and client changes.

## Save Migration Rules

Preserve these existing formats:

- Auth session file
- Solo save slots
- Slot names
- Cloud save payloads
- Legacy single-run save migration
- Settings configuration
- Coin/economy persistence
- Skill-tree state

Before the first C# write:

- Capture version 1 fixtures.
- Create a backup.
- Write to a temporary file.
- Validate the temporary file.
- Replace the original atomically where possible.
- Keep a last-known-good backup.
- Make migrations idempotent.
- Never delete a legacy save until the migrated copy has loaded successfully.

## LimboAI Rules

- Do not edit third-party LimboAI internals.
- Preserve behavior-tree assets and blackboard keys.
- Keep project-owned GDScript task adapters where C# support is uncertain.
- Expose a stable C# enemy API for GDScript tasks.
- Test task-to-C# calls before converting enemy runtime.
- Convert one enemy family at a time.
- Preserve admin tuning, targeting, attack ranges, animation names, death, XP, and network synchronization.

A retained GDScript LimboAI adapter is acceptable when documented. A large project-owned gameplay system remaining in GDScript without justification is not.

## UI Rules

Migrate UI after underlying services are stable.

For large UI controllers:

- Separate view logic from domain logic.
- Preserve node paths and signal connections.
- Preserve mouse and keyboard/controller navigation.
- Preserve pause behavior.
- Preserve host-only controls.
- Preserve loading and scene transition behavior.

Do not migrate UI merely to increase the C# percentage while core services remain unstable.

## Performance Rules

For hot-path migration:

- Compare against recorded baselines.
- No unexplained sustained managed allocations in `_Process()` or `_PhysicsProcess()`.
- No unbounded queues, tasks, subscriptions, snapshot buffers, or node counts.
- Investigate regressions above the approved thresholds in the migration plan.
- Measure Release exports, not only editor builds.

Do not claim C# is faster without measurements.

## Failure and Rollback Rules

Stop the current work package when:

- Existing scene/resource values are lost.
- Old saves cannot load.
- Network payload parity fails.
- LimboAI integration is unstable.
- Windows export fails.
- New runtime-only errors repeatedly appear.
- Performance exceeds approved regression limits.
- The new implementation creates a second source of truth.

Rollback options:

- Reassign the old GDScript scene script.
- Switch the autoload path back.
- Disable the C# feature flag.
- Restore the previous save fixture or backup.
- Revert the focused migration commit.

Do not patch around a failed foundation and continue into dependent packages.

## Prohibited Agent Behavior

The migration agent must not:

- Rewrite the entire client in one pass.
- Delete all GDScript immediately.
- Convert files without reading their callers and scene/resource consumers.
- Claim success because code compiles.
- Modify backend protocol accidentally.
- Change game balance during migration.
- Add unnecessary frameworks or packages.
- Generate fake test success.
- Ignore warnings, parse errors, missing resources, or failed exports.
- Hide incomplete verification.
- mark a script as migrated while its old implementation remains the active source of truth.

## Required Agent Report After Each Work Package

Report exactly:

### Scope completed

- Package ID
- GDScript files targeted
- C# files added or changed
- Scenes/resources changed

### Contracts preserved

- Exported properties
- Signals
- Public methods
- Save/network fields
- Autoload names

### Verification performed

- Build commands and results
- Tests and results
- Solo verification
- Multiplayer verification
- Windows export verification
- Performance comparison

### Activation and rollback

- How the C# path is activated
- How to switch back
- Whether the old GDScript remains

### Remaining risks

- Unverified behavior
- Deferred consumers
- Known compatibility bridges
- Required follow-up

Never state that a package is complete when required verification was not performed.

## First Assignment for a Fresh Agent

A fresh migration agent should not start converting gameplay immediately.

Its first assignment is M0:

1. Confirm the repository state and read all migration documents.
2. Confirm the Windows-only desktop client boundary.
3. Inspect `game/project.godot` and the installed Godot/.NET environment.
4. Generate the real Godot C# project.
5. Pin toolchain versions.
6. Add a minimal C# node and mixed-language test scene.
7. Prove C# signal/export interop.
8. Prove existing GDScript resources can be read from C#.
9. Prove a GDScript LimboAI task can call a C# method.
10. Build and launch a Windows desktop export.
11. Record results and update the decision log.

Only after this succeeds should the agent begin the M1 component pilot.
