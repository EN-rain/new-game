# Oozeborne GDScript-to-C# Migration Plan

## 1. Purpose

Oozeborne's Godot client has grown beyond what should remain concentrated in large, dynamically typed GDScript systems. The goal is to migrate the client gameplay code to C# without rewriting the game, breaking existing scenes, or changing the authoritative backend architecture.

This plan covers only the **desktop Godot game client** under `game/`. The Go game server, Node.js lobby API, Next.js web admin portal, PostgreSQL schema, Redis usage, and network protocol remain in their current languages unless a separate migration is approved. The web-facing code in this repository is backend/admin infrastructure; it is not a browser build of the game.

The migration must preserve:

- Solo gameplay
- Multiplayer gameplay
- Server-authoritative simulation
- Existing `.tscn` scenes
- Existing `.tres` skill resources
- Existing save formats where practical
- Existing backend JSON and WebSocket payloads
- Existing player and enemy behavior
- Existing LimboAI behavior trees during the transition

This is an incremental mixed-language migration. GDScript and C# will coexist until each subsystem is verified and its GDScript implementation can be removed.

---

## 2. Current Baseline

The Godot project currently contains approximately:

- 145 handwritten `.gd` files
- 22,000 lines of GDScript
- 17 autoload/global managers
- 36 UI controllers
- 33 entity scripts
- 27 resource/class scripts
- 18 status-effect scripts
- 8 gameplay-system scripts

The largest and most coupled files include:

- `game/scripts/ui/gameplay/skill_tree_ui.gd`
- `game/scripts/systems/game/main.gd`
- `game/scripts/globals/multiplayer_utils.gd`
- `game/scripts/entities/player/player.gd`
- `game/scripts/globals/skill_tree_manager.gd`
- `game/scripts/entities/enemies/mob_behavior_tree/main/bt_enemy.gd`
- `game/scripts/globals/class_manager.gd`
- `game/scripts/globals/multiplayer_manager.gd`

The project already contains a `[dotnet]` section in `game/project.godot`, but no `game/NewGame.csproj` currently exists. The first implementation step is therefore enabling the .NET Godot project correctly rather than immediately converting scripts.

---

## 3. Target State

The final target is a C#-first Godot client with this responsibility split:

### C# owns

- Core gameplay state
- Player movement and combat
- Stats and progression
- Health, mana, damage, cooldowns, and status effects
- Networking client infrastructure
- Network DTO parsing and serialization
- Client prediction, reconciliation, and interpolation
- Match orchestration
- Mob spawning and runtime enemy state
- Save models and save services
- Class and skill runtime logic
- Economy and shop runtime logic
- Testable non-visual domain logic

### GDScript may temporarily remain for

- LimboAI task scripts that are difficult to replace immediately
- Small scene-specific animation adapters
- One-off editor tooling
- Thin UI bridge scripts during staged conversion
- Third-party plugin integration where C# support is poor or undocumented

### Final preferred state

- No large gameplay manager remains in GDScript.
- No authoritative client-side domain rules depend on dynamic dictionaries when a typed C# model can be used.
- Scene scripts are small and delegate to typed services/components.
- Network messages use typed DTOs at the client boundary.
- Core logic can be unit tested without loading full scenes.
- GDScript is treated as an adapter language, not the main architecture language.

---

## 4. Non-Goals

This migration will not:

- Replace Godot with Unity or another engine
- Rewrite the Go authoritative server in C#
- Move authoritative multiplayer logic into the client
- Convert all scenes into code-created node trees
- Replace `.tres` resources with a database by default
- Redesign every gameplay system while converting it
- Perform broad balance changes during migration
- Change network op codes unless required for an independently approved protocol update
- Convert third-party LimboAI source code
- Rename all files, nodes, skills, classes, or payload keys at once

Migration and redesign must be separate concerns. A converted subsystem should first match existing behavior before it is improved.

---

## 5. Deployment Scope Gate

The product architecture is already decided:

- `game/` is a **desktop-only Godot game client**.
- There is no browser, Android, or iOS game client in scope.
- `moon_server/game-server/` and `moon_server/lobby-api/` are network backend services.
- `moon_server/admin-portal/` is the web-based administration and live-tuning interface.

The C# migration therefore needs to validate desktop game exports only. Windows is the current required development and release baseline. Linux or macOS may be added later as desktop targets, but they are not blockers unless explicitly added to product scope.

| Component | Runtime target | Migration impact |
|---|---|---|
| Godot game client | Desktop; Windows baseline | Migrate GDScript client code to C# and verify desktop exports |
| Go game server | Server/container | Preserve protocol compatibility; no language migration |
| Node lobby API | Server/container | Preserve REST compatibility; no language migration |
| Next.js admin portal | Web browser | Remains TypeScript/React; not a Godot export target |
| PostgreSQL/Redis | Backend infrastructure | Preserve schemas, keys, and data contracts |

Do not add mobile or browser-game requirements to this migration plan. Web testing applies only to the admin portal and backend APIs when their contracts are affected.

---

## 6. Migration Principles

### 6.1 One subsystem at a time

Never convert unrelated areas in one branch. Each migration unit must compile, load, and pass behavioral checks independently.

### 6.2 Preserve scene contracts

Existing scenes rely on:

- Node names
- Node paths
- Exported properties
- Signals
- Groups
- Callable methods
- Autoload names

A C# replacement must preserve these contracts until all consumers are migrated.

### 6.3 Preserve data contracts

Do not casually change:

- Skill IDs
- Class IDs
- JSON keys
- Save keys
- Network op codes
- Network payload fields
- Database tuning keys
- Resource paths

### 6.4 Replace dynamic boundaries first

Dictionary-based input is acceptable at an external boundary, but it must be converted immediately into a typed model. Internal C# code should not pass arbitrary `Godot.Collections.Dictionary` objects through the whole architecture.

### 6.5 Keep the server authoritative

C# improves client structure and performance; it does not grant the client authority. Damage, currency, identity, cooldown, movement validity, room permissions, and admin access remain validated server-side.

### 6.6 Behavior parity before optimization

Each replacement must first reproduce existing behavior. Optimize only after parity tests pass.

### 6.7 Avoid a permanent dual implementation

A compatibility bridge is temporary. Every migrated subsystem needs a dated removal condition for its old GDScript implementation.

---

## 7. Proposed C# Project Structure

Create the C# source tree under `game/src/` rather than mixing hundreds of `.cs` files directly beside existing GDScript files.

```text
game/
├── NewGame.csproj
├── src/
│   ├── Core/
│   │   ├── Contracts/
│   │   ├── Events/
│   │   ├── Extensions/
│   │   ├── Logging/
│   │   └── Utilities/
│   ├── Data/
│   │   ├── Classes/
│   │   ├── Skills/
│   │   ├── Shop/
│   │   ├── Saves/
│   │   └── Network/
│   ├── Components/
│   │   ├── Health/
│   │   ├── Mana/
│   │   └── StatusEffects/
│   ├── Entities/
│   │   ├── Player/
│   │   ├── Enemies/
│   │   ├── Projectiles/
│   │   └── Items/
│   ├── Systems/
│   │   ├── Match/
│   │   ├── Combat/
│   │   ├── Progression/
│   │   ├── Spawning/
│   │   └── Saving/
│   ├── Networking/
│   │   ├── Transport/
│   │   ├── Messages/
│   │   ├── Prediction/
│   │   └── Interpolation/
│   ├── Services/
│   │   ├── Classes/
│   │   ├── Skills/
│   │   ├── Economy/
│   │   └── StatusEffects/
│   ├── UI/
│   │   ├── Auth/
│   │   ├── Lobby/
│   │   ├── Gameplay/
│   │   └── Settings/
│   └── Interop/
│       ├── GdScriptBridge.cs
│       └── VariantConversion.cs
└── tests-csharp/
    ├── Unit/
    └── Integration/
```

