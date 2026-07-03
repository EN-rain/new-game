extends CharacterBody2D

enum State { IDLE, CHASE, ATTACKING }
var current_state = State.IDLE

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_range: Area2D = $AttackArea
@onready var sight_ray: RayCast2D = $SightRay
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer

@export var speed: float = 120.0
@export var attack_distance: float = 150.0
@export var stop_distance: float = 120.0
@export var max_health: int = 30
@export var xp_value: int = 25
@export var attack_cooldown: float = 2.0
@export var arrow_scene: PackedScene
@export var arrow_speed: float = 200.0
@export var prediction_lookback: int = 3  # Frames to look back for velocity smoothing
@export var max_prediction_distance: float = 300.0  # Cap prediction distance
@export var idle_move_interval: float = 3.0
@export var idle_move_radius: float = 96.0
@export var idle_move_speed_multiplier: float = 0.35
@export var player_group_name: StringName = &"player"

const LOS_CHECK_INTERVAL_SEC := 0.12
var _los_cached: bool = true
var _los_next_check_ms: int = 0
const WORLD_LAYER_MASK := 1
const PLAYER_BODY_LAYER_MASK := 2

var player: CharacterBody2D = null
var health: HealthComponent
var is_taking_damage := false
var is_dying := false
var is_attacking := false
var can_attack := true
var player_in_detection_range := false
var player_velocity_samples: Array[Vector2] = []
var last_player_position: Vector2 = Vector2.ZERO
var _idle_move_timer: float = 0.0
var _idle_target: Vector2 = Vector2.ZERO
var _has_idle_target: bool = false

func _ready():
	# Prevent sticky body collisions with the player; use areas for detection/attacks.
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
	attack_range.body_entered.connect(_on_attack_range_entered)
	attack_range.body_exited.connect(_on_attack_range_exited)
	
	sight_ray.enabled = true
	sight_ray.collide_with_bodies = true
	sight_ray.collide_with_areas = false
	sight_ray.collision_mask = WORLD_LAYER_MASK | PLAYER_BODY_LAYER_MASK
	detection_area.collision_mask = PLAYER_BODY_LAYER_MASK
	attack_range.collision_mask = PLAYER_BODY_LAYER_MASK
	
	attack_cooldown_timer.wait_time = attack_cooldown
	attack_cooldown_timer.one_shot = true
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timeout)
	_reset_idle_roam()

func _physics_process(_delta):
	if not is_dying:
		_idle_move_timer -= _delta
	if is_taking_damage and animated_sprite.animation != "took_damage":
		is_taking_damage = false
	
	# Track player velocity for prediction
	if player and is_instance_valid(player):
		var current_velocity = player.global_position - last_player_position
		last_player_position = player.global_position
		
		player_velocity_samples.append(current_velocity)
		if player_velocity_samples.size() > prediction_lookback:
			player_velocity_samples.pop_front()
	
	if not is_taking_damage and not is_dying and not is_attacking:
		match current_state:
			State.IDLE:
				_idle_state()
			State.CHASE:
				_chase_state()
			State.ATTACKING:
				_attacking_state()
	
	if not is_dying and not is_attacking:
		move_and_slide()

# ---------------- STATES ----------------
func _idle_state():
	if _idle_move_timer <= 0.0:
		_pick_idle_target()
	
	if _has_idle_target:
		var idle_direction := _idle_target - global_position
		if idle_direction.length() > 6.0:
			animated_sprite.play("walk")
			velocity = idle_direction.normalized() * speed * idle_move_speed_multiplier
			animated_sprite.flip_h = velocity.x < 0
		else:
			velocity = Vector2.ZERO
			animated_sprite.play("idle")
			_has_idle_target = false
	else:
		velocity = Vector2.ZERO
		animated_sprite.play("idle")
	
	if player and player_in_detection_range and has_line_of_sight():
		change_state(State.CHASE)

func _chase_state():
	if not player or not player_in_detection_range:
		change_state(State.IDLE)
		return
	
	if not has_line_of_sight():
		change_state(State.IDLE)
		return
	
	var distance := global_position.distance_to(player.global_position)
	
	# Check if in attack range and can attack
	if distance <= attack_distance and can_attack:
		change_state(State.ATTACKING)
		start_attack()
		return
	
	# Move towards player if too far, away if too close
	var direction := (player.global_position - global_position).normalized()
	
	if distance > attack_distance:
		animated_sprite.play("walk")
		velocity = direction * speed
		animated_sprite.flip_h = direction.x < 0
	elif distance < stop_distance:
		# Move away (kite player)
		animated_sprite.play("walk")
		velocity = -direction * speed
		animated_sprite.flip_h = direction.x < 0
	else:
		# Stay in position
		velocity = Vector2.ZERO
		animated_sprite.play("idle")
		# Still face the player
		animated_sprite.flip_h = direction.x < 0

func _attacking_state():
	velocity = Vector2.ZERO
	# Wait for animation to finish

