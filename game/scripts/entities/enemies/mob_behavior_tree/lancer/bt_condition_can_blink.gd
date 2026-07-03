extends BTCondition
class_name BTConditionCanBlink
## Check if lancer can blink (cooldown ready)

func _tick(_delta: float) -> Status:
	var is_teleporting = agent.get("is_teleporting")
	if is_teleporting:
		return SUCCESS

	var is_attacking = agent.get("is_attacking")
	if is_attacking:
		return FAILURE

	var player = agent.get("player")
	if player == null or not is_instance_valid(player):
		return FAILURE

	var detection_area = agent.get_node_or_null("DetectionArea")
	if detection_area != null and not _is_player_in_area_or_radius(player, detection_area):
		return FAILURE

	var attack_area = agent.get_node_or_null("AttackArea")
	if attack_area != null and _is_player_in_area_or_radius(player, attack_area):
		return FAILURE

	var can_blink = agent.get("can_blink")
	if can_blink:
		return SUCCESS
	return FAILURE


func _is_player_in_area_or_radius(player: Node2D, area: Area2D) -> bool:
	if area.overlaps_body(player):
		return true

	var radius := _get_area_radius(area)
	if radius <= 0.0:
		return false
	return agent.global_position.distance_to(player.global_position) <= radius


func _get_area_radius(area: Area2D) -> float:
	var radius := 0.0
	for child in area.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null or shape_node.disabled or shape_node.shape == null:
			continue
		var shape := shape_node.shape
		var scale_factor := maxf(absf(shape_node.global_scale.x), absf(shape_node.global_scale.y))
		if shape is CircleShape2D:
			radius = maxf(radius, (shape as CircleShape2D).radius * scale_factor)
		elif shape is RectangleShape2D:
			radius = maxf(radius, (shape as RectangleShape2D).size.length() * 0.5 * scale_factor)
		elif shape is CapsuleShape2D:
			var capsule := shape as CapsuleShape2D
			radius = maxf(radius, (capsule.height * 0.5 + capsule.radius) * scale_factor)
	return radius