Do not create excessive abstractions just to imitate enterprise backend architecture. Godot nodes and resources remain valid architectural building blocks.

---

## 8. C# Standards

Use consistent standards from the first converted file:

- Enable nullable reference types.
- Use file-scoped namespaces.
- Use explicit Godot base classes such as `Node`, `Node2D`, `CharacterBody2D`, `Control`, and `Resource`.
- Use `[GlobalClass]` only for resources or nodes that genuinely need editor-wide registration.
- Use `[Export]` for editor-configured properties.
- Use `[Signal]` delegates for Godot-facing signals.
- Use C# events only for internal non-Godot domain communication.
- Prefer `StringName` for repeated node, group, signal, animation, and input names.
- Cache node references in `_Ready()`; do not repeatedly call `GetNode()` in hot paths.
- Avoid per-frame LINQ and avoid allocations in `_Process()` and `_PhysicsProcess()`.
- Avoid reflection-driven architecture in gameplay hot paths.
- Use `partial` classes where required by Godot source generation.
- Use `sealed` for classes not intended for inheritance.
- Use records for immutable network/save DTOs when compatible with serialization needs.
- Keep Godot `Variant` usage at the boundary.
- Use `Godot.Collections.Array` and `Dictionary` only where engine interop requires them.
- Prefer standard .NET collections internally.
- Use `CancellationToken` for HTTP and long-running async operations where practical.
- Never call scene-tree APIs from background threads.
- Keep `_Process()` and `_PhysicsProcess()` lightweight.
- Pin the Godot .NET version and compatible .NET SDK; do not allow developer machines and CI to float independently.
- Add a repository `global.json` after the supported SDK is confirmed.
- Add `.editorconfig` rules for nullable analysis, naming, formatting, and warning severity.
- Treat compiler and Godot source-generator warnings as migration defects unless explicitly waived.
- Keep one Godot gameplay assembly initially; do not split into many assemblies until dependency boundaries are proven.
- Keep pure unit tests in a separate test project that references only logic which can run without the Godot scene tree.
- Use explicit JSON property names for every network and save DTO.
- Use culture-invariant numeric parsing and formatting at persistence and network boundaries.
- Do not add NuGet packages without documenting platform support, license, maintenance risk, export impact, and why the framework/BCL is insufficient.
- Commit package lock data when external packages are approved.
- Unsubscribe events and signals in `_ExitTree()` when the publisher can outlive the subscriber.
- Cancel and dispose per-node `CancellationTokenSource` instances during `_ExitTree()`.
- Avoid `async void` except unavoidable event handlers; route errors to a central logger.
- Never log JWTs, authorization headers, complete authenticated WebSocket URLs, passwords, or save secrets.

---

## 9. Interoperability Strategy

GDScript and C# can coexist, but cross-language calls are fragile when signatures drift. Use explicit bridge rules.

### 9.1 GDScript calling C#

During migration, expose only stable Godot-facing methods and signals. Keep names compatible with existing callers where possible.

Temporary compatibility methods may use snake_case names if an existing GDScript caller relies on them. New internal C# methods should use PascalCase.

### 9.2 C# calling GDScript

Prefer typed C# references after conversion. Before conversion, use `Call`, `Get`, `Set`, and signal connections only inside the `Interop` layer or a narrow adapter.

Do not scatter string-based GDScript calls throughout C# gameplay code.

### 9.3 Autoload compatibility

Autoload names must remain unchanged during conversion. For example, `MultiplayerManager` should still be reachable under the same singleton name even after its script becomes C#.

### 9.4 Resource compatibility

Existing `.tres` files reference GDScript resource scripts. Resource migrations require special care because changing the script path can invalidate loaded resources.

Use one of these strategies per resource type:

1. Keep the GDScript resource class and add a C# runtime mapper temporarily.
2. Create a C# resource with matching exported fields and migrate `.tres` references in a controlled batch.
3. Move stable data to JSON only when there is a separate reason; do not use JSON merely to avoid resource migration.

For Oozeborne, use strategy 1 first for skills and classes, then strategy 2 after runtime systems are stable.

---

## 10. Testing Foundation Before Conversion

The migration must not rely only on manual playtesting.

Before replacing production scripts, add characterization tests for current behavior.

### Required test categories

#### Pure logic tests

- XP thresholds and multi-level-up behavior
- Stat scaling and caps
- Skill cost and prerequisite rules
- Skill value resolution
- Shop purchase validation
- Save serialization/deserialization
- Status-effect refresh and expiry
- Cooldown calculations
- Damage and critical-hit calculations

#### Scene integration tests

- Player scene loads
- Player moves and dashes
- Player attacks and damages a mob
- Mob detects and attacks a player
- Death overlay appears
- Round transitions work
- Shop and skill tree open and close
- Class selection produces the correct player scene

#### Multiplayer contract tests

- Every client op-code payload serializes correctly
- Every server op-code payload parses correctly
- Unknown fields are tolerated where backward compatibility requires it
- Missing required fields fail safely
- Local prediction input sequence handling remains correct
- Snapshot reconciliation remains correct
- Remote interpolation handles delayed and out-of-order states

#### Save compatibility fixtures

Store representative fixtures for:

- Existing auth session
- Existing solo run save
- Existing cloud save payload
- Existing skill-tree state
- Existing shop/economy state

Old save fixtures must load after the corresponding C# migration.

---

## 11. Detailed Migration Phases

## Phase 0 — Preparation and Freeze

### Tasks

1. Create a migration branch.
2. Tag or record the last known-good GDScript build.
3. Confirm Godot .NET editor version and required .NET SDK.
4. Generate `game/NewGame.csproj` using the Godot .NET editor.
5. Add a minimal C# node to prove compilation and scene loading.
6. Document build commands for Windows and CI.
7. Validate a minimal Windows desktop export; add Linux/macOS export checks only if those desktop targets are later approved.
8. Establish naming and folder standards.
9. Add `docs/csharp-migration-status.md` to track each file.
10. Freeze broad feature work in migration-targeted systems while they are being converted.

### Exit criteria

- The existing game opens in the .NET editor.
- A C# script compiles and runs.
- Existing GDScript still runs unchanged.
- At least one desktop export launches.
- CI or a repeatable local command builds the C# project.

---

## Phase 1 — Core Utilities and Typed Contracts

This phase creates foundations without replacing gameplay.

### Convert or create

- Network op-code constants
- Network DTOs
- JSON serialization settings
- Variant conversion helpers
- Safe node lookup extensions
- Logging helpers
- Result/error types where useful
- Common math and time helpers
- Save DTOs
- Shared enums

### Network model examples

Create typed models for:

- Client input
- Start game
- Upgrade selection
- Ready state
- Vote kick
- Server state snapshot
- Player join/leave
- Wave start/end
- Mob spawn/die
- Game over
- Reconnecting state
- Vote status

Keep wire names identical to the existing Go server protocol.

### Exit criteria

- Typed DTOs serialize to payloads compatible with the current server.
- Captured server payloads deserialize into C# models.
- No gameplay behavior has changed.

---

## Phase 2 — Resource and Domain Models

Convert low-risk data classes before node-heavy scripts.

### Initial targets

- `player_stats.gd`
- `shop_item.gd`
- Runtime representation of `skill_definition.gd`
- Runtime representation of `player_class.gd`
- Shared enums for classes, skill types, item types, and status effects

### Recommended approach

Do not immediately rewrite every `.tres` file. First create C# domain models and mappers that read existing GDScript resources. This separates runtime logic from resource-file migration.

Example flow:

```text
Existing SkillDefinition .tres
        ↓
GDScript Resource instance
        ↓ mapper
C# SkillDefinitionModel
        ↓
C# skill tree/runtime systems
```

After the runtime is stable, convert the actual resource scripts and update `.tres` files in a dedicated resource migration.

### Exit criteria

