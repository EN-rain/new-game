extends CharacterBody2D
class_name BTEnemy

## Shared enemy base for LimboAI-driven mobs.

signal died(xp_reward: int)

@export var behavior_tree: BehaviorTree
@export var attacker_display_name: String = "Enemy"

@export var speed: float = 60.0
@export var stop_distance: float = 10.0
@export var contact_damage: int = 10
@export var damage_cooldown: float = 1.0
@export var knockback_force: float = 300.0
@export var knockback_decay: float = 500.0
@export var max_health: int = 50
@export var xp_value: int = 10

@export var attack_distance: float = 150.0
@export var attack_cooldown: float = 2.0
@export var arrow_scene: PackedScene
@export var arrow_speed: float = 200.0
@export var prediction_lookback: int = 3
@export var max_prediction_distance: float = 300.0

@export var teleport_distance: float = 10.0
@export var blink_cooldown: float = 3.0
@export var can_yield_chase_to_blink: bool = false
@export_range(0.0, 1.0, 0.01) var melee_hit_timing: float = 1.0
@export var player_group_name: StringName = &"player"
@export var idle_move_interval: float = 3.0
@export var idle_move_radius: float = 64.0
@export var idle_move_speed_multiplier: float = 0.45

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var sight_ray: RayCast2D = $SightRay
@onready var damage_timer: Timer = $DamageTimer
@onready var attack_cooldown_timer: Timer = get_node_or_null("AttackCooldownTimer") as Timer
@onready var blink_cooldown_timer: Timer = get_node_or_null("BlinkCooldownTimer") as Timer
@onready var teleport_particles: GPUParticles2D = get_node_or_null("TeleportParticles") as GPUParticles2D
@onready var bt_player: BTPlayer = get_node_or_null("BTPlayer") as BTPlayer
@onready var attack_animation_timer: Timer = $AttackAnimationTimer

var player: CharacterBody2D = null
var can_damage := true
var can_attack := true
var can_blink := true
var knockback_velocity := Vector2.ZERO
var is_taking_damage := false
var is_dying := false
var is_attacking := false
var is_teleporting := false
var health: HealthComponent
var player_velocity_samples: Array[Vector2] = []
var last_player_position: Vector2 = Vector2.ZERO
var _pending_attack_mode: StringName = &""
var _pending_attack_target: Node = null
var _pending_attack_damage: int = 0
var _pending_attack_knockback: float = 0.0
var _pending_arrow_direction: Vector2 = Vector2.ZERO
var _pending_arrow_speed: float = 0.0
var _pending_attack_resolved := false

const LOS_CHECK_INTERVAL_SEC := 0.12
var _los_cached: bool = true
var _los_next_check_ms: int = 0
var _attack_cooldown_fallback_timer: SceneTreeTimer = null

const WORLD_LAYER_MASK := 1
const PLAYER_BODY_LAYER_MASK := 2
const MIN_PLAYER_SEPARATION_MARGIN := 4.0
const MIN_PLAYER_SEPARATION_FLOOR := 18.0
const ATTACK_RANGE_INSET := 2.0


