# Oozeborne C# Migration Status Registry

This registry tracks every project-owned GDScript under `game/scripts/`. Update it in every migration pull request.

## Status Values

- Planned
- Inventoried
- Characterized
- In progress
- Compiles
- Integration testing
- Parity verified
- Activated
- GDScript removed
- Intentionally retained
- Blocked

## Work Packages

- M0 — toolchain, decisions, manifests, fixtures, baseline, CI
- M1 — core adapters and components
- M2 — stats, progression, skills, classes, status effects, economy
- M3 — saves, auth store, HTTP
- M4 — networking, prediction, interpolation
- M5 — player, weapons, projectiles, item entities
- M6 — match, rounds, spawn, routing
- M7 — enemies and LimboAI adapters
- M8 — UI, admin client, settings, presentation
- M9 — editor tools and actual `.tres` resource-script conversion
- M10 — compatibility removal and cleanup

## Current Package Status

| Package | Status | Evidence | Remaining gate |
|---|---|---|---|
| M0 | In progress | Godot-generated `NewGame.csproj`; pinned SDK; warning-free Debug/Release builds; 3 unit tests; six-check mixed-language/LimboAI integration pass; 4 existing GDScript smoke scenes; sanitized fixtures; Windows Debug/Release exports and five-second launch gates; repeatable PowerShell and Windows CI workflows | Representative full solo/multiplayer performance, save/load, and reconnect baselines |

M0 is test-only and does not activate a replacement for any registry row below. M1 must not begin until the remaining M0 gates are recorded as passed or explicitly approved with evidence.

## Registry

The initial package/risk assignment is a planning estimate. Change it only with a documented reason.