- C# models reproduce existing values.
- Skill descriptions match current output.
- Class registry produces the same class/subclass set.
- No `.tres` data is lost.

---

## Phase 3 — Components

Components are a good first production replacement because they have narrow responsibilities.

### Conversion order

1. `hit_box.gd`
2. `mana_component.gd`
3. `health_component.gd`
4. `status_effect.gd`
5. `player_death_sequence.gd`
6. Damage number script if useful

### Requirements

- Preserve exported field names.
- Preserve signals such as damage, heal, death, and mana changes.
- Preserve expected method names during transition.
- Verify node ownership and `QueueFree()` behavior.
- Avoid changing damage formulas in the same phase.

### Exit criteria

- Existing GDScript player and enemy scripts can use the C# components.
- Health, mana, death, and hitbox tests pass.
- Solo and multiplayer scenes load without missing script errors.

---

## Phase 4 — Status Effects

### Convert

- `status_effect_manager.gd`
- Buff base behavior
- Debuff base behavior
- Individual buffs and debuffs

### Suggested architecture

Use a typed status-effect base class with:

- Effect ID
- Duration
- Remaining time
- Stack policy
- Refresh policy
- Source entity
- Target entity
- Apply
- Tick
- Remove

Do not use a giant switch statement in the manager. Effects should own their behavior while the manager owns lifecycle and indexing.

### Special checks

- Refresh versus stack semantics
- Duplicate effect handling
- Removal on target death
- Stat restoration after expiry
- Damage-over-time tick timing
- Multiplayer presentation versus authority

### Exit criteria

- Every current effect has a parity test.
- Applying and removing an effect restores exact original stats.
- No orphaned effect nodes remain.

---

## Phase 5 — Progression, Skills, Classes, and Economy

### Convert in this order

1. `level_system.gd`
2. `skill_tree_runtime_data.gd`
3. `skill_registry.gd`
4. `skill_tree_manager.gd`
5. `player_skill_manager.gd`
6. `class_manager.gd`
7. `coin_manager.gd`
8. `shop_manager.gd`

### Reason for this order

The UI and player scripts depend on these managers. Converting them first creates stable typed services that later scene scripts can consume.

### Important constraints

- Preserve singleton names.
- Preserve signals used by HUD and lobby scenes.
- Preserve skill IDs and class IDs.
- Preserve main-class/subclass spending restrictions.
- Preserve skill point refunds and apply behavior.
- Preserve database/admin tuning key compatibility.
- Preserve shop JSON compatibility.

### Refactoring allowed after parity

Once behavior matches, split large managers into:

- Registry/data loader
- Runtime state service
- Validation service
- Persistence adapter

Do not keep all responsibilities in a single 600-line C# autoload merely because the GDScript version was large.

### Exit criteria

- Class selection returns the same scenes and stats.
- Skill trees load all existing skills.
- Skill point rules pass characterization tests.
- Shop purchases and coin changes match existing behavior.

---

## Phase 6 — Save and HTTP Services

### Convert

- `solo_run_save_manager.gd`
- `cloud_save_manager.gd`
- Authentication/session storage portions of `multiplayer_manager.gd`

### Architecture

Separate:

- Save models
- Local file storage
- Encryption/obfuscation adapter
- Cloud API transport
- Save version migration
- Runtime state capture/restore

Every save format must include a version. Add migration functions rather than assuming all saves match the latest model.

### Required compatibility

- Existing solo saves load.
- Existing cloud payloads load.
- Missing fields use safe defaults.
- Unknown fields do not destroy saves.
- Failed cloud operations do not corrupt local state.

### Exit criteria

- Old fixtures load successfully.
- Save-roundtrip tests pass.
- Network failures are handled without blocking the scene tree.

---

## Phase 7 — Networking Infrastructure

This is high risk and should only begin after typed contracts and tests exist.

### Split the current responsibilities

The current networking code should become several C# services:

- `LobbyApiClient`
- `GameWebSocketClient`
- `SessionService`
- `RoomService`
- `NetworkMessageCodec`
- `InputSender`
- `RemotePlayerInterpolator`
- `LocalPlayerReconciler`
- `NetworkClock` or latency tracker

### Convert

- `network_messaging.gd`
- Most of `multiplayer_manager.gd`
- Most of `multiplayer_utils.gd`
- `player_stats_broadcaster.gd`

### Required behavior

- JWT login/register
- Session restore
- Room create/join
- WebSocket lifecycle
- Reconnect grace behavior
- Op-code dispatch
- Input send at 20 Hz
- Pending-input tracking
- Snapshot acknowledgement
- Local reconciliation
- Remote interpolation
- Ping/jitter metrics

### Safety rules

- Do not deserialize arbitrary data directly into scene nodes.
- Validate message type and required fields.
- Cap collection sizes from the network.
- Reject invalid numeric values such as NaN and infinity.
- Keep WebSocket callbacks lightweight.
- Queue scene-tree mutations to the main thread.
- Keep protocol compatibility with the Go server.

### Rollout method

Run old and new parsers side by side in a debug-only comparison mode. The C# parser should process captured messages and compare normalized output with the GDScript path before taking ownership.

### Exit criteria

- Two clients can authenticate, join, start, play, disconnect, and reconnect.
- Host and non-host flows work.
- Prediction and interpolation metrics are no worse than the baseline.
- Invalid messages fail safely.

---

## Phase 8 — Player Runtime

Do not convert the 650-line player script as one direct line-for-line class.

### First split responsibilities

Target C# components:

- `PlayerController`
- `PlayerInputReader`
- `PlayerMovementMotor`
- `PlayerDashController`
- `PlayerCombatController`
- `PlayerStatsController`
- `PlayerVisualController`
- `PlayerNetworkController`

The scene root can remain a `CharacterBody2D` C# script that coordinates these components.

### Conversion order

1. Existing `player_stats_controller.gd`
2. Existing `player_combat_controller.gd`
3. Existing `player_visual_controller.gd`
4. `sword.gd`
5. `sword_slash.gd`
6. `arrow.gd`
7. Main `player.gd`

### Key parity checks

- Local versus remote player mode
- Input ownership
- Movement speed
- Dash duration and cooldown
- Physics tick behavior at 120 Hz
- Attack timing and animation
- Hit stun and knockback
- Class modifier application
- Player death and revive
- Prediction and reconciliation
- Slime visual palette and animation behavior

### Exit criteria

- The same player scenes work by replacing only their root script and mapped dependencies.
- Solo control feels equivalent.
- Remote players remain interpolation-driven.
- No duplicate attack or dash events occur.

---

## Phase 9 — Match and Spawn Systems

### Convert

- `round_manager.gd`
- `mob_scene_registry.gd`
- `mob_spawner.gd`
- `match_state_handler.gd`
- `match_state_router.gd`
- `main.gd`
- `debug_stats_overlay.gd`

### Refactoring target

The current `main.gd` should become a thin scene coordinator. Move logic into services/components for:

- Player binding
- Match startup
- Solo restoration
- Network event routing
- Mob synchronization
- Round synchronization
- Debug telemetry

### Exit criteria

- Main solo scene starts and restores saves.
- Multiplayer scene starts from the lobby.
- Mob spawn/death messages map correctly.
- Round transitions match the old implementation.
- The scene coordinator is substantially smaller than the old `main.gd`.

---

## Phase 10 — Enemies and LimboAI

Enemy conversion must account for LimboAI integration.

### Strategy

Do not rewrite LimboAI. Keep behavior tree resources and convert only scripts where C# integration is verified.

Use three categories:

1. **Safe C# conversion:** enemy body/state data, damage, death, movement helpers.
2. **Adapter conversion:** C# enemy exposes methods/properties called by existing GDScript behavior tasks.
3. **Deferred GDScript:** behavior task scripts remain GDScript until a tested C# replacement is supported.

### Conversion order