func _ready() -> void:
	# Enemy bodies should not physically collide with the player (that causes sticky movement/jitter).
	# Use Area2D for detection/attacks; keep body collisions for world only.
	collision_layer = 8
	collision_mask = WORLD_LAYER_MASK

	health = HealthComponent.new()
	health.max_health = max_health
	add_child(health)
	health.initialize($AnimatedSprite2D/HealthBar)
	health.died.connect(_on_health_died)

	damage_timer.wait_time = damage_cooldown
	damage_timer.one_shot = true
	damage_timer.timeout.connect(_on_damage_timer_timeout)

	if attack_cooldown_timer != null:
		attack_cooldown_timer.wait_time = attack_cooldown
		attack_cooldown_timer.one_shot = true
		attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timeout)

	if blink_cooldown_timer != null:
		blink_cooldown_timer.wait_time = blink_cooldown
		blink_cooldown_timer.one_shot = true
		blink_cooldown_timer.timeout.connect(_on_blink_cooldown_timeout)

	if sight_ray != null:
		sight_ray.enabled = true
		sight_ray.collide_with_bodies = true
		sight_ray.collide_with_areas = false
		sight_ray.collision_mask = WORLD_LAYER_MASK | PLAYER_BODY_LAYER_MASK

	# Ensure detection/attack areas are active even if scene settings got toggled off.
	if detection_area != null:
		detection_area.monitoring = true
		detection_area.monitorable = true
	if attack_area != null:
		attack_area.monitoring = true
		attack_area.monitorable = true

	detection_area.body_entered.connect(_on_detection_area_entered)
	detection_area.body_exited.connect(_on_detection_area_exited)
	attack_area.body_entered.connect(_on_attack_area_entered)
	# Ensure areas can see the player body regardless of editor collision-mask setup.
	detection_area.collision_mask = PLAYER_BODY_LAYER_MASK
	attack_area.collision_mask = PLAYER_BODY_LAYER_MASK
	animated_sprite.animation_finished.connect(_on_animation_finished)
	attack_animation_timer.timeout.connect(_on_attack_animation_timeout)

	if bt_player == null and behavior_tree != null:
		bt_player = BTPlayer.new()
		bt_player.name = "BTPlayer"
		bt_player.behavior_tree = behavior_tree
		add_child(bt_player)
		bt_player.owner = self
	if bt_player != null:
		if "behavior_tree" in bt_player and bt_player.behavior_tree == null and behavior_tree != null:
			bt_player.behavior_tree = behavior_tree
		if "scene_root_hint" in bt_player:
			bt_player.scene_root_hint = self
		if "agent" in bt_player:
			bt_player.agent = self
		bt_player.active = true
		_sync_blackboard()


func _physics_process(delta: float) -> void:
	if player != null and is_instance_valid(player):
		var current_velocity: Vector2 = player.global_position - last_player_position
		last_player_position = player.global_position
		player_velocity_samples.append(current_velocity)
		if player_velocity_samples.size() > prediction_lookback:
			player_velocity_samples.pop_front()

	velocity += knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	_apply_player_separation_guard()

	if not is_dying:
		move_and_slide()
		_update_locomotion_animation()


func take_damage(amount: int) -> void:
	if is_dying:
		return

	amount = _apply_incoming_damage_modifiers(amount)
	var was_killed := health.take_damage(amount)

	DamageNumbers.spawn_damage(global_position + Vector2(0, -20), amount, false, false)

	if not was_killed:
		# Don't interrupt attack animation
		if not is_attacking:
			_cancel_pending_attack()
			is_taking_damage = true
			velocity = Vector2.ZERO
			animated_sprite.stop()
			animated_sprite.frame = 0
			animated_sprite.play("took_damage")


func die() -> void:
	if is_dying:
		return

	is_dying = true
	_cancel_pending_attack()
	is_taking_damage = false
	is_attacking = false
	is_teleporting = false
	velocity = Vector2.ZERO

	set_physics_process(false)
	detection_area.monitoring = false
	attack_area.monitoring = false

	if bt_player != null:
		bt_player.active = false

	CoinManager.try_spawn_coin_drop(global_position, xp_value)
	died.emit(xp_value)
	if animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
	else:
		queue_free()


func is_targetable_player(body: Node) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if not body.is_in_group(player_group_name):
		return false
	if body.has_method("is_targetable"):
		return body.is_targetable()
	return true


func get_minimum_player_separation(target: Node2D, margin: float = MIN_PLAYER_SEPARATION_MARGIN) -> float:
	if target == null or not is_instance_valid(target):
		return MIN_PLAYER_SEPARATION_FLOOR
	var self_radius := _get_body_clearance_radius(self)
	var target_radius := _get_body_clearance_radius(target)
	var separation := maxf(MIN_PLAYER_SEPARATION_FLOOR, self_radius + target_radius + margin)
	var attack_radius := get_attack_area_radius()
	if attack_radius > 0.0:
		separation = minf(separation, maxf(0.0, attack_radius - ATTACK_RANGE_INSET))
	return separation


