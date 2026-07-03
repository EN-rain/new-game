extends BTAction
class_name BTActionShadowStrike

const BTBossScript := preload("res://scripts/entities/enemies/boss_behavior_tree/void_warden/bt_boss_base.gd")

## Shadow Strike - Teleport behind player and strike

@export var damage: int = 80
@export var cooldown: float = 5.0
@export var teleport_distance: float = 50.0
@export var knockback: float = 400.0


func _tick(_p_delta: float) -> Status:
	var boss: BTBossScript = agent
	if boss == null or boss.player == null:
		return Status.FAILURE
	
	if not boss.is_skill_ready("shadow_strike"):
		return Status.FAILURE
	
	# Teleport behind player
	var player_pos := boss.player.global_position
	var boss_to_player := (player_pos - boss.global_position).normalized()
	var teleport_pos := player_pos + boss_to_player * teleport_distance
	
	boss.global_position = teleport_pos
	
	# Deal damage
	if boss.player.has_method("apply_damage"):
		boss.player.apply_damage(damage, boss.global_position, knockback, boss.boss_display_name)
	
	boss.set_skill_cooldown("shadow_strike", cooldown)
	print("[VoidWarden] Shadow Strike!")
	
	return Status.SUCCESS