1. Shared enemy runtime model
2. `bt_enemy.gd` responsibilities split into C# components
3. Blue slime
4. Archer
5. Plagued lancer
6. Void warden
7. Boss base and boss actions

### Preserve

- Blackboard keys
- Behavior-tree task expectations
- Target selection
- Attack ranges
- Animation names
- Mob IDs
- Server snapshot synchronization
- Death and XP behavior
- Admin live tuning

### Exit criteria

- Each enemy passes an isolated test scene.
- Existing behavior tree assets still load.
- Server-controlled spawn and death work.
- No AI task accesses a missing property or method.

---

## Phase 11 — UI Migration

UI is late because it is scene-heavy and less performance-critical. Convert it after services are stable.

### Recommended order

1. Small reusable HUD widgets
2. HUD panels
3. Pause and death overlays
4. Shop UI
5. Settings UI
6. Auth UI
7. Class selection UI
8. Room lobby controllers
9. Skill tree UI
10. Loading screen

### Do not perform a line-for-line conversion

Large UI scripts should be split into:

- View/controller node
- View model or presentation model
- Service calls
- Formatting helpers
- Reusable widgets

### High-risk UI files

- `skill_tree_ui.gd`
- `room_lobby_carousel_controller.gd`
- `room_lobby_party_controller.gd`
- `room_lobby_view.gd`
- `settings.gd`
- `loading_screen.gd`

### Preserve

- Scene node paths
- Theme behavior
- Button signal connections
- Keyboard/controller navigation
- Host-only visibility rules
- Skill/class color formatting
- Loading transitions
- Pause behavior

### Exit criteria

- No large UI controller owns gameplay domain logic.
- All menus work with mouse and configured keyboard input.
- Lobby works for host and client.
- Skill tree behavior matches progression tests.

---

## Phase 12 — Resource Script Conversion

After C# runtime systems are stable, convert editor-facing resource scripts.

### Targets

- `skill_definition.gd`
- `player_class.gd`
- `player_stats.gd`
- `shop_item.gd`
- Class resource scripts under `game/scripts/resources/classes/`

### Procedure

1. Create equivalent C# `[GlobalClass]` resources.
2. Match exported property names and types.
3. Create a conversion script/tool for `.tres` files where manual reassignment would be error-prone.
4. Convert one resource family at a time.
5. Open every converted resource in Godot.
6. Verify references, icons, scene paths, enums, arrays, and dictionaries.
7. Keep a backup branch/tag before mass changes.

### Special warning

`Variant`-heavy fields such as `value_per_level` need an explicit long-term model. Consider a typed union-like resource structure rather than carrying an unrestricted `Variant` forever.

Possible final model:

- Scalar value progression
- Array value progression
- Base-plus-per-level progression
- Level-keyed progression

### Exit criteria

- All resources load without warnings.
- Skill and class registries return identical data.
- No `.tres` points to removed GDScript classes.

---

## Phase 13 — Remove Compatibility Layer

Only remove GDScript after its replacement has passed all gates.

### Tasks

- Remove obsolete `.gd` scripts.
- Remove temporary snake_case wrappers.
- Remove string-based `Call` bridges.
- Remove duplicate signals.
- Update scenes to C# script paths.
- Update autoload entries.
- Remove dead compatibility mappers.
- Update documentation.
- Run a full reference search for deleted class names and methods.

### Exit criteria

- No scene references missing scripts.
- No runtime call references deleted GDScript methods.
- The project starts with clean logs.
- Required exports build and launch.

---

## 12. File Migration Priority Matrix

### Priority A — Convert early

- Resource/domain models
- Health and mana
- Status-effect base
- Network DTOs
- Save DTOs
- Level/progression logic
- Skill-tree runtime logic
- Shop validation

These are logic-heavy, testable, and low in scene coupling.

### Priority B — Convert after foundations

- Autoload managers
- Networking
- Player controllers
- Match router
- Round manager
- Mob spawner

These are important but highly coupled.

### Priority C — Convert later

- UI controllers
- Enemy-specific scripts
- LimboAI task scripts
- Environment generation
- Visual-only scripts

These depend on stable lower layers or external integration.

### Do not convert

- Third-party plugin source unless necessary
- Godot `.import` or `.uid` files
- Generated MCP addon build output
- Backend code merely for language consistency

---

## 13. Migration Status Tracking

Create `docs/csharp-migration-status.md` with a table like:

| GDScript file | C# replacement | Phase | Status | Parity test | Scene updated | Old file removed |
|---|---|---:|---|---|---|---|
| `components/health_component.gd` | `src/Components/Health/HealthComponent.cs` | 3 | Planned | No | No | No |

Allowed statuses:

- Planned
- Characterized
- In progress
- Compiles
- Integration testing
- Parity verified
- Scene switched
- GDScript removed
- Blocked

Every pull request should update this table.

---

## 14. Pull Request Rules

Each migration PR should:

- Convert one subsystem or one tightly related group.
- Include tests or characterization evidence.
- Avoid unrelated balance or UI changes.
- List every scene changed.
- List every signal/method contract preserved.
- State solo verification.
- State multiplayer verification when applicable.
- State save compatibility impact.
- State rollback steps.
- Remove old code only after the new path is active and verified.

Avoid PRs that convert dozens of unrelated scripts. They are difficult to review and impossible to bisect safely.

---

## 15. Verification Gates

A phase is not complete because it compiles.

### Compile gate

- `dotnet build` succeeds.
- Godot reports no C# build errors.
- No missing script/resource errors appear.

### Scene gate

- Target scenes instantiate.
- Exported references are assigned.
- Signals connect correctly.
- Autoloads initialize in dependency-safe order.

### Solo gate

- Start game.
- Move, dash, attack.
- Spawn and kill enemies.
- Gain XP and level.
- Open skill tree and shop.
- Save, quit, and restore.
- Die and restart/revive as supported.

### Multiplayer gate

- Register/login.
- Host room.
- Join room from another client.
- Select classes.
- Start match.
- Move and attack.
- Observe remote interpolation.
- Spawn and kill mobs.
- Disconnect and reconnect.
- Complete or fail a run.

### Performance gate

Measure before and after for hot systems:

- Frame time
- Physics time
- Allocations per frame
- Garbage collection spikes
- Network parse time
- Snapshot processing time
- Remote interpolation cost
- Mob update cost

C# migration should not be declared successful if architecture improves but runtime regressions are severe.

---

## 16. Risks and Mitigations

### Scene reference breakage

**Risk:** Changing script classes or exported property types invalidates `.tscn` references.

**Mitigation:** Convert one scene family at a time, preserve exported names, and inspect changed scene diffs.

### Signal mismatch

**Risk:** GDScript consumers expect old signal names or argument shapes.

**Mitigation:** Preserve signal contracts until consumers are migrated; add temporary wrapper signals if required.

### Resource incompatibility

**Risk:** Existing `.tres` resources no longer load after changing resource scripts.

**Mitigation:** Use runtime mappers first; perform actual resource conversion in a dedicated late phase.

### Dynamic method calls

**Risk:** String-based calls fail only at runtime.

**Mitigation:** Centralize interop, search all `Call`, `Get`, `Set`, and signal names, then remove them gradually.

### Autoload order

**Risk:** C# singleton initialization order differs from assumptions in existing scripts.

**Mitigation:** Keep `_Ready()` idempotent, avoid static scene-tree access, and explicitly document singleton dependencies.

### Async/thread errors

**Risk:** HTTP/WebSocket tasks mutate Godot nodes outside the main thread.

**Mitigation:** Separate transport from presentation and marshal scene-tree work back to the main thread.

### Serialization drift

**Risk:** C# naming policies change JSON field names.

**Mitigation:** Explicitly annotate wire names and test against captured payload fixtures.

### Performance assumptions

**Risk:** C# code allocates heavily through LINQ, boxing, Variants, and delegate creation.

