# Oozeborne C# Migration Contract Manifest

This document defines the compatibility inventory required before replacing any GDScript with C#. Populate one entry per migrated script or tightly coupled script family.

The M0 audit regenerated from the live workspace on 2026-07-16 found:

- 145 handwritten GDScript files
- 22,069 GDScript lines
- 495 exported properties
- 67 custom signals
- 188 direct `.connect(` sites
- 146 `get_node` / `get_node_or_null` calls
- 30 deferred calls
- 82 await sites
- 100 global `class_name` declarations
- 259 dictionary usage sites
- 45 runtime `load` / `preload` calls
- 385 scene/resource script references
- 16 autoloads
- 3 `@tool` scripts

Counts use `rg` against `game/scripts/` and script references in `game/scenes/` plus `game/resources/`; they exclude addons and M0 test scripts. These are snapshot counts, not permanent truth. Regenerate after major feature merges.

## Contract Status

- Not inventoried
- Inventoried
- Characterized
- C# contract drafted
- Pilot active
- Parity verified
- Old contract retired
- Intentionally retained
- Blocked

## Required Entry Template

```markdown
## CONTRACT-XXX — `game/scripts/path/file.gd`

### Ownership

- Subsystem:
- Work package:
- Risk: Low / Medium / High / Critical
- Owner:
- Status: Not inventoried
- Proposed C# path:
- Retention decision: Migrate / Adapter / Keep GDScript
- Removal condition:

### Godot Type Contract

- Base class:
- `class_name`:
- `@tool` / editor execution:
- Process callbacks:
- Physics callbacks:
- Input callbacks:
- Process mode:
- Pause behavior:
- Groups joined:
- Groups queried:

### Exported Inspector Contract

| Name | GDScript type | Default | Hint/range | Resource/node requirement | C# equivalent | Verified |
|---|---|---|---|---|---|---|

### Signal Contract

| Signal | Arguments in order | Emitters | Subscribers | Duplicate-sensitive | C# representation | Verified |
|---|---|---|---|---|---|---|

### Callable/Public Method Contract

| Existing name | Arguments | Return | Known callers | Ordering/side effects | Compatibility strategy | Verified |
|---|---|---|---|---|---|---|

### Node and Scene Contract

| Required path/relation | Expected type | Required/optional | Failure behavior | C# binding | Verified |
|---|---|---|---|---|---|

- Scenes attaching this script:
- Inherited scenes:
- Resources referencing this script:
- Script/resource paths loaded dynamically:
- Ownership assumptions:
- Nodes created/freed:

### Dynamic Data Contract

| Dictionary/Variant boundary | Required keys/types | Optional keys/defaults | Unknown-field behavior | Typed C# model |
|---|---|---|---|---|

### Lifecycle and Ordering Contract

- `_Ready()` behavior:
- `_EnterTree()` behavior:
- `_ExitTree()` cleanup:
- Deferred calls:
- Awaited operations:
- Cancellation behavior:
- Behavior after owner/target leaves tree:
- Re-entry/reuse behavior:
- Pause/unpause behavior:

### External Dependency Contract

- Autoloads referenced:
- Signals subscribed from autoloads:
- HTTP endpoints:
- Network operation codes/fields:
- Save/config paths and keys:
- Backend/admin tuning keys:
- LimboAI blackboard keys/tasks:

### Characterization Evidence

- Unit tests:
- Integration scene:
- Golden fixtures:
- Manual parity checklist:
- Performance baseline:
- Known existing quirks intentionally preserved:

### Activation

- Scene/resource reassignment steps:
- Compatibility facade/wrappers:
- Feature/debug comparison switch:
- Rollback steps:
- Validation commands:

### Completion

- [ ] Exports preserved or all serialized consumers migrated
- [ ] Signals preserved and exactly-once behavior verified
- [ ] Callers migrated or compatibility methods retained
- [ ] Node paths verified
- [ ] Dynamic data converted at boundary
- [ ] Await/cancellation/lifetime reviewed
- [ ] Save/network contracts tested if applicable
- [ ] Solo verification passed
- [ ] Multiplayer verification passed if applicable
- [ ] Performance budget passed
- [ ] No secrets in logs
- [ ] Scenes/resources reopen cleanly
- [ ] Old script removal condition met
```

---

## Global Contracts

## M0 Interop Foundation Contract

- Package: M0
- Production GDScript replaced: none
- C# class: `game/src/Interop/M0InteropProbe.cs`
- Integration scene: `game/tests-csharp/Integration/m0_interop_test.tscn`
- Activation: explicit test-scene launch only
- Rollback: remove the M0 C# and test files; no production scene/autoload reassignment is required
- Exported contract: `ProbeLabel: String`, `SkillResource: Resource`
- Signal contract: `ProbeCompleted(String marker)`
- GDScript-to-C# methods: `echo_from_csharp`, `emit_probe`, `enemy_probe_from_limbo`, `get_limbo_call_count`
- C#-to-GDScript boundary: `call_gdscript` invokes the fixture method `echo_from_gdscript`
- Resource boundary: `read_skill_id` reads `skill_id` from an existing GDScript `SkillDefinition` resource through `Variant`
- LimboAI boundary: a project-owned GDScript `BTAction` calls `enemy_probe_from_limbo` on its C# agent; third-party LimboAI code is unchanged
- Save/network contracts: fixture-only; no writer, parser, op code, or payload activation
- Verified: Debug/Release compile and Windows export launch, inspector export retention, signal delivery, both call directions, GDScript resource read, and LimboAI-to-C# call
- Removal condition: retain until the first production M1 component proves the same interop contracts and has its own parity scene

## Autoload Order

Current declared order in `game/project.godot`:

1. `MultiplayerManager`
2. `NetworkMessaging`
3. `MultiplayerUtils`
4. `PlayerSkillManager`
5. `StatusEffectManager`
6. `LevelSystem`
7. `SkillRegistry`
8. `SkillTreeManager`
9. `DamageNumbers`
10. `CoinManager`
11. `ShopManager`
12. `SlimePaletteRegistry`
13. `ClassManager`
14. `SoloRunSaveManager`
15. `AdminManager`
16. `CloudSaveManager`

Before migrating an autoload, add its dependency edges below. Preserve the public singleton name and order until every dependent consumer is migrated.

| Autoload | Depends on during initialization | Runtime dependencies | Subscribers | Migration facade | Status |
|---|---|---|---|---|---|
| MultiplayerManager | To inventory | ClassManager, SlimePaletteRegistry, NetworkMessaging | Many | Required | Not inventoried |
| NetworkMessaging | To inventory | MultiplayerManager | To inventory | Required | Not inventoried |
| MultiplayerUtils | To inventory | MultiplayerManager, NetworkMessaging | To inventory | Required | Not inventoried |
| PlayerSkillManager | To inventory | SkillRegistry/Class state | To inventory | Required | Not inventoried |
| StatusEffectManager | To inventory | Effect nodes/entities | To inventory | Required | Not inventoried |
| LevelSystem | To inventory | Player stats/components | HUD/player | Required | Not inventoried |
| SkillRegistry | To inventory | `.tres` skill resources | Skill systems/UI | Required | Not inventoried |
| SkillTreeManager | To inventory | SkillRegistry/ClassManager | UI/save/player | Required | Not inventoried |
| DamageNumbers | Scene autoload | Damage number scene | Combat | Decide | Not inventoried |
| CoinManager | Scene autoload | Save/shop | HUD/shop | Required | Not inventoried |
| ShopManager | To inventory | CoinManager/item JSON | Shop UI | Required | Not inventoried |
| SlimePaletteRegistry | To inventory | Slime scenes/resources | Lobby/player | Decide | Not inventoried |
| ClassManager | Scene autoload | Class scripts/scenes | Lobby/player/save | Required | Not inventoried |
| SoloRunSaveManager | To inventory | ClassManager/SkillTree/Coin | Save UI/main | Required | Not inventoried |
| AdminManager | To inventory | Config/network/game systems | Admin UI | Decide | Not inventoried |
| CloudSaveManager | To inventory | MultiplayerManager/Class/Skill/Coin | Save UI | Required | Not inventoried |

## Network Envelope Contract

The migration must preserve these current receive rules:

| Element | Current behavior | Required C# behavior |
|---|---|---|
| Operation | Top-level `op` | Primary field |
| Operation fallback | Top-level `op_code` | Continue accepting during compatibility period |
| Payload | Entire envelope when no `data` | Preserve |
| Encoded payload | `data` may be a JSON string | Parse once into object when valid |
| Object payload | `data` may already be a dictionary | Accept directly |
| Sender | Top-level `user_id` | Primary source |
| Sender fallback | Payload `user_id` | Preserve |
| Type discriminator | Payload `type` | Preserve exact values |
| Compatibility event | Normalized match state with JSON data, op code, optional presence | Preserve until consumers migrate |

Required fixture groups:

- Valid packets for every op code
- Unknown additive fields
- Missing optional fields
- Invalid/missing required fields
- Wrong types
- Empty payloads
- Oversized packets and collections
- NaN/infinity attempts
- Out-of-order and duplicate snapshots
- Reconnect and late join
- Backpressure and queue flush

## Save and Config Contract

| Path/source | Current format/version | Writer | Required migration behavior | Fixture status |
|---|---|---|---|---|
| `user://auth_session.json` | JSON, unversioned | MultiplayerManager | Read old shape; do not log token; define future versioning | Missing |
| `user://solo_saves/slot_1.json`–`slot_5.json` | JSON v1 | SoloRunSaveManager | Back up, validate, atomic replace, explicit migrations | Missing |
| `user://solo_saves/slot_names.json` | JSON dictionary | SoloRunSaveManager | Preserve string slot keys and defaults | Missing |
| `user://solo_run_save.json` | Legacy JSON | SoloRunSaveManager | Idempotent verified copy; retain migration backup | Missing |
| Cloud save slots | JSON payload v1 | CloudSaveManager/API | Preserve unknown fields and typed failure modes | Missing |
| `user://settings.cfg` | ConfigFile | Settings UI | Preserve sections, keys, defaults, keybind encoding | Missing |
| `user://coins.sav` | To inventory | CoinManager | Capture exact binary/text contract before conversion | Missing |
| `server_config.cfg` | ConfigFile | Manual/export config | Preserve host, port, scheme behavior | Missing |
| `config/admin_list.cfg` | ConfigFile | Project/admin config | Preserve only if still required after server auth review | Missing |

## Editor/Tool Contract

Current project-owned editor/tool scripts:

- `game/scripts/levels/forest_arena_environment.gd`
- `game/scripts/ui/gameplay/hud_minimap.gd`
- `game/scripts/ui/gameplay/skill_tree_card.gd`
- `game/scripts/ui/gameplay/skill_tree_ui.gd`

For each, document separately:

- What runs in the editor
- What data/nodes it generates or mutates
- Inspector refresh behavior
- Undo/redo expectations
- Runtime-only guards
- Network/save/destructive operations that must never run in editor context
- Reload and recompilation behavior

## First Pilot Contracts

Populate these first:

1. `game/scripts/components/hit_box.gd`
2. `game/scripts/components/mana_component.gd`
3. `game/scripts/components/health_component.gd`
4. One representative player test scene
5. One representative enemy test scene

Do not inventory `player.gd`, `main.gd`, or networking first merely because they are important. Their contracts depend on the lower-level pilot and service decisions.