func get_attack_area_radius() -> float:
	if attack_area == null:
		return 0.0
	return _get_area_clearance_radius(attack_area)


func is_body_in_attack_range(body: Node2D) -> bool:
	if body == null or not is_instance_valid(body) or attack_area == null:
		return false
	if attack_area.overlaps_body(body):
		return true
	var attack_radius := get_attack_area_radius()
	return attack_radius > 0.0 and global_position.distance_to(body.global_position) <= attack_radius


func _apply_player_separation_guard() -> void:
	if player == null or not is_instance_valid(player) or is_dying or is_teleporting:
		return
	if not is_targetable_player(player):
		return

	var offset := global_position - player.global_position
	if offset.length_squared() <= 0.0001:
		offset = Vector2.LEFT if animated_sprite != null and animated_sprite.flip_h else Vector2.RIGHT

	var min_separation := get_minimum_player_separation(player)
	var distance := offset.length()
	if distance >= min_separation:
		return

	var away := offset.normalized()
	global_position = player.global_position + (away * min_separation)
	if velocity.dot(-away) > 0.0:
		velocity = velocity.slide(away)


func _get_body_clearance_radius(body: Node2D) -> float:
	var radius := 0.0
	for child in body.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null or shape_node.disabled or shape_node.shape == null:
			continue
		var scale_factor := maxf(absf(shape_node.global_scale.x), absf(shape_node.global_scale.y))
		var shape := shape_node.shape
		if shape is CircleShape2D:
			radius = maxf(radius, (shape as CircleShape2D).radius * scale_factor)
		elif shape is RectangleShape2D:
			radius = maxf(radius, (shape as RectangleShape2D).size.length() * 0.5 * scale_factor)
		elif shape is CapsuleShape2D:
			var capsule := shape as CapsuleShape2D
			radius = maxf(radius, maxf(capsule.radius, capsule.height * 0.5) * scale_factor)
	return radius


func _get_area_clearance_radius(area: Area2D) -> float:
	var radius := 0.0
	for child in area.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null or shape_node.disabled or shape_node.shape == null:
			continue
		var scale_factor := maxf(absf(shape_node.global_scale.x), absf(shape_node.global_scale.y))
		var shape := shape_node.shape
		if shape is CircleShape2D:
			radius = maxf(radius, (shape as CircleShape2D).radius * scale_factor)
		elif shape is RectangleShape2D:
			radius = maxf(radius, (shape as RectangleShape2D).size.length() * 0.5 * scale_factor)
		elif shape is CapsuleShape2D:
			var capsule := shape as CapsuleShape2D
			radius = maxf(radius, maxf(capsule.radius, capsule.height * 0.5) * scale_factor)
	return radius


func has_target_line_of_sight() -> bool:
	if player == null or not is_instance_valid(player) or sight_ray == null:
		return false

	var now_ms := Time.get_ticks_msec()
	if now_ms < _los_next_check_ms:
		return _los_cached
	_los_next_check_ms = now_ms + int(LOS_CHECK_INTERVAL_SEC * 1000.0)

	sight_ray.target_position = sight_ray.to_local(player.global_position)
	sight_ray.force_raycast_update()

	if sight_ray.is_colliding():
		_los_cached = is_targetable_player(sight_ray.get_collider())
		return _los_cached

	_los_cached = true
	return _los_cached


func _sync_blackboard() -> void:
	if bt_player == null:
		return
	bt_player.blackboard.set_var("speed", speed)
	bt_player.blackboard.set_var("stop_distance", stop_distance)
	bt_player.blackboard.set_var("contact_damage", contact_damage)
	bt_player.blackboard.set_var("knockback_force", knockback_force)
	bt_player.blackboard.set_var("attack_distance", attack_distance)
	bt_player.blackboard.set_var("arrow_speed", arrow_speed)
	bt_player.blackboard.set_var("teleport_distance", teleport_distance)
	bt_player.blackboard.set_var("blink_cooldown", blink_cooldown)