**Mitigation:** Profile hot paths; avoid allocations in per-frame and network-tick loops.

### Permanent hybrid architecture

**Risk:** Both implementations remain indefinitely.

**Mitigation:** Every bridge must have an owner, removal condition, and tracking-table entry.

### Feature development conflicts

**Risk:** New GDScript work lands in a subsystem currently being converted.

**Mitigation:** Freeze or coordinate target areas and keep migration branches short.

---

## 17. Rollback Strategy

Every migrated subsystem must remain reversible until parity is proven.

Use these rollback layers:

1. Git commit/branch rollback.
2. Scene script reassignment back to the old `.gd` file.
3. Autoload path switch back to the old singleton.
4. Feature flag for high-risk runtime paths such as networking.
5. Preserve old save fixtures and never overwrite them during testing.
6. Keep protocol unchanged so old and new clients can be compared against the same server.

Do not delete the old implementation in the same commit that first activates the replacement for high-risk systems.

---

## 18. Recommended First Milestone

The first milestone should prove the migration approach without touching networking or the main player controller.

### Milestone 1 scope

- Enable Godot .NET project
- Add C# coding standards
- Add typed network DTO project area without activating it
- Convert `HealthComponent`
- Convert `ManaComponent`
- Convert `HitBox`
- Add unit/scene tests
- Replace these scripts in one test player scene and one test enemy scene
- Verify existing GDScript consumers still work

### Why this milestone

It validates:

- C# compilation
- Scene attachment
- Exported fields
- Signals
- GDScript/C# interoperability
- Testing workflow
- Desktop export

It creates useful production code while keeping rollback simple.

---

## 19. Recommended Second Milestone

### Milestone 2 scope

- Convert player stats domain model
- Convert level system
- Convert skill runtime models and mapper
- Convert skill-tree runtime data
- Add parity tests for XP, stats, skill values, and spending rules

This establishes the typed gameplay domain before converting scene-heavy systems.

---

## 20. Completion Definition

The migration is complete when:

- The required desktop game export builds and launches successfully.
- Core gameplay code is C#.
- Networking infrastructure is C# and protocol-compatible.
- Player, match, progression, economy, save, and status systems are C#.
- Large UI controllers are C# or intentionally documented exceptions.
- Enemy runtime is C#, with any remaining GDScript limited to justified LimboAI adapters.
- Existing `.tres` data loads through C# resources or documented stable adapters.
- Old saves load.
- Solo and multiplayer regression suites pass.
- No obsolete dual implementation remains.
- Documentation and `AGENTS.md` reflect C# as the primary client language.

---

## 21. Immediate Next Actions

1. Record the fixed scope: desktop-only Godot client, Windows baseline, with web limited to backend/admin services.
2. Install/use the Godot 4.6 .NET editor build and matching supported .NET SDK.
3. Generate `game/NewGame.csproj` through Godot.
4. Create `game/src/` and `game/tests-csharp/`.
5. Add build and naming rules to `AGENTS.md`.
6. Create the migration status tracker.
7. Add characterization tests for health, mana, XP, skills, saves, and network payloads.
8. Begin Milestone 1 with components only.

Do not begin with `player.gd`, `main.gd`, `multiplayer_utils.gd`, or `skill_tree_ui.gd`. Those files are high-coupling endpoints and should be migrated only after their dependencies have typed C# replacements.

---

## 22. Audit Findings and Required Corrections

The initial phase structure is directionally correct, but architecture phases alone are not enough to execute this migration safely. The following codebase facts make an explicit operational specification mandatory.

### Current coupling snapshot

The following counts were regenerated from the live workspace during M0 on 2026-07-16. They exclude addons and M0 test scripts:

| Contract/coupling type | M0 count | Migration consequence |
|---|---:|---|
| Handwritten GDScript files | 145 | Every file requires a tracked disposition |
| GDScript lines | 22,069 | A big-bang rewrite is unacceptable |
| Exported properties | 495 | Inspector contracts must be inventoried before script replacement |
| Custom signals | 67 | Signal names, arguments, and connection lifecycle require parity checks |
| Direct `.connect(` sites | 188 | Duplicate and orphaned subscriptions are a major risk |
| `get_node` / `get_node_or_null` calls | 146 | Node-path contracts must be captured per scene |
| Deferred calls | 30 | Ordering and frame-boundary behavior must be characterized |
| `await` sites | 82 | Cancellation, freed-node, and main-thread behavior must be reviewed |
| `class_name` declarations | 100 | Global type names and resource loading must remain valid |
| Dictionary usage sites | 259 | Dynamic boundaries require typed conversion plans |
| Runtime `load`/`preload` calls | 45 | Resource paths must remain stable or be migrated explicitly |
| Scene/resource script references | 385 | Blind text replacement is prohibited |
| Autoloads | 16 | Singleton names, order, and dependencies require a migration graph |
| Direct `MultiplayerManager` references | 472 | This singleton must be decomposed behind a compatibility facade |
| Editor/tool scripts | 3 | Tool-time behavior requires a separate migration policy |

These counts show that the main risk is not translating syntax. The risk is preserving Godot editor contracts, scene/resource references, singleton behavior, asynchronous ordering, and wire/save compatibility.

### Gaps closed by this addendum

The migration must now include:

- A complete contract manifest for every migrated script.
- A scene and resource reference migration procedure.
- A toolchain, package, analyzer, and CI policy.
- Exact save-file and network-wire compatibility fixtures.
- Explicit async, cancellation, and node-lifecycle rules.
- Measurable performance and memory budgets.
- Security and secret-redaction requirements.
- A decision log for unresolved product/technical choices.
- Per-script and per-work-package definitions of done.

---

## 23. Mandatory Phase 0 Artifacts

Phase 1 cannot begin until these artifacts exist and have owners.

### 23.1 Migration status registry

Create `docs/csharp-migration-status.md` and list every handwritten `.gd` file. Each row must include:

- GDScript path
- Proposed C# path or explicit retained-GDScript decision
- Owning subsystem
- Scene/resource consumers
- Autoload dependencies
- Risk level
- Characterization test
- Current status
- Activation method
- Rollback method
- Old-script removal condition

No file may disappear from scope simply because it was not named in a phase summary.

### 23.2 Contract manifest

Create `docs/csharp-contract-manifest.md`. Before replacing a script, capture:

- Godot base class
- `class_name` or global type name
- Tool/editor execution status
- Process and physics callbacks
- Process mode and pause behavior
- Groups joined or queried
- Exported field name, type, default, range/hint, and resource reference
- Signal name, argument order, argument type, and known subscribers
- Public/callable method name, argument shape, return shape, and callers
- Required child node paths
- Required sibling/parent assumptions
- Dynamic properties accessed through `get`, `set`, or dictionary keys
- Deferred calls and ordering assumptions
- Awaited signals and cancellation behavior
- Loaded/preloaded resource paths
- Save keys or network fields touched
- Autoloads referenced
- Expected behavior on `_Ready`, `_ExitTree`, death, pause, scene change, and reconnect

The C# replacement must either preserve each contract or list every consumer migrated in the same work package.

### 23.3 Decision log

Create `docs/csharp-decisions.md`. Decisions must be recorded before dependent work starts. At minimum decide:

- Required desktop release targets, with Windows as the baseline
- Confirmation that web is backend/admin only and not a game-client export target
- Godot .NET patch version
- Compatible .NET SDK version
- Unit-test framework
- JSON serializer and naming policy
- HTTP transport approach
- WebSocket transport approach
- Resource migration approach
- Remaining allowed uses of GDScript
- Telemetry/crash-reporting approach
- NuGet dependency approval process
- Performance regression thresholds
- Save backup and recovery policy

Each decision needs date, owner, status, rationale, consequences, and reversal conditions.

### 23.4 Baseline fixture set

Create versioned fixtures under `game/tests-csharp/Fixtures/`:

```text
Fixtures/
├── Network/
│   ├── ClientToServer/
│   ├── ServerToClient/
│   ├── Invalid/
│   └── Reconnect/
├── Saves/
│   ├── SoloV1/
│   ├── CloudV1/
│   ├── AuthSession/
│   ├── Settings/
│   └── Coins/
├── Resources/
│   ├── Skills/
│   ├── Classes/
│   └── Shop/
└── Performance/
```

Fixtures must be copied from sanitized real outputs or generated by the current implementation. Never commit live credentials or personal account data.

### 23.5 Baseline runtime report

Record a repeatable baseline for:

- Startup time to auth menu
- Scene transition time to lobby and match
- Median and p95 frame time
- Median and p95 physics-frame time
- Managed allocations per frame in hot gameplay
- GC pause count and duration
- Input packet serialization time
- Snapshot parse and route time
- Remote-player interpolation cost
- Mob update cost at representative mob counts
- Working-set memory after a representative run
- Save and load latency
- Reconnect latency

The machine, build configuration, scene, player count, mob count, and measurement duration must be recorded.

---

## 24. Toolchain and Project Configuration

### 24.1 Required repository files

After Godot generates the project, add and review:

- `game/NewGame.csproj`
- `game/NewGame.sln` or a repository-level solution
- `global.json`
- `.editorconfig`
- `game/tests-csharp/Oozeborne.UnitTests.csproj`
- Optional Godot-hosted integration test project or test runner setup
- CI build scripts

Do not hand-create a fake Godot project file before the .NET editor has generated the correct SDK structure.

### 24.2 Version pinning

Pin:

- Exact Godot .NET version used by the team and CI
- Compatible .NET SDK feature band
- Test SDK and approved test packages
- Any serializer or analyzer package

Upgrade Godot or .NET in a separate change from subsystem migration. An engine/runtime upgrade and a language migration in the same pull request are not reviewable.

### 24.3 Build configurations

Maintain at least:

- `Debug` for development and parity diagnostics
- `Release` for export/performance validation
- Optional `MigrationCompare` configuration for dual-run comparison code

Debug-only parity code, payload dumps, and comparison adapters must not ship in release builds.

### 24.4 Analyzer and warning policy

Initially enable:

- Nullable reference type analysis
- Compiler warnings at a strict level
- Formatting/naming enforcement
- Dead-code and unused-member checks where compatible with Godot reflection/source generation
- Async misuse checks

Do not blindly enable analyzers that cannot understand Godot-generated code. Suppress only the narrow diagnostic with a documented reason.

### 24.5 Dependency policy

The default dependency policy is "BCL and Godot APIs first."

Before adding a package, document:

- Functional need
- Alternatives considered
- License
- Maintainer/activity status
- Desktop export compatibility, especially Windows
- Native library requirements
- Trimming/AOT implications where relevant
- Serialization compatibility
- Security/update process

Do not introduce a dependency-injection framework, mediator framework, reactive framework, or serializer merely to imitate backend architecture.

---

## 25. Godot C# Contract Rules

### 25.1 Class and file rules

- Godot node/resource classes must be `partial` where required.
- Use a stable namespace rooted at `Oozeborne`.
- Use PascalCase internally.
- Keep temporary snake_case compatibility methods only at the interop boundary.
- Do not rename a global class and replace its script in the same step unless every reference is migrated and verified.

### 25.2 Exported properties

For each `[Export]` member:

- Use a Godot Variant-compatible type.
- Match the old field's semantic type, default, range, enum values, resource class, and nullability.
- Build the C# project before expecting the editor to expose new members.
- Re-open and inspect every changed scene/resource after build.
- Never assume an inspector value survived script replacement; verify serialized values in the scene diff and editor.

If a property cannot retain the same type, add a migration adapter or migrate all serialized consumers in one controlled batch.

### 25.3 Signals and events

- Godot-facing C# signals must use the required delegate naming convention.
- Signal argument types must be Variant-compatible.
- Preserve signal names and argument order until every subscriber is migrated.
- Use C# events only for internal C# communication.
- Record and disconnect long-lived subscriptions in `_ExitTree()`.
- Prevent double connection when `_Ready()` can run more than once through scene reuse.
- Add tests that count event delivery when duplicate delivery would affect damage, purchases, saves, attack, dash, or lobby state.

### 25.4 Node-path rules

Replace fragile string lookups gradually:

1. Capture the current required path in the contract manifest.
2. Prefer exported `NodePath`/typed node references where scene authors need configurability.
3. Cache validated typed references during `_Ready()`.
4. Fail with a clear diagnostic when required nodes are absent.
5. Do not silently create replacement nodes that change scene ownership.

### 25.5 Variant and collection boundaries

At GDScript/C# boundaries:

- Accept `Variant`, `Godot.Collections.Dictionary`, or `Godot.Collections.Array` only in adapters.
- Validate expected key presence and type.
- Convert immediately to a typed C# record/class/value object.
- Convert back only at a Godot-facing boundary.
- Do not retain mutable Godot collections across unrelated systems.
- Be careful with value-type copies from Godot structs; mutate and assign back when required.

### 25.6 Resource identity

- Preserve `res://` paths until a dedicated resource migration.
- Never manually invent or edit `.uid` files.
- Use the Godot editor or a tested migration tool to reassign scripts.
- Do not delete a GDScript resource class while any `.tres` references it.
- Keep icons, `PackedScene`, textures, enum values, and nested resources intact.

---

## 26. Scene and Resource Conversion Runbook

Use this procedure for every scene-bound script family.

### Before activation

1. Identify every `.tscn` and `.tres` that references the script.
2. Record exported values and node paths.
3. Record inherited scenes and resource subclasses.
4. Capture the scene's clean startup log.
5. Add or update a targeted scene test.
6. Confirm the old script remains available for rollback.

### Pilot conversion

1. Convert one disposable/test scene or one duplicated representative scene.
2. Attach the C# script through Godot.
3. Build C#.
4. Reassign exported references.
5. Open, run, close, and reopen the scene.
6. Compare inspector values and serialized diff.
7. Verify all signals exactly once.
8. Verify pause, scene exit, and re-entry behavior.

### Family conversion

After the pilot passes:

1. Convert one scene family only.
2. Update references through the editor or tested tool.
3. Open/save each changed scene and resource.
4. Run a scanner for missing scripts, resources, and node paths.
5. Run the family integration tests.
6. Run at least one full solo smoke test.
7. Run multiplayer smoke tests when the family participates in network play.

### Prohibited shortcuts

- No blind repository-wide `.gd` to `.cs` path replacement.
- No manual `.uid` editing.
- No deleting old scripts before scene activation passes.
- No mass resource conversion without a generated before/after manifest.
- No hiding missing-resource warnings to make the editor appear clean.

---

## 27. Autoload Migration Specification

The project has 16 autoloads and heavy direct singleton coupling. Autoload conversion must use a facade-first strategy.

### Required steps per autoload

1. Inventory all direct references and signal subscribers.
2. Document initialization dependencies on other autoloads.
3. Separate state, transport/data access, domain logic, and presentation notifications.
4. Create typed C# services behind a compatibility-facing Godot node.
5. Keep the existing autoload name and order.
6. Route old GDScript callers through the facade.
7. Migrate consumers incrementally.
8. Replace the facade implementation only after consumers are stable.
9. Remove compatibility methods only after a repository reference search is clean.

### Initialization rules

- Do not access the scene tree from static constructors.
- Do not assume another autoload has completed `_Ready()` unless order and dependency are explicit.
- Make initialization idempotent.
- Expose an explicit ready/initialized state when async startup is required.
- Handle scene reload without duplicating retained state or connections.

### Special handling for `MultiplayerManager`

Do not translate the existing manager into one large C# singleton. It currently combines authentication, HTTP, WebSocket polling, rooms, player selection, presence, serialization, queueing, and signals.

