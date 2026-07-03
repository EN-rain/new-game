extends CharacterBody2D

enum State { IDLE, CHASE }
var current_state = State.IDLE

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var sight_ray: RayCast2D = $SightRay
@onready var damage_timer: Timer = $DamageTimer
@onready var teleport_particles: GPUParticles2D = $TeleportParticles
@onready var blink_cooldown_timer: Timer = $BlinkCooldownTimer
@onready var vulnerability_particles: CPUParticles2D = $VulnerabilityParticles

@export var speed: float = 60.0
@export var stop_distance: float = 10.0
@export var contact_damage: int = 10
@export var damage_cooldown: float = 1.0
@export var knockback_force: float = 300.0
@export var knockback_decay: float = 500.0
@export var teleport_delay: float = 1.0
@export var teleport_distance: float = 10.0  # Reduced from 20 to get closer for attack
@export var blink_cooldown: float = 3.0  # Reduced from 15 for testing
@export var max_health: int = 100
@export var xp_value: int = 25
@export var vulnerability_duration: float = 3.0  # Duration of vulnerability after teleport
@export var idle_move_interval: float = 3.0
@export var idle_move_radius: float = 72.0
@export var idle_move_speed_multiplier: float = 0.4
@export var player_group_name: StringName = &"player"

const TELEPORT_FADE_TIME := 0.3
const INITIAL_TELEPORT_OFFSET := 20.0  # Reduced from 100 to teleport closer
@export_range(0.0, 1.0, 0.01) var melee_hit_timing: float = 0.55
const ATTACK_HIT_DELAY := 2
const LOS_CHECK_INTERVAL_SEC := 0.12
const DETECTION_SCAN_INTERVAL_SEC := 0.20
const WORLD_LAYER_MASK := 1
const PLAYER_BODY_LAYER_MASK := 2

var player: CharacterBody2D = null
var _attack_target: CharacterBody2D = null
var can_damage := true
var knockback_velocity := Vector2.ZERO
var is_taking_damage := false
var is_dying := false
var is_attacking := false
var is_teleporting := false
var has_teleported_to_player := false
var can_blink := true
var chase_frame_count := 0
var is_blinking := false
var fade_tween: Tween = null
var last_debug_state := ""
var lancer_id := 0  # Unique ID for each lancer instance
var player_in_detection_range := false
var health: HealthComponent
var _idle_move_timer: float = 0.0
var _idle_target: Vector2 = Vector2.ZERO
var _has_idle_target: bool = false
var _los_cached: bool = true
var _los_next_check_ms: int = 0
var _detect_next_scan_ms: int = 0

func _ready():
	# Assign unique ID for debugging
	lancer_id = randi() % 1000

	# Ensure the lancer never physically blocks players (especially noticeable after blink teleports).
	# Combat/detection is handled via Area2D + RayCast2D, so the body only needs to collide with world.
	collision_layer = 8
	collision_mask = WORLD_LAYER_MASK
	
	health = HealthComponent.new()
	health.max_health = max_health
	add_child(health)
	health.initialize($AnimatedSprite2D/HealthBar)
	health.died.connect(_on_health_died)
	
	animated_sprite.animation_finished.connect(_on_animation_finished)
	detection_area.body_entered.connect(_on_detection_area_entered)
	detection_area.body_exited.connect(_on_detection_area_exited)
	attack_area.body_entered.connect(_on_attack_area_entered)
	attack_area.body_exited.connect(_on_attack_area_exited)
	
	damage_timer.wait_time = damage_cooldown
	damage_timer.one_shot = true
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	
	sight_ray.enabled = true
	sight_ray.collide_with_bodies = true
	sight_ray.collide_with_areas = false
	sight_ray.collision_mask = WORLD_LAYER_MASK | PLAYER_BODY_LAYER_MASK
	detection_area.collision_mask = PLAYER_BODY_LAYER_MASK
	attack_area.collision_mask = PLAYER_BODY_LAYER_MASK
	
	blink_cooldown_timer.wait_time = blink_cooldown
	blink_cooldown_timer.one_shot = true
	blink_cooldown_timer.timeout.connect(_on_blink_cooldown_timeout)
	
	teleport_particles.emitting = false
	vulnerability_particles.emitting = false
	_reset_idle_roam()

