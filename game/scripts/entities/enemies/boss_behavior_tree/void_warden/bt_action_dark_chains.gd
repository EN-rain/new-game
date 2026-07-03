extends BTAction
class_name BTActionDarkChains

const BTBossScript := preload("res://scripts/entities/enemies/boss_behavior_tree/void_warden/bt_boss_base.gd")

## Dark Chains - Root player in place (Phase 2+)

@export var duration: float = 3.0
@export var cooldown: float = 12.0
@export var min_phase: int = 2


func _tick(_p_delta: float) -> Status:
	var boss: BTBossScript = agent
	if boss == null or boss.player == null:
		return Status.FAILURE
	
	if boss.get_current_phase() < min_phase:
		return Status.FAILURE
	
	if not boss.is_skill_ready("dark_chains"):
		return Status.FAILURE
	
	# Root player
	if boss.player.has_method("apply_status_effect"):
		boss.player.apply_status_effect("rooted", duration)
	else:
		# Fallback: disable physics briefly
		var target := boss.player
		target.set_physics_process(false)
		await boss.get_tree().create_timer(duration).timeout
		if target != null and is_instance_valid(target):
			target.set_physics_process(true)
	
	boss.set_skill_cooldown("dark_chains", cooldown)
	print("[VoidWarden] Dark Chains! Duration: %.1f" % duration)
	
	return Status.SUCCESS