Split behind the compatibility facade into:

- `SessionService`
- `AuthSessionStore`
- `LobbyApiClient`
- `RoomService`
- `GameSocketTransport`
- `OutboundMessageQueue`
- `MatchPresenceStore`
- `PlayerSelectionState`
- `NetworkMessageCodec`

The old public surface remains temporarily, but the implementation must delegate to these components.

---

## 28. Async, Threading, and Node Lifetime

### 28.1 Await policy

- Use Godot signal awaiting where the operation is driven by an engine signal.
- Use `Task`/`Task<T>` for pure C# asynchronous services.
- Never use blocking `.Result`, `.Wait()`, or synchronous sleeps on the main thread.
- Avoid `async void` except event handlers.
- Every long-running or retrying operation needs cancellation.

### 28.2 Node lifetime

An awaited operation may resume after its owner or target node has left the tree. Therefore:

- Store a per-node cancellation source.
- Cancel it in `_ExitTree()`.
- Check cancellation and object validity after awaits.
- Do not capture strong references to transient scenes in long-lived singleton tasks.
- Reject stale responses using request IDs, scene generation IDs, or current-session IDs where appropriate.

### 28.3 Main-thread rule

- Transport, parsing, compression, and pure calculations may run off-thread only after profiling justifies it.
- Scene-tree access, signal emission affecting nodes, resource mutation, and node creation/freeing must occur on the main thread.
- Use one documented dispatcher/deferred-call mechanism rather than ad hoc cross-thread calls.

### 28.4 HTTP lifecycle

The first C# implementation should preserve current request semantics before changing transports. Regardless of transport:

- Define request timeout.
- Define retry policy per idempotency.
- Do not retry login/register/save mutations blindly.
- Propagate cancellation on scene exit/logout.
- Normalize HTTP status, transport, parse, and API errors into typed failures.
- Ensure temporary request nodes or managed handlers are disposed and cannot leak.

---

## 29. Network Protocol Migration Specification

Networking is the highest-risk client migration and requires exact wire fixtures.

### 29.1 Preserve the current envelope

The C# codec must preserve and test:

- Top-level `op` as the current primary operation field.
- `op_code` as a compatibility fallback on receive.
- Payloads where `data` is a JSON string.
- Payloads where `data` is already an object/dictionary.
- Sender identity from top-level `user_id` with payload fallback.
- Existing message `type` values.
- Existing numeric and string representations accepted by the current client/server.

Do not "clean up" this envelope during language migration. A future protocol revision must be separately versioned and deployed compatibly.

### 29.2 Golden packet matrix

For every operation code, store:

- Minimal valid packet
- Full valid packet
- Packet with unknown additive fields
- Packet with missing optional fields
- Packet with missing required fields
- Wrong-type fields
- Empty payload
- Oversized collection/string case
- Reordered/out-of-order state where applicable
- Reconnect/late-join case

Round-trip tests must compare semantic wire output, not only object equality.

### 29.3 Validation limits

Define and enforce:

- Maximum packet bytes
- Maximum string lengths
- Maximum player/mob/list entries
- Valid coordinate and rotation ranges
- Finite-number checks rejecting NaN and infinity
- Valid operation-code range
- Maximum queued reliable messages
- Maximum retained snapshots/interpolation samples

### 29.4 Timing and backpressure

Preserve or explicitly re-baseline:

- Client input send rate: 20 Hz
- Godot physics tick rate: 120 Hz
- Input sequence and acknowledgment behavior
- Pending-input replay rules
- Remote interpolation delay
- Ping/jitter calculation
- Input dropping during backpressure
- Reliable/control-message queue behavior
- Existing outbound queue cap of 64 unless a separately tested change is approved

The migration must test socket close during send, queue flush on reopen, reconnect within grace, reconnect after expiry, duplicate state, stale state, and out-of-order state.

### 29.5 Dual-run comparator

Before activation, the C# decoder/router must run in debug comparison mode against captured input:

1. Feed the same packet to old and new paths.
2. Normalize resulting state/events.
3. Compare operation, sender, parsed payload, and emitted semantic event.
4. Log mismatches without secrets.
5. Block activation while unexplained mismatches remain.

---

## 30. Save and Configuration Migration Specification

### 30.1 Current formats in scope

The migration must explicitly cover:

- `user://auth_session.json`
- `user://solo_saves/slot_1.json` through `slot_5.json`
- `user://solo_saves/slot_names.json`
- Legacy `user://solo_run_save.json`
- Cloud save payloads at version 1
- `user://settings.cfg`
- `user://coins.sav`
- Server configuration files
- Admin configuration where client-side behavior depends on it

### 30.2 Version rules

- Read every known old version.
- Write only the current approved version.
- Implement explicit `V1 -> V2` style migrations.
- Never infer a destructive migration from missing fields.
- Preserve unknown fields when round-tripping formats that may be extended by newer clients/server versions.
- Use invariant numeric formatting.
- Reject invalid ranges safely and report recovery action.

### 30.3 Atomic local writes

Before the first C# writer is activated:

1. Read and validate the existing file.
2. Keep an untouched backup on first migration.
3. Write to a temporary file.
4. Flush/close it.
5. Re-read and validate the temporary file.
6. Replace the target atomically where supported.
7. Retain the last-known-good backup until the new format has loaded successfully in a later run.

A crash or disk-full condition must not erase the only usable save.

### 30.4 Legacy save migration correction

The current legacy flow deletes `user://solo_run_save.json` after copying. The C# migration must be safer:

- Do not delete the old file until the new slot file has been written, re-read, schema-validated, and successfully loaded.
- Prefer renaming the old file to a migration backup rather than deleting it immediately.
- Make migration idempotent so an interrupted launch can retry safely.

### 30.5 Cloud saves

- Never overwrite a cloud slot after a failed or partial local parse.
- Keep slot number and ownership validation server-side.
- Preserve unknown server fields.
- Distinguish no-data, authentication, timeout, server, conflict, and parse errors.
- Define conflict behavior before adding offline/local caching.

---

## 31. Test Architecture

### 31.1 Pure unit tests

Pure logic must be testable without loading Godot scenes. Introduce narrow interfaces only where they improve deterministic testing:

- `IClock`
- `IRandomSource`
- `IFileStore`
- `INetworkTransport`
- `IJsonCodec`
- `ILogger`

Do not wrap every Godot API by default. Add seams around nondeterministic or external boundaries.

### 31.2 Godot integration tests

Use Godot-hosted tests for:

- Scene loading
- Export assignment
- Signal connection and delivery
- Node lifecycle
- Physics/movement
- Animation triggers
- Pause behavior
- Resource loading
- Autoload integration
- C#/GDScript interop

Each converted family needs at least one representative integration scene.

### 31.3 Characterization tests

Before conversion, characterize behavior that may be surprising or arguably imperfect. The migration test should preserve current behavior unless a separate bug-fix decision is made.

Examples:

- Exact level-up thresholds
- Effect refresh timing
- Dash cooldown start point
- Outbox dropping behavior
- Class/subclass reset rules
- Skill description formatting
- Save defaults for absent keys
- Disconnect signal timing

### 31.4 Determinism

Tests must control:

- Time
- Randomness
- Network packet order/delay
- Physics steps where possible
- Save fixture paths
- Locale/culture

A flaky parity test is not an acceptable migration gate.

### 31.5 Error-log gate

Integration tests fail on unexpected:

- C# exceptions
- Godot errors
- Missing script/resource warnings
- Invalid signal connections
- Orphan-node reports
- Unhandled task failures

Expected errors must be asserted narrowly, not globally ignored.

---

## 32. CI and Export Matrix

### Required CI stages

