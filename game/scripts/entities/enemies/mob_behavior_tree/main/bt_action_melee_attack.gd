extends BTAction
class_name BTActionMeleeAttack
## Melee attack - only deal damage through the enemy's attack animation flow.

@export var damage_var: StringName = &"contact_damage"
@export var knockback_var: StringName = &"knockback_force"

func _tick(_delta: float) -> Status:
	if agent.get("is_attacking"):
		return RUNNING

	var attack_area = agent.get_node_or_null("AttackArea")
	if attack_area == null:
		return FAILURE
	
	var can_damage = agent.get("can_damage")
	if not can_damage:
		return FAILURE
	var can_attack = agent.get("can_attack")
	if not can_attack:
		return FAILURE
	
	var bodies = attack_area.get_overlapping_bodies()
	for body in bodies:
		if agent.has_method("is_targetable_player") and agent.is_targetable_player(body) and body.has_method("apply_damage"):
			var damage: int = blackboard.get_var(damage_var, 10)
			var knockback: float = blackboard.get_var(knockback_var, 300.0)

			if agent.has_method("begin_melee_attack") and agent.begin_melee_attack(body, damage, knockback):
				return RUNNING
			return FAILURE

	var player = agent.get("player")
	if player != null and is_instance_valid(player):
		if agent.has_method("is_targetable_player") and agent.is_targetable_player(player) and player.has_method("apply_damage"):
			if agent.has_method("is_body_in_attack_range") and agent.is_body_in_attack_range(player):
				var damage: int = blackboard.get_var(damage_var, 10)
				var knockback: float = blackboard.get_var(knockback_var, 300.0)
				if agent.has_method("begin_melee_attack") and agent.begin_melee_attack(player, damage, knockback):
					return RUNNING
				return FAILURE
	
	return FAILURE
