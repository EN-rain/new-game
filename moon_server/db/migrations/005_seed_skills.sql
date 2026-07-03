-- Moon Server Migration (005)
-- Seeds correct, code-accurate skills for all mobs and classes.
-- Data sourced directly from:
--   - Mob skills: game/scripts/entities/enemies/**/*.gd + boss_behavior_tree actions
--   - Class skills: game/resources/skills/**/*.tres (display_name + description_template)
-- Safe to re-run: uses UPDATE (mobs) and ON CONFLICT DO UPDATE (classes).

-- ── MOB SKILLS & ATTRIBUTES (sourced from GDScript code) ─────────────────────

-- Blue Slime (blue_slime.gd): contact damage, idle roaming. No special abilities.
UPDATE mob_configs SET
    category   = 'common',
    speed      = 60.0,
    attributes = '{}',
    skills     = '[
        {"name": "Contact Damage", "desc": "Deals damage on contact with a player. Has a 1-second cooldown between hits and applies knockback."}
    ]'
WHERE mob_type = 'slime';

-- Plagued Lancer (plagued_lancer.gd):
--   - @export var blink_cooldown: float = 3.0
--   - @export var teleport_distance: float = 10.0
--   - Initial teleport on player detection, then blink every 3s
--   - After blink: takes 30% more damage (vulnerability_duration = 3.0s)
UPDATE mob_configs SET
    category   = 'elite',
    speed      = 60.0,
    attributes = '{
        "blink_cooldown": 3.0,
        "teleport_distance": 10.0,
        "vulnerability_duration": 3.0,
        "idle_move_interval": 3.0
    }',
    skills     = '[
        {"name": "Blink Strike", "desc": "On detecting a player, the Lancer instantly teleports behind them. During chase, it blinks to the player every 3 seconds to deliver a melee strike."},
        {"name": "Post-Blink Vulnerability", "desc": "After each blink, the Lancer takes 30% increased damage for 3 seconds, shown by a particle effect. Time your attacks wisely."}
    ]'
WHERE mob_type = 'lancer';

-- Archer (archer.gd):
--   - @export var arrow_speed: float = 200.0
--   - @export var attack_distance: float = 150.0  (keeps range)
--   - @export var stop_distance: float = 120.0    (kites player)
--   - @export var attack_cooldown: float = 2.0
--   - Predictive shot: _predict_player_position() using velocity samples
UPDATE mob_configs SET
    category   = 'elite',
    speed      = 120.0,
    attributes = '{
        "arrow_speed": 200.0,
        "attack_distance": 150.0,
        "stop_distance": 120.0,
        "attack_cooldown": 2.0,
        "prediction_lookback": 3,
        "max_prediction_distance": 300.0
    }',
    skills     = '[
        {"name": "Predictive Shot", "desc": "Fires an arrow that leads the target, calculating the player s movement velocity over the last 3 frames to predict their future position. Harder to dodge at range."},
        {"name": "Kite Behavior", "desc": "Actively maintains distance: approaches if the player is too far, retreats if too close. Attacks on a 2-second cooldown from up to 150 units away."}
    ]'
WHERE mob_type = 'archer';

-- Void Warden (void_warden.gd + bt_action_*.gd boss actions):
--   Phase 1 (100%-60%): Shadow Strike (5s CD, 80 dmg), Void Pulse (8s CD, 40 dmg AoE 200r)
--   Phase 2 (60%-30%): + Dark Chains (12s CD, 3s root)
--   Phase 3 (<30%):    + Soul Drain  (15s CD, 60 dmg + 50% lifesteal)
--   base_health = 2000, speed: P1=35, P2=45, P3=55, enrage_time=300s
UPDATE mob_configs SET
    category   = 'boss',
    health     = 2000,
    speed      = 35.0,
    attributes = '{
        "phase_2_threshold": 0.6,
        "phase_3_threshold": 0.3,
        "enrage_time": 300.0,
        "shadow_strike_damage": 80,
        "shadow_strike_cooldown": 5.0,
        "void_pulse_damage": 40,
        "void_pulse_radius": 200.0,
        "void_pulse_cooldown": 8.0,
        "dark_chains_duration": 3.0,
        "dark_chains_cooldown": 12.0,
        "soul_drain_damage": 60,
        "soul_drain_heal_percent": 0.5,
        "soul_drain_cooldown": 15.0
    }',
    skills     = '[
        {"name": "Shadow Strike", "desc": "[Phase 1+] Teleports directly behind the player and strikes for 80 damage with 400 knockback. 5 second cooldown."},
        {"name": "Void Pulse", "desc": "[Phase 1+] Releases an AoE burst of void energy dealing 40 damage to all players within 200 units with knockback. 8 second cooldown."},
        {"name": "Dark Chains", "desc": "[Phase 2: <60% HP] Roots the player in place for 3 seconds, preventing all movement. 12 second cooldown. Unlocks when Warden enters Phase 2."},
        {"name": "Soul Drain", "desc": "[Phase 3: <30% HP] Drains life from the player for 60 damage while healing the Warden for 30 HP (50% of damage). 15 second cooldown. Speed also increases each phase."}
    ]'
WHERE mob_type = 'warden';