1. Restore packages using locked versions.
2. Build C# in Debug.
3. Build C# in Release.
4. Run pure unit tests.
5. Import/open the Godot project headlessly using the .NET editor binary.
6. Run targeted Godot integration/smoke scenes.
7. Scan scenes/resources for missing scripts and external resources.
8. Run network fixture contract tests.
9. Run save fixture migration tests.
10. Produce at least the required Windows export.
11. Launch the export in a smoke harness where practical.

### Deployment jobs

- Windows desktop build/export is mandatory.
- Linux/macOS game-client jobs are added only if those desktop targets enter scope.
- No Android, iOS, or browser-game export jobs belong in this migration.
- The Next.js admin portal keeps its own web lint/build checks, separate from Godot C# export CI.
- Backend service checks remain separate from game-client migration checks unless a shared contract changes.

### CI output

Retain:

- Build logs
- Test reports
- Export logs
- Missing-resource scan report
- Parity mismatch report
- Performance comparison summary for benchmark jobs

Migration pull requests cannot merge with unexplained Godot import errors or C# warnings newly introduced by the change.

---

## 33. Performance and Memory Budgets

Exact numeric budgets must be measured and approved in Phase 0. Until then, use these default regression gates:

- No more than 5% regression in median frame or physics time for a migrated hot subsystem.
- No more than 10% regression in p95 frame or physics time.
- No new sustained managed allocations in per-frame/per-physics hot loops without justification.
- No additional recurring GC spikes visible during representative gameplay.
- No more than 10% regression in snapshot parsing/routing time.
- No more than 10% regression in interpolation cost at the same remote-player count.
- No more than 10% regression in mob update cost at the same mob count.
- No unbounded growth in queues, retained snapshots, event subscriptions, tasks, or node counts.

These are migration guardrails, not final game optimization targets. A waiver requires before/after evidence and an owner for follow-up.

### Required profiles

Benchmark at minimum:

- Solo, low mob count
- Solo, peak intended mob count
- Multiplayer host/client with 2 players
- Multiplayer with intended maximum players
- Reconnect flow
- Skill/effect-heavy combat
- Skill tree and large UI open/close cycles
- Repeated scene transitions
- Save/load loop

Use both Godot profiling and managed runtime diagnostics where available. Measure Release exports as well as editor builds.

---

## 34. Logging, Diagnostics, and Security

### 34.1 Structured categories

Use stable categories such as:

- `Auth`
- `LobbyApi`
- `GameSocket`
- `NetworkCodec`
- `Prediction`
- `Interpolation`
- `Save`
- `ResourceMigration`
- `SceneContract`
- `Gameplay`
- `MigrationParity`

### 34.2 Secret redaction

The current networking path can construct an authenticated WebSocket URL containing the token. Migration diagnostics must never print that full URL.

Redact:

- JWTs and query-string tokens
- Authorization headers
- Passwords
- Email addresses where unnecessary
- Save payload personal data
- Admin credentials

Captured fixtures must use synthetic identities and invalid tokens.

### 34.3 Error handling

- Record unhandled C# exceptions with subsystem and scene context.
- Observe/log failed background tasks.
- Show user-safe errors for auth/save/network failures.
- Keep detailed diagnostics out of release UI.
- Avoid swallowing exceptions merely to preserve flow; return typed failure and preserve recovery state.

### 34.4 Client trust boundary

C# conversion must not weaken server authority. Continue server validation for identity, room host privileges, damage, movement limits, cooldowns, skill activation, currency, saves, and admin commands.

Also validate client-side packet sizes and data shapes to protect client stability even when the server is expected to be trusted.

---

## 35. Editor and Tool Script Policy

The current editor-time scripts must be handled separately from runtime scripts.

Initial policy:

- Keep existing tool scripts in GDScript until runtime foundations are stable.
- Convert only when C# editor behavior has been validated.
- Use the C# tool attribute only where editor execution is required.
- Guard editor-only behavior explicitly.
- Do not perform network calls, account access, save mutation, or destructive generation merely because the inspector refreshes.
- Make generation idempotent.
- Test editor reload, script rebuild, scene reopen, undo/redo where relevant, and exported-property refresh.

Tool-script migration is not complete until both editor-time and runtime behavior are verified.

---

## 36. Work Package Dependency Map

| Package | Scope | Depends on | Risk | Required exit artifact |
|---|---|---|---|---|
| M0 | Toolchain, decisions, manifests, fixtures, baselines | None | Medium | Reproducible build/export and approved decisions |
| M1 | Core DTOs, adapters, health/mana/hitbox | M0 | Low | Mixed-language pilot scene passes |
| M2 | Stats, progression, skill runtime, class runtime, economy | M1 | Medium | Pure parity suite and unchanged resource output |
| M3 | Local/cloud saves, auth store, HTTP client | M2 | High | V1 fixture migration and failure-recovery suite |
| M4 | WebSocket, codec, queues, prediction/interpolation | M1, M2, M3 | Critical | Dual-run parity and two-client reconnect suite |
| M5 | Player controllers, weapons, projectiles | M1, M2, M4 | High | Solo feel and multiplayer prediction parity |
| M6 | Match, rounds, spawn, state router | M2, M4, M5 | High | Full run smoke in solo and multiplayer |
| M7 | Enemy runtime and LimboAI adapters | M1, M2, M6 | High | Per-enemy scene suite and admin tuning parity |
| M8 | HUD, menus, lobby, settings, skill tree | M2, M3, M4, M6 | Medium/High | Input/navigation/lobby UI regression suite |
| M9 | Actual `.tres` script conversion | M2–M8 stable | Critical | Full resource manifest and clean reload/export |
| M10 | Compatibility removal and cleanup | All | High | Zero stale references and final regression pass |

Do not start a dependent package because staffing is available while its contract/test prerequisites are incomplete.

---

## 37. Per-Script Definition of Done

A script is not "migrated" when a `.cs` file exists. It is complete only when:

- The status registry row is updated.
- The old contract is documented.
- The C# replacement compiles without new warnings.
- All exported values have been verified.
- Signals/events fire exactly as expected.
- Public callers have parity or were migrated.
- Required scenes/resources reopen cleanly.
- Characterization and new unit tests pass.
- Relevant solo tests pass.
- Relevant multiplayer tests pass.
- Save/network compatibility tests pass when applicable.
- Pause, scene exit, and re-entry are tested.
- No unexpected errors, orphan nodes, leaked subscriptions, or unobserved tasks remain.
- Performance is within the approved budget.
- Security/logging review is complete for boundary code.
- Activation and rollback steps are documented and tested.
- The old GDScript file is removed only after its removal condition is met.
- Documentation is updated.

---

## 38. Stop/Go Gates

Pause the migration and reassess when any of these occurs:

- The required Windows desktop build cannot produce a stable minimal C# export.
- A newly approved desktop target cannot produce a stable minimal C# export.
- Resource conversion loses serialized data or breaks editor loading.
- Network parity mismatches cannot be explained.
- Old saves cannot be loaded safely.
- A migrated hot subsystem exceeds the approved performance budget.
- Mixed-language interop causes recurring runtime-only failures.
- Feature work repeatedly invalidates the migration baseline.
- CI cannot reproduce local builds.
- The migration creates a second source of truth for authoritative gameplay state.

Proceed to the next package only when the current package's exit artifacts and rollback path are complete.

---

## 39. Revised Immediate Order

1. Record the confirmed architecture boundary: desktop game client; web backend and admin portal only.
2. Pin Godot .NET and .NET SDK versions.
3. Generate and review the actual Godot C# project.
4. Create the decision log, status registry, and contract manifest.
5. Capture sanitized save/network/resource fixtures.
6. Capture performance and memory baselines.
7. Add build, unit-test, Godot integration-test, and export CI.
8. Inventory contracts for the first component family.
9. Run the mixed-language component pilot.
10. Review the pilot before approving any autoload, player, networking, resource, or large UI conversion.

The migration is now considered implementation-ready only after M0 is complete, not merely because this document exists.
