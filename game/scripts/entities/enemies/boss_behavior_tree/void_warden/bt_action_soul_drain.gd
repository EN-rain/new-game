extends BTAction
class_name BTActionSoulDrain

const BTBossScript := preload("res://scripts/entities/enemies/boss_behavior_tree/void_warden/bt_boss_base.gd")

## Soul Drain - Damage player and heal boss (Phase 3+)

@export var damage: int = 60
@export var heal_percent: float = 0.5
@export var cooldown: float = 15.0
@export var min_phase: int = 3


func _tick(_p_delta: float) -> Status:
	var boss: BTBossScript = agent
	if boss == null or boss.player == null:
		return Status.FAILURE
	
	if boss.get_current_phase() < min_phase:
		return Status.FAILURE
	
	if not boss.is_skill_ready("soul_drain"):
		return Status.FAILURE
	
	# Damage player
	if boss.player.has_method("apply_damage"):
		boss.player.apply_damage(damage, boss.global_position, 100.0, boss.boss_display_name)
	
	# Heal boss
	var heal_amount: int = int(damage * heal_percent)
	if boss.health != null:
		boss.health.heal(heal_amount)
	
	boss.set_skill_cooldown("soul_drain", cooldown)
	print("[VoidWarden] Soul Drain! Healed: %d" % heal_amount)
	
	return Status.SUCCESS