func _physics_process(delta):
	# Multiplayer: remote player nodes may have collisions disabled; don't rely only on Area2D signals.
	# Periodically reacquire the closest targetable player within our detection radius.
	if not _is_action_locked() and (not _has_valid_player() or not player_in_detection_range):
		_acquire_player_fallback()

	if not is_dying:
		_idle_move_timer -= delta
	# Failsafe: reset stuck animation flags if animation isn't playing
	if is_taking_damage and animated_sprite.animation != "took_damage":
		is_taking_damage = false
	if is_attacking and animated_sprite.animation != "attack":
		is_attacking = false
	
	if not _is_action_locked():
		match current_state:
			State.IDLE:
				_idle_state()
			State.CHASE:
				_chase_state()
	
	velocity += knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	
	if not is_dying and not is_attacking and not is_teleporting:
		move_and_slide()

# ---------------- STATES ----------------
func _idle_state():
	if _idle_move_timer <= 0.0:
		_pick_idle_target()
	
	if _has_idle_target:
		var idle_direction := _idle_target - global_position
		if idle_direction.length() > 6.0:
			velocity = idle_direction.normalized() * speed * idle_move_speed_multiplier
			animated_sprite.play("walk")
			animated_sprite.flip_h = velocity.x < 0
		else:
			velocity = Vector2.ZERO
			animated_sprite.play("idle")
			_has_idle_target = false
	else:
		velocity = Vector2.ZERO
		animated_sprite.play("idle")
	
	# Transition back to CHASE if we have a valid player and line of sight
	# (don't require player_in_detection_range - it may have briefly gone false after a blink)
	if is_instance_valid(player) and has_line_of_sight():
		player_in_detection_range = true
		change_state(State.CHASE)

func _chase_state():
	if not _has_valid_player():
		chase_frame_count = 0
		player = null
		change_state(State.IDLE)
		return
	
	if not has_line_of_sight():
		chase_frame_count = 0
		change_state(State.IDLE)
		return
	
	chase_frame_count += 1
	
	# Only blink after chasing for at least 5 frames AND initial teleport done (prevents mini-teleport bug)
	if can_blink and not is_teleporting and not is_blinking and has_teleported_to_player and chase_frame_count > 5:
		can_blink = false
		chase_frame_count = 0
		start_blink()
		return
	
	var direction := (player.global_position - global_position).normalized()
	var distance := global_position.distance_to(player.global_position)
	
	if distance <= stop_distance:
		velocity = Vector2.ZERO
		animated_sprite.play("idle")
	else:
		animated_sprite.play("walk")
		velocity = direction * speed
		animated_sprite.flip_h = direction.x < 0

func change_state(new_state):
	if current_state == new_state:
		return
	current_state = new_state
	if new_state == State.IDLE:
		_reset_idle_roam()
	elif new_state == State.CHASE:
		_has_idle_target = false

# ---------------- DAMAGE ----------------
func take_damage(amount: int):
	if is_taking_damage or is_dying:
		return
	
	amount = _apply_incoming_damage_modifiers(amount)
	var died = health.take_damage(amount)
	
	if not died:
		# Don't interrupt attack animation
		if not is_attacking:
			is_taking_damage = true
			animated_sprite.play("took_damage")

func _on_animation_finished():
	if animated_sprite.animation == "took_damage":
		is_taking_damage = false
	elif animated_sprite.animation == "death":
		queue_free()
	elif animated_sprite.animation == "attack":
		is_attacking = false

func _on_health_died():
	die()

func die():
	if is_dying:
		return
	
	is_dying = true
	is_taking_damage = false
	is_attacking = false
	is_teleporting = false
	velocity = Vector2.ZERO
	
	set_physics_process(false)
	detection_area.monitoring = false
	attack_area.monitoring = false
	
	queue_free()

# ---------------- ATTACK ----------------
func _on_attack_area_entered(body):
	if _is_targetable_player(body) and not is_teleporting:
		_attack_target = body as CharacterBody2D
		start_attack(body)

func _on_attack_area_exited(body) -> void:
	if body == _attack_target:
		_attack_target = null

func start_attack(body: CharacterBody2D):
	if is_attacking or is_taking_damage or is_dying or is_teleporting:
		return
	
	is_attacking = true
	velocity = Vector2.ZERO
	animated_sprite.play("attack")
	
	var hit_delay := _get_attack_hit_delay()
	await get_tree().create_timer(hit_delay).timeout
	
	# Guard: lancer or player may have died during the await
	if is_dying or not is_instance_valid(body):
		is_attacking = false
		return
	if not is_attacking:
		return
	
	if can_damage and body.has_method("apply_damage"):
		body.apply_damage(contact_damage, global_position, knockback_force, "Plagued Lancer")
		can_damage = false
		damage_timer.start()

