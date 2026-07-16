# Oozeborne Project Instructions

Use this file as the starting context for every coding session in this repository.

## Project Summary

Oozeborne is a multiplayer action roguelite built as a single repository containing:

- `game/` — desktop-only Godot 4.6 game client, currently written primarily in GDScript and planned for C# migration
- `moon_server/game-server/` — Go authoritative WebSocket game server
- `moon_server/lobby-api/` — Node.js/Express REST backend API
- `moon_server/admin-portal/` — browser-based Next.js admin and live-tuning portal; this is not a playable web game client
- `moon_server/db/migrations/` — PostgreSQL schema and seed migrations
- `moon_server/docker-compose.yml` — local backend stack
- `docs/` — current architecture and gameplay documentation
- `tools/` — development utilities

The playable client is entirely desktop-only. Windows is the current development and release baseline unless another desktop OS is explicitly added later. There is no browser, Android, or iOS game client in scope.

The client supports solo and multiplayer paths. Multiplayer uses the lobby API for authentication and room discovery, then connects to the Go game server for the authoritative match. The web portion of the repository exists only for backend APIs and the admin portal.

## Read These First

Before making broad changes, read only the documentation relevant to the task:

- `docs/workspace-overview.md` — repository map
- `docs/game-architecture.md` — client gameplay architecture
- `docs/multiplayer-architecture.md` — multiplayer client flow
- `docs/server-architecture.md` — backend architecture
- `docs/SkillTreeReference.md` — skill tree rules and data layout
- `docs/enemies.md` — enemy implementation notes
- `moon_server/README.md` — backend setup

Do not reread the whole repository for each task. Inspect the smallest relevant area.

## Runtime Flow

Typical multiplayer flow:

1. Godot auth UI logs in or registers through the lobby API.
2. The lobby API returns a JWT and player/session data.
3. The player creates or joins a room through REST endpoints.
4. Redis stores room/session state.
5. The client receives a WebSocket URL for the Go game server.
6. The client connects with JWT authentication.
7. The Go server runs the authoritative simulation and broadcasts snapshots.
8. Godot interpolates remote players and synchronizes match state.

Typical solo flow:

1. The player starts from the solo menu.
2. Godot runs local gameplay without the backend room flow.
3. Solo progress is handled by the local run save system.

Always preserve both paths unless the task explicitly targets only one mode.

## Important Client Files

### Main gameplay

- `game/scripts/systems/game/main.gd` — match orchestration and player binding
- `game/scripts/systems/game/match_state_router.gd` — routes server match messages
- `game/scripts/systems/game/match_state_handler.gd` — match-state handling
- `game/scripts/systems/game/mob_spawner.gd` — local and network mob spawning
- `game/scripts/systems/game/round_manager.gd` — round progression

### Player

- `game/scripts/entities/player/player.gd` — movement, input, dash and base player behavior
- `game/scripts/entities/player/player_combat_controller.gd` — combat behavior
- `game/scripts/entities/player/player_stats_controller.gd` — stat application
- `game/scripts/entities/player/player_visual_controller.gd` — sprite and visual behavior

### Multiplayer

- `game/scripts/globals/multiplayer_manager.gd` — auth/session and connection coordination
- `game/scripts/globals/multiplayer_utils.gd` — remote-player registration and interpolation
- `game/scripts/globals/network_messaging.gd` — network message helpers
- `game/scripts/systems/game/player_stats_broadcaster.gd` — player stat synchronization

### Classes and skills

- `game/scripts/globals/class_manager.gd` — class registry and lookup
- `game/scripts/globals/player_skill_manager.gd` — active player skills
- `game/scripts/globals/skill_registry.gd` — skill resource registry
- `game/scripts/globals/skill_tree_manager.gd` — progression and skill-point rules
- `game/scripts/globals/skill_tree_runtime_data.gd` — runtime skill-tree state
- `game/scripts/resources/player_class.gd` — class resource model
- `game/scripts/resources/player_stats.gd` — player stat model
- `game/scripts/resources/skill_definition.gd` — skill resource model
- `game/resources/skills/` — data-driven `.tres` skill definitions

### Combat and effects

- `game/scripts/components/health_component.gd`
- `game/scripts/components/mana_component.gd`
- `game/scripts/components/status_effect.gd`
- `game/scripts/globals/status_effect_manager.gd`
- `game/scripts/effects/buffs/`
- `game/scripts/effects/debuffs/`