func _on_animation_finished() -> void:
	if animated_sprite.animation == "took_damage":
		is_taking_damage = false
	elif animated_sprite.animation == "attack":
		if attack_animation_timer != null:
			attack_animation_timer.stop()
		if _pending_attack_mode == &"melee":
			if not _pending_attack_resolved:
				_resolve_melee_attack()
			_clear_pending_attack_state()
		elif _pending_attack_mode != &"":
			_resolve_pending_attack()
	elif animated_sprite.animation == "death":
		queue_free()


func _on_health_died() -> void:
	die()


func _on_damage_timer_timeout() -> void:
	can_damage = true


func _on_attack_cooldown_timeout() -> void:
	can_attack = true
	_attack_cooldown_fallback_timer = null


func _on_blink_cooldown_timeout() -> void:
	can_blink = true


func _on_detection_area_entered(body: Node) -> void:
	if not is_targetable_player(body):
		return

	# Latch the FIRST player that enters detection range. Don't retarget until the
	# current target exits (prevents target swapping when multiple players overlap).
	if player != null and is_instance_valid(player) and is_targetable_player(player):
		return

	player = body as CharacterBody2D
	last_player_position = player.global_position
	player_velocity_samples.clear()


func _on_detection_area_exited(body: Node) -> void:
	if body == player:
		player = null
		player_velocity_samples.clear()


func _on_attack_area_entered(_body: Node) -> void:
	pass


func begin_melee_attack(target: Node, damage: int, knockback: float) -> bool:
	if is_attacking or is_taking_damage or is_dying or is_teleporting or not can_attack:
		return false

	_pending_attack_mode = &"melee"
	_pending_attack_target = target
	_pending_attack_damage = damage
	_pending_attack_knockback = knockback
	_pending_attack_resolved = false
	velocity = Vector2.ZERO
	is_attacking = true
	_start_attack_cooldown()

	if not _play_attack_animation():
		_resolve_pending_attack()
		return true

	var attack_duration := _get_animation_length("attack")
	if attack_duration <= 0.0 or attack_animation_timer == null:
		_resolve_pending_attack()
		return true

	attack_animation_timer.stop()
	var hit_delay := maxf(attack_duration * clampf(melee_hit_timing, 0.0, 1.0), 0.001)
	attack_animation_timer.start(hit_delay)

	return true


func begin_ranged_attack(direction: Vector2, projectile_speed: float) -> bool:
	if is_attacking or is_taking_damage or is_dying or is_teleporting or not can_attack:
		return false
	if arrow_scene == null:
		return false

	_pending_attack_mode = &"ranged"
	_pending_arrow_direction = direction.normalized()
	_pending_arrow_speed = projectile_speed
	_pending_attack_resolved = false
	velocity = Vector2.ZERO
	is_attacking = true
	_start_attack_cooldown()
	_face_direction(_pending_arrow_direction)

	if not _play_attack_animation():
		_resolve_pending_attack()
		return true

	var attack_duration := _get_animation_length("attack")
	if attack_duration > 0.0 and attack_animation_timer != null:
		attack_animation_timer.stop()
		attack_animation_timer.start(attack_duration + 0.02)

	return true


func _play_attack_animation() -> bool:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return false
	if not animated_sprite.sprite_frames.has_animation("attack"):
		return false

	animated_sprite.stop()
	animated_sprite.frame = 0
	animated_sprite.play("attack")
	return true


func _get_animation_length(animation_name: StringName) -> float:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return 0.0
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return 0.0

	var frame_count := animated_sprite.sprite_frames.get_frame_count(animation_name)
	var anim_speed := animated_sprite.sprite_frames.get_animation_speed(animation_name)
	if frame_count <= 0 or anim_speed <= 0.0:
		return 0.0
	return float(frame_count) / anim_speed