func change_state(new_state):
	if current_state == new_state:
		return
	current_state = new_state
	if new_state == State.IDLE:
		_reset_idle_roam()
	elif new_state == State.CHASE or new_state == State.ATTACKING:
		_has_idle_target = false

# ---------------- ATTACK ----------------
func start_attack():
	if not can_attack or not player:
		return
	
	is_attacking = true
	can_attack = false
	velocity = Vector2.ZERO
	
	# Face the player
	var direction := (player.global_position - global_position).normalized()
	animated_sprite.flip_h = direction.x < 0
	
	animated_sprite.play("attack")

func spawn_arrow():
	if not player or not arrow_scene:
		return
	
	var arrow = arrow_scene.instantiate()
	get_tree().current_scene.add_child(arrow)
	
	# Position arrow at archer's position
	arrow.global_position = global_position
	
	# Calculate predicted target position
	var predicted_position = _predict_player_position()
	var direction = (predicted_position - global_position).normalized()
	
	arrow.direction = direction
	arrow.speed = arrow_speed
	arrow.rotation = direction.angle()

func _predict_player_position() -> Vector2:
	if player_velocity_samples.is_empty():
		return player.global_position
	
	# Calculate average velocity from samples
	var total_velocity := Vector2.ZERO
	for sample in player_velocity_samples:
		total_velocity += sample
	var average_velocity := total_velocity / player_velocity_samples.size()
	
	# Estimate time to reach target
	var distance_to_player := global_position.distance_to(player.global_position)
	var time_to_hit := distance_to_player / arrow_speed
	
	# Predict future position
	var predicted_position := player.global_position + (average_velocity * time_to_hit * 60)  # Multiply by 60 for frame rate
	
	# Cap prediction distance to prevent shooting at impossible positions
	var max_predict_distance := max_prediction_distance
	var actual_predict_distance := player.global_position.distance_to(predicted_position)
	
	if actual_predict_distance > max_predict_distance:
		var clamped_direction := (predicted_position - player.global_position).normalized()
		predicted_position = player.global_position + (clamped_direction * max_predict_distance)
	
	return predicted_position

func _on_animation_finished():
	var anim_name = animated_sprite.animation
	
	if anim_name == "attack":
		# Only spawn arrow if attack wasn't interrupted
		if is_attacking:
			spawn_arrow()
		is_attacking = false
		attack_cooldown_timer.start()
		change_state(State.CHASE)
	elif anim_name == "took_damage":
		is_taking_damage = false
		# Return to appropriate state
		if player and player_in_detection_range:
			change_state(State.CHASE)
		else:
			change_state(State.IDLE)
	elif anim_name == "death":
		queue_free()

func _on_attack_cooldown_timeout():
	can_attack = true

func _on_attack_range_entered(body):
	if _is_targetable_player(body) and can_attack and current_state == State.CHASE:
		change_state(State.ATTACKING)
		start_attack()

func _on_attack_range_exited(_body):
	pass  # Handled in chase state

# ---------------- DAMAGE ----------------
func take_damage(amount: int):
	if is_taking_damage or is_dying:
		return
	
	amount = _apply_incoming_damage_modifiers(amount)
	var was_killed = health.take_damage(amount)
	
	if was_killed:
		return
	
	# FORCE cancel attack animation and state
	if is_attacking:
		is_attacking = false
		can_attack = true
		attack_cooldown_timer.stop()
		# Stop the current animation immediately
		animated_sprite.stop()
	
	is_taking_damage = true
	velocity = Vector2.ZERO
	
	# Force play damage animation
	animated_sprite.play("took_damage")

func _on_health_died():
	die()

func die():
	is_dying = true
	is_taking_damage = false
	velocity = Vector2.ZERO
	
	set_physics_process(false)
	detection_area.monitoring = false
	attack_range.monitoring = false
	
	animated_sprite.play("death")

# ---------------- DETECTION ----------------
func _on_detection_area_entered(body):
	if _is_targetable_player(body):
		player = body
		player_in_detection_range = true

func _on_detection_area_exited(body):
	if body == player:
		player_in_detection_range = false
		player = null
		change_state(State.IDLE)

# ---------------- LINE OF SIGHT ----------------
func has_line_of_sight() -> bool:
	if not player:
		return false

	var now_ms := Time.get_ticks_msec()
	if now_ms < _los_next_check_ms:
		return _los_cached
	_los_next_check_ms = now_ms + int(LOS_CHECK_INTERVAL_SEC * 1000.0)
	
	sight_ray.target_position = sight_ray.to_local(player.global_position)
	sight_ray.force_raycast_update()
	
	if sight_ray.is_colliding():
		_los_cached = _is_targetable_player(sight_ray.get_collider())
		return _los_cached
	
	_los_cached = true
	return _los_cached


func _is_targetable_player(body: Node) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if not body.is_in_group(player_group_name):
		return false
	if body.has_method("is_targetable"):
		return body.is_targetable()
	return true


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