### Enemies

Enemy AI uses LimboAI behavior trees plus enemy-specific scripts.

- `game/scripts/entities/enemies/mob_behavior_tree/main/bt_enemy.gd` — shared enemy base
- `game/scripts/entities/enemies/mob_behavior_tree/` — regular enemies
- `game/scripts/entities/enemies/boss_behavior_tree/` — boss logic
- `game/scripts/systems/game/mob_scene_registry.gd` — mob scene lookup

### UI

- `game/scripts/ui/auth/` — login and main menus
- `game/scripts/ui/lobby/` — room lobby, party, class selection and match start
- `game/scripts/ui/gameplay/hud_ui.gd` — gameplay HUD root
- `game/scripts/ui/gameplay/skill_tree_ui.gd` — large skill-tree UI controller
- `game/scripts/ui/gameplay/death_overlay.gd` — death and revive flow
- `game/scripts/ui/settings/settings.gd` — settings and keybinds

### Saving and economy

- `game/scripts/globals/cloud_save_manager.gd` — server-backed saves
- `game/scripts/globals/solo_run_save_manager.gd` — local solo run saves
- `game/scripts/globals/coin_manager.gd`
- `game/scripts/globals/shop_manager.gd`
- `game/resources/data/shop_items.json`

## Important Backend Files

### Go authoritative server

- `moon_server/game-server/main.go` — WebSocket endpoint, message handling, game tick and skill processing
- `moon_server/game-server/room.go` — room simulation and broadcasting
- `moon_server/game-server/player.go` — authoritative player state
- `moon_server/game-server/types.go` — network payload types
- `moon_server/game-server/auth.go` — JWT validation
- `moon_server/game-server/config.go` — environment configuration
- `moon_server/game-server/admin.go` — admin server controls

The game server is authoritative. Do not move security-sensitive multiplayer decisions to the Godot client.

### Lobby API

- `moon_server/lobby-api/src/index.js` — Express bootstrap
- `moon_server/lobby-api/src/routes/auth.js`
- `moon_server/lobby-api/src/routes/rooms.js`
- `moon_server/lobby-api/src/routes/profiles.js`
- `moon_server/lobby-api/src/routes/saves.js`
- `moon_server/lobby-api/src/routes/friends.js`
- `moon_server/lobby-api/src/routes/chat.js`
- `moon_server/lobby-api/src/routes/game.js`
- `moon_server/lobby-api/src/routes/admin.js`
- `moon_server/lobby-api/src/middleware/auth.js`
- `moon_server/lobby-api/src/middleware/validate.js`
- `moon_server/lobby-api/src/middleware/rateLimiter.js`

### Admin portal

- `moon_server/admin-portal/app/dashboard/page.tsx` — dashboard composition
- `moon_server/admin-portal/components/` — moderation and live room controls
- `moon_server/admin-portal/components/tuning/` — class, enemy and item tuning
- `moon_server/admin-portal/lib/api.ts` — API wrapper

### Database

Migrations are sequential and must remain backward-safe:

- `moon_server/db/migrations/001_init.sql` through `010_class_base_stats.sql`

Never edit an already-deployed migration to change production state. Add a new numbered migration unless the task is explicitly limited to an unshipped local reset.

## Data Ownership Rules

Use the correct source of truth:

- Permanent player/account data: PostgreSQL
- Session, room registry and pub/sub data: Redis
- Authoritative live match state: Go game server
- Client presentation and interpolation: Godot
- Skill definitions and many gameplay values: Godot `.tres` resources and backend tuning tables
- Solo run state: local Godot save manager

When adding a synchronized field, update every necessary layer:

1. server type/payload
2. server simulation or API logic
3. client message parsing/router
4. client runtime state
5. UI, save or admin layer when applicable

Search for the existing payload name before creating a new parallel representation.

## Class and Skill Structure

Main class families currently include:

- DPS
- Tank
- Support
- Controller
- Hybrid

Each family has subclasses and a `main` skill resource folder. Skills are stored under:

`game/resources/skills/<main_class>/<subclass>/`

Class scripts are stored under:

`game/scripts/resources/classes/<main_class>/`

Keep skill IDs, filenames, class registrations, database tuning keys and UI references consistent. A skill change may require updates in more than one location.

## Scene and Asset Rules

