extends BTAction
class_name BTActionTeleportBehind
## Teleport behind the player (for Lancer)

@export var teleport_distance_var: StringName = &"teleport_distance"
@export var cooldown_var: StringName = &"blink_cooldown"

const FADE_DURATION := 0.3
const META_PHASE := &"_lancer_blink_phase"
const META_ELAPSED := &"_lancer_blink_elapsed"
const META_TARGET := &"_lancer_blink_target"
const PHASE_OUT := &"fade_out"
const PHASE_IN := &"fade_in"
const PHASE_SETTLE := &"settle"

func _tick(_delta: float) -> Status:
	if agent.get("is_teleporting"):
		return _continue_teleport(_delta)

	var player = agent.get("player")
	if player == null or not is_instance_valid(player):
		return FAILURE
	
	var can_blink = agent.get("can_blink")
	if not can_blink:
		return FAILURE
	
	agent.is_teleporting = true
	agent.can_blink = false
	agent.velocity = Vector2.ZERO
	agent.set_meta(META_PHASE, PHASE_OUT)
	agent.set_meta(META_ELAPSED, 0.0)
	agent.set_meta(META_TARGET, player)

	var teleport_particles := agent.get_node_or_null("TeleportParticles") as GPUParticles2D
	if teleport_particles:
		teleport_particles.emitting = true

	var animated_sprite := agent.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite == null:
		agent.global_position = _get_position_behind_player(player)
		_face_player(player, null)
		_finish_teleport(true, null, teleport_particles)
		return SUCCESS

	_face_player(player, animated_sprite)
	animated_sprite.modulate.a = 1.0
	return RUNNING


func _continue_teleport(delta: float) -> Status:
	var animated_sprite := agent.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var teleport_particles := agent.get_node_or_null("TeleportParticles") as GPUParticles2D
	var player := agent.get_meta(META_TARGET, null) as Node2D
	if not _is_valid_teleport_target(player):
		_finish_teleport(false, animated_sprite, teleport_particles)
		return FAILURE

	var phase: StringName = agent.get_meta(META_PHASE, PHASE_OUT)
	if phase == PHASE_SETTLE:
		_finish_teleport(true, animated_sprite, teleport_particles)
		return SUCCESS

	var elapsed: float = float(agent.get_meta(META_ELAPSED, 0.0)) + delta
	var progress := clampf(elapsed / FADE_DURATION, 0.0, 1.0)

	if animated_sprite != null:
		if phase == PHASE_OUT:
			animated_sprite.modulate.a = lerpf(1.0, 0.0, progress)
		else:
			animated_sprite.modulate.a = lerpf(0.0, 1.0, progress)

	if elapsed < FADE_DURATION:
		agent.set_meta(META_ELAPSED, elapsed)
		return RUNNING

	if phase == PHASE_OUT:
		agent.global_position = _get_position_behind_player(player)
		_face_player(player, animated_sprite)
		agent.set_meta(META_PHASE, PHASE_IN)
		agent.set_meta(META_ELAPSED, 0.0)
		if teleport_particles:
			teleport_particles.emitting = true
		return RUNNING

	_face_player(player, animated_sprite)
	agent.set_meta(META_PHASE, PHASE_SETTLE)
	agent.set_meta(META_ELAPSED, 0.0)
	return RUNNING


func _is_valid_teleport_target(player: Node) -> bool:
	return is_instance_valid(agent) and player != null and is_instance_valid(player)


func _get_position_behind_player(player: Node2D) -> Vector2:
	var player_facing := Vector2.RIGHT
	if player.has_node("AnimatedSprite2D"):
		var player_sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
		if player_sprite != null and player_sprite.flip_h:
			player_facing = Vector2.LEFT

	var teleport_distance: float = blackboard.get_var(teleport_distance_var, 10.0)
	if agent.has_method("get_minimum_player_separation"):
		teleport_distance = maxf(teleport_distance, agent.get_minimum_player_separation(player))
	return player.global_position - (player_facing * teleport_distance)


func _face_player(player: Node2D, animated_sprite: AnimatedSprite2D) -> void:
	if player == null or not is_instance_valid(player):
		return
	if animated_sprite == null:
		animated_sprite = agent.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite == null:
		return

	var direction_to_player: Vector2 = player.global_position - agent.global_position
	if absf(direction_to_player.x) <= 0.001:
		return
	animated_sprite.flip_h = direction_to_player.x < 0.0


func _finish_teleport(success: bool, animated_sprite: AnimatedSprite2D, teleport_particles: GPUParticles2D) -> void:
	if is_instance_valid(animated_sprite):
		animated_sprite.modulate.a = 1.0
	if is_instance_valid(teleport_particles):
		teleport_particles.emitting = false
	if not is_instance_valid(agent):
		return

	agent.is_teleporting = false
	agent.remove_meta(META_PHASE)
	agent.remove_meta(META_ELAPSED)
	agent.remove_meta(META_TARGET)
	if not success:
		agent.can_blink = true
		return

	var cooldown_timer = agent.get_node_or_null("BlinkCooldownTimer")
	if cooldown_timer:
		cooldown_timer.start()