func _cancel_pending_attack() -> void:
	if attack_animation_timer != null:
		attack_animation_timer.stop()
	_pending_attack_mode = &""
	_pending_attack_target = null
	_pending_attack_damage = 0
	_pending_attack_knockback = 0.0
	_pending_arrow_direction = Vector2.ZERO
	_pending_arrow_speed = 0.0
	_pending_attack_resolved = false
	is_attacking = false


func _on_attack_animation_timeout() -> void:
	if not is_attacking or _pending_attack_mode == &"":
		return
	if _pending_attack_mode == &"melee":
		if not _pending_attack_resolved:
			_resolve_melee_attack()
		return
	if _pending_attack_mode != &"":
		_resolve_pending_attack()


func _resolve_pending_attack() -> void:
	match _pending_attack_mode:
		&"melee":
			_resolve_melee_attack()
		&"ranged":
			_resolve_ranged_attack()

	_pending_attack_mode = &""
	_pending_attack_target = null
	_pending_attack_damage = 0
	_pending_attack_knockback = 0.0
	_pending_arrow_direction = Vector2.ZERO
	_pending_arrow_speed = 0.0
	_pending_attack_resolved = false
	is_attacking = false


func _resolve_melee_attack() -> void:
	_pending_attack_resolved = true
	var target := _pending_attack_target
	if target != null and is_instance_valid(target) and is_targetable_player(target) and target.has_method("apply_damage"):
		if target is Node2D and not is_body_in_attack_range(target as Node2D):
			return
		target.apply_damage(_pending_attack_damage, global_position, _pending_attack_knockback, attacker_display_name)
		can_damage = false
		if damage_timer != null:
			damage_timer.start()


func _clear_pending_attack_state() -> void:
	_pending_attack_mode = &""
	_pending_attack_target = null
	_pending_attack_damage = 0
	_pending_attack_knockback = 0.0
	_pending_arrow_direction = Vector2.ZERO
	_pending_arrow_speed = 0.0
	_pending_attack_resolved = false
	is_attacking = false


func _resolve_ranged_attack() -> void:
	if arrow_scene == null:
		can_attack = true
		return

	var arrow = arrow_scene.instantiate()
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	if host == null or arrow == null:
		can_attack = true
		return

	host.add_child(arrow)
	arrow.global_position = global_position
	arrow.direction = _pending_arrow_direction
	arrow.speed = _pending_arrow_speed
	arrow.rotation = _pending_arrow_direction.angle()


func _start_attack_cooldown() -> void:
	can_attack = false
	if attack_cooldown_timer != null:
		attack_cooldown_timer.start()
		return
	if _attack_cooldown_fallback_timer != null:
		return
	if not is_inside_tree():
		can_attack = true
		return
	_attack_cooldown_fallback_timer = get_tree().create_timer(maxf(0.01, attack_cooldown))
	_attack_cooldown_fallback_timer.timeout.connect(_on_attack_cooldown_fallback_timeout)


func _on_attack_cooldown_fallback_timeout() -> void:
	_attack_cooldown_fallback_timer = null
	can_attack = true


func _apply_incoming_damage_modifiers(amount: int) -> int:
	if has_meta("damage_modifier"):
		amount = int(round(float(amount) * float(get_meta("damage_modifier"))))
	return maxi(1, amount)


func _face_direction(direction: Vector2) -> void:
	if animated_sprite == null or direction == Vector2.ZERO:
		return
	animated_sprite.flip_h = direction.x < 0.0


func _update_locomotion_animation() -> void:
	if animated_sprite == null:
		return
	if is_dying or is_taking_damage or is_attacking or is_teleporting:
		return
	if animated_sprite.sprite_frames == null:
		return

	var horizontal_motion := velocity.x
	if absf(horizontal_motion) > 0.01:
		animated_sprite.flip_h = horizontal_motion < 0.0

	if velocity.length() > 1.0:
		if animated_sprite.sprite_frames.has_animation("walk") and animated_sprite.animation != "walk":
			animated_sprite.play("walk")
	else:
		if animated_sprite.sprite_frames.has_animation("idle") and animated_sprite.animation != "idle":
			animated_sprite.play("idle")