- Player visuals use slime scene variants under `game/scenes/entities/player/`.
- Slime sprite assets live under `game/assets/sprites/Player/Slime/`.
- Do not manually edit Godot `.import` or `.uid` files unless a specific recovery task requires it.
- Do not treat generated `.next/` output, compiled `.exe` files or imported asset metadata as source code.
- Prefer editing `.gd`, `.tscn`, `.tres`, JSON, Go, JS/TS and SQL source files.

## Coding Rules

- Make focused changes; do not rewrite large systems unnecessarily.
- Preserve established naming, node paths, signals and scene structure.
- Use typed GDScript where nearby code already uses types.
- Keep network payloads explicit and backward-compatible where practical.
- Validate all untrusted API and WebSocket input server-side.
- Never trust client-supplied identity, damage, currency, cooldown or admin state.
- Avoid adding dependencies unless they solve a clear need.
- Do not duplicate managers or sources of truth.
- Check solo and multiplayer behavior for gameplay changes.
- Check host and non-host behavior for lobby changes.
- Check reconnect/disconnect behavior for network changes.
- Keep UI logic separated from authoritative gameplay logic.

## Generated and Third-Party Content

Normally exclude these from reviews and edits:

- `moon_server/admin-portal/.next/`
- compiled `.exe` files in `moon_server/game-server/`
- Godot `.import` files
- Godot `.uid` files
- third-party addon internals under `game/addons/limboai/`
- built output under `game/addons/godot_mcp_server/build/`
- lockfiles unless dependencies change

The Godot MCP addon source is under `game/addons/godot_mcp_server/src/`. Only edit it when the task specifically concerns that addon.

## Verification

Run the smallest relevant verification after changes.

### Godot

Use available Godot headless checks or targeted test scenes. Existing tests include:

- `game/tests/lancer_solo_test.tscn`
- `game/tests/overlay_pause_test.tscn`
- `game/tests/round_popup_timing_test.tscn`
- `game/tests/slime_detection_death_test.tscn`

At minimum, check for GDScript parse errors and broken resource/scene paths.

### Godot C# migration

- Use Godot `4.6.2` .NET and the repository-pinned .NET SDK from `global.json`.
- Keep C# source under `game/src/` and pure tests under `game/tests-csharp/Unit/`.
- Set `GODOT_DOTNET_EXE` to the 4.6.2 .NET editor and run `tools/csharp/Verify-M0.ps1` for the foundation build, test, interop, and Windows export gates.
- Do not start M1 production conversion while `docs/csharp-migration-status.md` reports M0 as incomplete.

### Go server

From `moon_server/game-server/`:

```bash
go test ./...
go vet ./...
```

When no tests exist for the changed behavior, at least build the package.

### Lobby API

From `moon_server/lobby-api/`, run the available package scripts and start-up validation. Inspect `package.json` before choosing a command.

### Admin portal

From `moon_server/admin-portal/`, use the package scripts defined in `package.json`, normally lint/build checks.

### Full backend

Use `moon_server/docker-compose.yml` only when integration verification is needed. Do not run or rebuild every service for a small isolated change.

## Security-Sensitive Areas

Treat these as high risk and inspect related call sites before editing:

- JWT authentication
- room ownership and host permissions
- admin endpoints and admin portal actions
- save slot ownership
- currency and shop purchases
- player stats and skill activation
- damage, movement and cooldown validation
- chat and moderation
- Redis room/session keys
- database migrations

Never commit real secrets. Use `.env.example` for documented environment variables.

## Common Change Checklist

For gameplay changes:

- Does it work in solo?
- Does it work in multiplayer?
- Is the server authoritative where needed?
- Are stats and skills recalculated correctly?
- Are save/load and revive flows affected?
- Does the HUD update?

For network changes:

- Are Go payload types updated?
- Is message parsing updated in Godot?
- Is reconnect or late join handled?
- Is malformed input rejected?
- Is old or absent data handled safely?

For class or skill changes:

- Resource file
- registry
- class script
- UI description/icon
- runtime application
- database/admin tuning keys
- save compatibility

For API changes:

- validation
- authentication/authorization
- rate limiting where appropriate
- database transaction/error handling
- Godot or admin portal caller
- response compatibility

## Session Workflow

1. Read this file.
2. Read only the relevant architecture document.
3. Locate symbols and call sites before editing.
4. Inspect nearby patterns.
5. Make the smallest complete change.
6. Verify the affected component.
7. Report files changed, verification and remaining risks.

When current code conflicts with documentation, trust the current code and update the documentation if the mismatch is meaningful.
