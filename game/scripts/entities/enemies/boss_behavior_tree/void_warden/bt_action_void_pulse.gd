extends BTAction
class_name BTActionVoidPulse

const BTBossScript := preload("res://scripts/entities/enemies/boss_behavior_tree/void_warden/bt_boss_base.gd")

## Void Pulse - AoE damage around boss

@export var damage: int = 40
@export var cooldown: float = 8.0
@export var radius: float = 200.0
@export var knockback: float = 200.0


func _tick(_p_delta: float) -> Status:
	var boss: BTBossScript = agent
	if boss == null:
		return Status.FAILURE
	
	if not boss.is_skill_ready("void_pulse"):
		return Status.FAILURE
	
	# AoE damage
	if boss.player != null:
		var dist := boss.global_position.distance_to(boss.player.global_position)
		if dist <= radius:
			if boss.player.has_method("apply_damage"):
				boss.player.apply_damage(damage, boss.global_position, knockback, boss.boss_display_name)
	
	boss.set_skill_cooldown("void_pulse", cooldown)
	print("[VoidWarden] Void Pulse! Radius: %d" % radius)
	
	return Status.SUCCESS
