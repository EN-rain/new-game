extends BTAction
class_name BTActionChase
## Chase the player - move towards them

@export var speed_var: StringName = &"speed"
@export var stop_distance_var: StringName = &"stop_distance"

func _tick(_delta: float) -> Status:
	if agent.get("is_attacking"):
		agent.velocity = Vector2.ZERO
		return RUNNING

	var player = agent.get("player")
	if player == null or not is_instance_valid(player):
		return FAILURE

	if _should_yield_to_blink(player):
		agent.velocity = Vector2.ZERO
		return FAILURE
	
	var speed: float = blackboard.get_var(speed_var, 60.0)
	var stop_distance: float = blackboard.get_var(stop_distance_var, 10.0)
	if agent.has_method("get_minimum_player_separation"):
		stop_distance = maxf(stop_distance, agent.get_minimum_player_separation(player))
	
	var direction: Vector2 = (player.global_position - agent.global_position).normalized()
	var distance: float = agent.global_position.distance_to(player.global_position)
	
	if distance <= stop_distance:
		agent.velocity = Vector2.ZERO
		return SUCCESS
	
	# Move towards player
	agent.velocity = direction * speed
	
	# Flip sprite based on direction
	var animated_sprite = agent.get_node_or_null("AnimatedSprite2D")
	if animated_sprite:
		animated_sprite.flip_h = direction.x < 0
		animated_sprite.play("walk")
	
	return RUNNING


func _should_yield_to_blink(player: Node2D) -> bool:
	if not ("can_yield_chase_to_blink" in agent) or not bool(agent.get("can_yield_chase_to_blink")):
		return false
	if not ("can_blink" in agent) or not bool(agent.get("can_blink")):
		return false
	if bool(agent.get("is_teleporting")):
		return false
	if "is_attacking" in agent and bool(agent.get("is_attacking")):
		return false

	var detection_area = agent.get_node_or_null("DetectionArea")
	if detection_area != null and not _is_player_in_area_or_radius(player, detection_area):
		return false

	var attack_area = agent.get_node_or_null("AttackArea")
	if attack_area != null and _is_player_in_area_or_radius(player, attack_area):
		return false

	return true


func _is_player_in_area_or_radius(player: Node2D, area: Area2D) -> bool:
	if area.overlaps_body(player):
		return true

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
	return radius > 0.0 and agent.global_position.distance_to(player.global_position) <= radius