| GDScript file | Package | Risk | Status | Contract inventoried | Parity test | Activated | Old file removed |
|---|---|---|---|---|---|---|---|
| `game/scripts/components/health_component.gd` | M1 | Low | Planned | No | No | No | No |
| `game/scripts/components/hit_box.gd` | M1 | Low | Planned | No | No | No | No |
| `game/scripts/components/mana_component.gd` | M1 | Low | Planned | No | No | No | No |
| `game/scripts/components/player_death_sequence.gd` | M1 | Medium | Planned | No | No | No | No |
| `game/scripts/components/status_effect.gd` | M1/M2 | Medium | Planned | No | No | No | No |
| `game/scripts/effects/buffs/berserk_buff.gd` | M2 | Medium | Planned | No | No | No | No |
| `game/scripts/effects/buffs/fury_buff.gd` | M2 | Medium | Planned | No | No | No | No |
| `game/scripts/effects/buffs/iron_skin_buff.gd` | M2 | Medium | Planned | No | No | No | No |
| `game/scripts/effects/buffs/rage_buff.gd` | M2 | Medium | Planned | No | No | No | No |
| `game/scripts/effects/buffs/regeneration_buff.gd` | M2 | Medium | Planned | No | No | No | No |
| `game/scripts/effects/buffs/shield_buff.gd` | M2 | Medium | Planned | No | No | No | No |
| `game/scripts/effects/buffs/skill_tree_passive_effect.gd` | M2 | Medium | Planned | No | No | No | No |
| `game/scripts/effects/buffs/swiftness_buff.gd` | M2 | Medium | Planned | No | No | No | No |
| `game/scripts/effects/buffs/vampire_buff.gd` | M2 | Medium | Planned | No | No | No | No |
| `game/scripts/effects/damage_number.gd` | M1/M8 | Low | Planned | No | No | No | No |
| `game/scripts/effects/debuffs/bleed_debuff.gd` | M2 | Medium | Planned | No | No | No | No |
| `game/scripts/effects/debuffs/blind_debuff.gd` | M2 | Medium | Planned | No | No | No | No |
| `game/scripts/effects/debuffs/curse_debuff.gd` | M2 | Medium | Planned | No | No | No | No |
| `game/scripts/effects/debuffs/poison_debuff.gd` | M2 | Medium | Planned | No | No | No | No |
| `game/scripts/effects/debuffs/slow_debuff.gd` | M2 | Medium | Planned | No | No | No | No |
| `game/scripts/effects/debuffs/stun_debuff.gd` | M2 | Medium | Planned | No | No | No | No |
| `game/scripts/effects/debuffs/vulnerability_debuff.gd` | M2 | Medium | Planned | No | No | No | No |
| `game/scripts/effects/debuffs/weakness_debuff.gd` | M2 | Medium | Planned | No | No | No | No |
| `game/scripts/entities/enemies/boss_behavior_tree/void_warden/bt_action_boss_chase.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/boss_behavior_tree/void_warden/bt_action_dark_chains.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/boss_behavior_tree/void_warden/bt_action_shadow_strike.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/boss_behavior_tree/void_warden/bt_action_soul_drain.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/boss_behavior_tree/void_warden/bt_action_void_pulse.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/boss_behavior_tree/void_warden/bt_boss_base.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/boss_behavior_tree/void_warden/bt_condition_phase.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/boss_behavior_tree/void_warden/bt_condition_skill_ready.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/boss_behavior_tree/void_warden/void_warden.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/mob_behavior_tree/archer/archer.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/mob_behavior_tree/archer/bt_action_kite.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/mob_behavior_tree/archer/bt_action_ranged_attack.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/mob_behavior_tree/archer/bt_condition_can_attack.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/mob_behavior_tree/lancer/bt_action_teleport_behind.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/mob_behavior_tree/lancer/bt_condition_can_blink.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/mob_behavior_tree/lancer/plagued_lancer.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/mob_behavior_tree/main/bt_action_chase.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/mob_behavior_tree/main/bt_action_detect_player.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/mob_behavior_tree/main/bt_action_idle.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/mob_behavior_tree/main/bt_action_melee_attack.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/mob_behavior_tree/main/bt_condition_has_los.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/mob_behavior_tree/main/bt_condition_has_player.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/mob_behavior_tree/main/bt_condition_in_attack_range.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/mob_behavior_tree/main/bt_enemy.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/enemies/mob_behavior_tree/slime/blue_slime.gd` | M7 | High | Planned | No | No | No | No |
| `game/scripts/entities/items/coin.gd` | M2/M5 | Medium | Planned | No | No | No | No |
| `game/scripts/entities/player/player.gd` | M5 | Critical | Planned | No | No | No | No |
| `game/scripts/entities/player/player_combat_controller.gd` | M5 | High | Planned | No | No | No | No |
| `game/scripts/entities/player/player_stats_controller.gd` | M5 | High | Planned | No | No | No | No |
| `game/scripts/entities/player/player_visual_controller.gd` | M5 | Medium | Planned | No | No | No | No |
| `game/scripts/entities/player/sword.gd` | M5 | Medium | Planned | No | No | No | No |
| `game/scripts/entities/player/sword_slash.gd` | M5 | Medium | Planned | No | No | No | No |
| `game/scripts/entities/projectiles/arrow.gd` | M5 | Medium | Planned | No | No | No | No |
| `game/scripts/globals/admin_manager.gd` | M8 | High | Planned | No | No | No | No |
| `game/scripts/globals/class_manager.gd` | M2 | High | Planned | No | No | No | No |
| `game/scripts/globals/cloud_save_manager.gd` | M3 | Critical | Planned | No | No | No | No |
| `game/scripts/globals/coin_manager.gd` | M2/M3 | High | Planned | No | No | No | No |
| `game/scripts/globals/damage_number_manager.gd` | M1/M8 | Low | Planned | No | No | No | No |
| `game/scripts/globals/level_system.gd` | M2 | High | Planned | No | No | No | No |
| `game/scripts/globals/multiplayer_manager.gd` | M3/M4 | Critical | Planned | No | No | No | No |
| `game/scripts/globals/multiplayer_utils.gd` | M4 | Critical | Planned | No | No | No | No |
| `game/scripts/globals/network_messaging.gd` | M4 | Critical | Planned | No | No | No | No |
| `game/scripts/globals/player_skill_manager.gd` | M2 | High | Planned | No | No | No | No |
| `game/scripts/globals/shop_manager.gd` | M2 | High | Planned | No | No | No | No |
| `game/scripts/globals/skill_registry.gd` | M2 | High | Planned | No | No | No | No |
| `game/scripts/globals/skill_tree_manager.gd` | M2 | Critical | Planned | No | No | No | No |
| `game/scripts/globals/skill_tree_runtime_data.gd` | M2 | High | Planned | No | No | No | No |
| `game/scripts/globals/slime_palette_registry.gd` | M2/M8 | Medium | Planned | No | No | No | No |
| `game/scripts/globals/solo_run_save_manager.gd` | M3 | Critical | Planned | No | No | No | No |
| `game/scripts/globals/status_effect_manager.gd` | M2 | High | Planned | No | No | No | No |
| `game/scripts/levels/forest_arena_environment.gd` | M9 | High | Planned | No | No | No | No |
| `game/scripts/resources/classes/controller/chronomancer_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/controller/controller_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/controller/hexbinder_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/controller/stormcaller_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/controller/warden_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/dps/assassin_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/dps/dps_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/dps/mage_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/dps/ranger_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/dps/samurai_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/hybrid/hybrid_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/hybrid/monk_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/hybrid/shadow_knight_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/hybrid/spellblade_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/support/alchemist_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/support/bard_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/support/cleric_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/support/necromancer_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/support/support_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/tank/berserker_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/tank/guardian_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/tank/paladin_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/classes/tank/tank_class.gd` | M2/M9 | Medium | Planned | No | No | No | No |
| `game/scripts/resources/player_class.gd` | M2/M9 | Critical | Planned | No | No | No | No |
| `game/scripts/resources/player_stats.gd` | M2/M9 | High | Planned | No | No | No | No |
| `game/scripts/resources/shop_item.gd` | M2/M9 | High | Planned | No | No | No | No |
| `game/scripts/resources/skill_definition.gd` | M2/M9 | Critical | Planned | No | No | No | No |
| `game/scripts/systems/game/debug_stats_overlay.gd` | M6/M8 | Low | Planned | No | No | No | No |
| `game/scripts/systems/game/main.gd` | M6 | Critical | Planned | No | No | No | No |
| `game/scripts/systems/game/match_state_handler.gd` | M4/M6 | Critical | Planned | No | No | No | No |
| `game/scripts/systems/game/match_state_router.gd` | M4/M6 | Critical | Planned | No | No | No | No |
| `game/scripts/systems/game/mob_scene_registry.gd` | M6 | Medium | Planned | No | No | No | No |
| `game/scripts/systems/game/mob_spawner.gd` | M6 | High | Planned | No | No | No | No |
| `game/scripts/systems/game/player_stats_broadcaster.gd` | M4 | Critical | Planned | No | No | No | No |
| `game/scripts/systems/game/round_manager.gd` | M6 | High | Planned | No | No | No | No |
| `game/scripts/ui/admin/admin_tools_panel.gd` | M8 | High | Planned | No | No | No | No |
| `game/scripts/ui/auth/auth_menu.gd` | M8 | High | Planned | No | No | No | No |
| `game/scripts/ui/auth/main_menu.gd` | M8 | High | Planned | No | No | No | No |
| `game/scripts/ui/auth/solo_main_menu.gd` | M8 | Medium | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/chat_box.gd` | M8 | High | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/death_menu.gd` | M8 | Low | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/death_overlay.gd` | M8 | High | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/dev_tools_panel.gd` | M8 | Medium | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/hud_active_skill_slot.gd` | M8 | Medium | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/hud_control_panel.gd` | M8 | Medium | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/hud_minimap.gd` | M8/M9 | High | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/hud_passive_skill_icon.gd` | M8 | Medium | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/hud_player_info_panel.gd` | M8 | Medium | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/hud_player_panel.gd` | M8 | Medium | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/hud_skill_bar.gd` | M8 | Medium | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/hud_stats_panel.gd` | M8 | High | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/hud_ui.gd` | M8 | High | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/main_ui.gd` | M8 | Low | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/pause_menu.gd` | M8 | Medium | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/save_slots_ui.gd` | M3/M8 | High | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/shop_item_card.gd` | M8 | Medium | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/shop_ui.gd` | M2/M8 | High | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/skill_tree_card.gd` | M8/M9 | High | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/skill_tree_tab_content.gd` | M8 | Medium | Planned | No | No | No | No |
| `game/scripts/ui/gameplay/skill_tree_ui.gd` | M8/M9 | Critical | Planned | No | No | No | No |
| `game/scripts/ui/loading_screen.gd` | M4/M8 | High | Planned | No | No | No | No |
| `game/scripts/ui/lobby/class_selection_main_slot.gd` | M8 | Medium | Planned | No | No | No | No |
| `game/scripts/ui/lobby/class_selection_ui.gd` | M8 | High | Planned | No | No | No | No |
| `game/scripts/ui/lobby/room_lobby.gd` | M8 | Critical | Planned | No | No | No | No |
| `game/scripts/ui/lobby/room_lobby_carousel_controller.gd` | M8 | High | Planned | No | No | No | No |
| `game/scripts/ui/lobby/room_lobby_chat_box.gd` | M8 | High | Planned | No | No | No | No |
| `game/scripts/ui/lobby/room_lobby_match_flow.gd` | M4/M8 | Critical | Planned | No | No | No | No |
| `game/scripts/ui/lobby/room_lobby_party_controller.gd` | M8 | High | Planned | No | No | No | No |
| `game/scripts/ui/lobby/room_lobby_title_controller.gd` | M8 | Medium | Planned | No | No | No | No |
| `game/scripts/ui/lobby/room_lobby_view.gd` | M8 | High | Planned | No | No | No | No |
| `game/scripts/ui/settings/settings.gd` | M3/M8 | High | Planned | No | No | No | No |

## Registry Maintenance Rules

For each row that moves to `In progress`, add or link:

- Proposed C# path
- Contract entry ID
- Known scene/resource consumers
- Test IDs
- Activation plan
- Rollback plan
- Old-file removal condition

A migration work package is incomplete when its source files have not all reached either `GDScript removed` or `Intentionally retained` with an approved reason.