func _on_damage_timer_timeout():
	can_damage = true
	if _attack_target != null and is_instance_valid(_attack_target) and attack_area != null and attack_area.overlaps_body(_attack_target):
		start_attack(_attack_target)

# ---------------- DETECTION ----------------
func _on_detection_area_entered(body):
	if _is_targetable_player(body):
		player = body
		player_in_detection_range = true
		
		if not has_teleported_to_player:
			has_teleported_to_player = true
			initial_teleport()

func _on_detection_area_exited(body):
	if body == player:
		player_in_detection_range = false
		# Do NOT null out player here - after a blink the player may briefly
		# exit the detection area, and clearing player causes a permanent lock.
		# The chase/idle states will handle re-engagement via LOS checks.

# ---------------- TELEPORT ----------------
func initial_teleport():
	if not _has_valid_player():
		return
	
	if is_teleporting or is_blinking:
		return
	
	is_teleporting = true
	is_blinking = true  # Prevent chase state from running during initial teleport
	velocity = Vector2.ZERO
	
	teleport_particles.emitting = true
	
	await _fade_sprite_alpha(0.0, TELEPORT_FADE_TIME)
	
	# Guard after await
	if not _has_valid_player() or is_dying:
		animated_sprite.modulate.a = 1.0
		is_teleporting = false
		is_blinking = false
		return
	
	var direction_to_player = (player.global_position - global_position).normalized()
	var target_pos = player.global_position - (direction_to_player * INITIAL_TELEPORT_OFFSET)
	global_position = target_pos
	
	teleport_particles.emitting = true
	
	await _fade_sprite_alpha(1.0, TELEPORT_FADE_TIME)
	
	if is_dying:
		is_teleporting = false
		is_blinking = false
		return
	
	is_teleporting = false
	is_blinking = false
	can_blink = false
	blink_cooldown_timer.start()
	
	# Attack instantly after initial teleport if player is in melee range
	if is_instance_valid(player) and attack_area.overlaps_body(player):
		start_attack(player)
	
	# Apply vulnerability debuff to self after teleport
	_apply_vulnerability()

func start_blink():
	if not _has_valid_player() or is_teleporting or is_blinking:
		return
	
	is_blinking = true
	is_teleporting = true
	can_blink = false
	velocity = Vector2.ZERO
	attack_area.monitoring = false
	
	teleport_to_player_back()

func teleport_to_player_back():
	if not _has_valid_player():
		attack_area.monitoring = true
		is_teleporting = false
		is_blinking = false
		return
	
	teleport_particles.emitting = true
	
	await _fade_sprite_alpha(0.0, TELEPORT_FADE_TIME)
	
	# Re-validate player after await - it may have been freed during animation
	if not _has_valid_player():
		animated_sprite.modulate.a = 1.0
		attack_area.monitoring = true
		is_teleporting = false
		is_blinking = false
		blink_cooldown_timer.start()
		return
	
	var player_facing = Vector2.RIGHT
	if player.has_node("AnimatedSprite2D"):
		var player_sprite = player.get_node("AnimatedSprite2D")
		if player_sprite.flip_h:
			player_facing = Vector2.LEFT
	
	var behind_position = player.global_position - (player_facing * teleport_distance)
	global_position = behind_position
	
	teleport_particles.emitting = true
	
	await _fade_sprite_alpha(1.0, TELEPORT_FADE_TIME)
	
	# Re-validate after second await
	if not _has_valid_player():
		attack_area.monitoring = true
		is_teleporting = false
		is_blinking = false
		blink_cooldown_timer.start()  # reset can_blink so lancer doesn't get stuck
		return
	
	attack_area.monitoring = true
	is_teleporting = false
	is_blinking = false
	
	# Ensure we're in CHASE state after blink so the lancer walks toward the player
	change_state(State.CHASE)
	
	# Start cooldown immediately after blink
	blink_cooldown_timer.start()
	
	# Attack instantly after blink if player is already in melee area.
	# NOTE: Attack animation happens AFTER cooldown starts, so timer runs during attack
	if is_instance_valid(player) and attack_area.overlaps_body(player):
		start_attack(player)
	
	# Apply vulnerability debuff to self after teleport
	_apply_vulnerability()

func _apply_vulnerability():
	# Apply vulnerability to self after teleporting
	set_meta("damage_modifier", 1.3)  # 30% more damage taken
	vulnerability_particles.emitting = true
	print("[Lancer] Vulnerability applied for %.1fs" % vulnerability_duration)
	
	await get_tree().create_timer(vulnerability_duration).timeout
	
	# Remove vulnerability after duration
	if has_meta("damage_modifier"):
		remove_meta("damage_modifier")
		vulnerability_particles.emitting = false
		print("[Lancer] Vulnerability removed")

