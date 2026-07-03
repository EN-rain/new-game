extends BTCondition
class_name BTConditionInAttackRange
## Check if player is within attack range

@export var attack_distance_var: StringName = &"attack_distance"

func _tick(_delta: float) -> Status:
	var player = agent.get("player")
	if player == null or not is_instance_valid(player):
		return FAILURE

	if "arrow_scene" in agent and agent.get("arrow_scene") != null:
		return _is_within_distance(player)

	var attack_area = agent.get_node_or_null("AttackArea")
	if attack_area != null:
		if agent.has_method("is_body_in_attack_range"):
			return SUCCESS if agent.is_body_in_attack_range(player) else FAILURE
		return SUCCESS if attack_area.overlaps_body(player) else FAILURE

	return _is_within_distance(player)


func _is_within_distance(player: Node2D) -> Status:
	if player == null or not is_instance_valid(player):
		return FAILURE
	
	var attack_distance: float = blackboard.get_var(attack_distance_var, 150.0)
	var distance: float = agent.global_position.distance_to(player.global_position)

	if distance <= attack_distance:
		return SUCCESS
	return FAILURE