func _on_blink_cooldown_timeout():
	can_blink = true

# ---------------- LINE OF SIGHT ----------------
func has_line_of_sight() -> bool:
	if not _has_valid_player():
		return false

	var now_ms := Time.get_ticks_msec()
	if now_ms < _los_next_check_ms:
		return _los_cached
	_los_next_check_ms = now_ms + int(LOS_CHECK_INTERVAL_SEC * 1000.0)
	
	sight_ray.target_position = sight_ray.to_local(player.global_position)
	sight_ray.force_raycast_update()
	
	if sight_ray.is_colliding():
		var collider = sight_ray.get_collider()
		_los_cached = _is_targetable_player(collider)
		return _los_cached
	
	_los_cached = true
	return _los_cached

func _get_attack_hit_delay() -> float:
	var length_sec := 0.0
	if animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("attack"):
		var frame_count := animated_sprite.sprite_frames.get_frame_count("attack")
		var anim_speed := animated_sprite.sprite_frames.get_animation_speed("attack")
		if frame_count > 0 and anim_speed > 0.0:
			length_sec = float(frame_count) / anim_speed
	if length_sec <= 0.0:
		return float(ATTACK_HIT_DELAY)
	return clampf(length_sec * melee_hit_timing, 0.0, length_sec)

func _is_action_locked() -> bool:
	return is_taking_damage or is_dying or is_attacking or is_teleporting or is_blinking

func _has_valid_player() -> bool:
	return _is_targetable_player(player)


func _acquire_player_fallback() -> void:
	var now_ms := Time.get_ticks_msec()
	if now_ms < _detect_next_scan_ms:
		return
	_detect_next_scan_ms = now_ms + int(DETECTION_SCAN_INTERVAL_SEC * 1000.0)

	var radius := _get_detection_radius(detection_area)
	if radius <= 0.0:
		return

	var candidates := get_tree().get_nodes_in_group(player_group_name)
	var best: CharacterBody2D = null
	var best_dist_sq := radius * radius
	for candidate in candidates:
		var body := candidate as CharacterBody2D
		if body == null:
			continue
		if not _is_targetable_player(body):
			continue
		var dist_sq := global_position.distance_squared_to(body.global_position)
		if dist_sq <= best_dist_sq:
			best_dist_sq = dist_sq
			best = body

	if best != null:
		player = best
		player_in_detection_range = true

		# Mirror DetectionArea enter behavior when collisions are disabled in multiplayer.
		if not has_teleported_to_player:
			has_teleported_to_player = true
			initial_teleport()


func _get_detection_radius(area: Area2D) -> float:
	if area == null:
		return 0.0

	for child in area.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null or shape_node.disabled or shape_node.shape == null:
			continue
		var shape := shape_node.shape
		var scale_factor := maxf(absf(area.global_scale.x), absf(area.global_scale.y))
		if shape is CircleShape2D:
			return (shape as CircleShape2D).radius * scale_factor
		if shape is RectangleShape2D:
			var rect := shape as RectangleShape2D
			return rect.size.length() * 0.5 * scale_factor
		if shape is CapsuleShape2D:
			var cap := shape as CapsuleShape2D
			return (cap.height * 0.5 + cap.radius) * scale_factor

	return 0.0


func _is_targetable_player(body: Node) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if not body.is_in_group(player_group_name):
		return false
	if body.has_method("is_targetable"):
		return body.is_targetable()
	return true

func _fade_sprite_alpha(target_alpha: float, duration: float) -> void:
	# Kill any existing tween to prevent overlap
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.tween_property(animated_sprite, "modulate:a", target_alpha, duration)
	await fade_tween.finished
	fade_tween = null


func _reset_idle_roam() -> void:
	_idle_move_timer = randf_range(0.4, idle_move_interval)
	_has_idle_target = false


func _pick_idle_target() -> void:
	_idle_move_timer = idle_move_interval
	var random_offset := Vector2(
		randf_range(-idle_move_radius, idle_move_radius),
		randf_range(-idle_move_radius, idle_move_radius)
	)
	if random_offset.length() < 8.0:
		random_offset = Vector2.RIGHT.rotated(randf() * TAU) * 20.0
	_idle_target = global_position + random_offset
	_has_idle_target = true


func _apply_incoming_damage_modifiers(amount: int) -> int:
	if has_meta("damage_modifier"):
		amount = int(round(float(amount) * float(get_meta("damage_modifier"))))
	return maxi(1, amount)
