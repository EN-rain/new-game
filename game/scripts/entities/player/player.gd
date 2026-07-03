extends CharacterBody2D

# Player controller script

signal death_sequence_finished(killer_name: String)

@export var speed := 100.0
@export var knockback_decay := 800.0  
@export var hit_stun_time := 0.2        
@export var dash_speed := 400.0
@export var dash_duration := 0.35
@export var dash_cooldown := 3.0
@export var basic_attack_cooldown := 0.4
@export var camera_zoom_step := 0.25
@export var camera_zoom_min := 0.8
@export var camera_zoom_max := 6.0

# Attack damage is now managed by LevelSystem
var attack_damage := 25

@onready var player_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player_camera: Camera2D = $Camera2D
@onready var hit_stun_timer: Timer = $HitStunTimer
@onready var health = $Health
var mana: ManaComponent = null
@onready var death_sequence = $DeathSequence
@onready var dash_timer: Timer = $DashTimer
@onready var dash_particles: CPUParticles2D = $DashParticles
@onready var dash_trail: CPUParticles2D = $DashTrail
@onready var damage_particles: CPUParticles2D = $DamageParticles
@export var slash_effect_scene: PackedScene

var is_local_player := true  # Set to false for remote players

const FLIP_DEADZONE := 8.0
const MOVE_FLIP_DEADZONE := 0.08
const SLIME_VISUAL_SCALE := 0.85
const SLIME_COLLISION_SCALE := 0.9
var is_taking_damage := false
var last_attacker_name: String = ""
var is_death_sequence_active := false
var facing := 1
var knockback_velocity := Vector2.ZERO
var can_move := true
var is_dashing := false
var is_attacking := false
var attack_rotation := 0.0
var attack_seq := 0  # Incremented on each attack for reliable remote sync
var dash_seq := 0    # Incremented on each dash for reliable remote sync
var can_dash := true
var can_basic_attack := true
var dash_direction := Vector2.ZERO
var _remote_dash_cooldown_timer: Timer = null  # Used for remote player dash cooldown tracking
var _damage_flash_active := false
var _original_slime_shader_colors: Dictionary = {}


func _get_player_skill_manager() -> Node:
	return PlayerSkillManager

func _ready():
	# Enemy AI relies on this group for detection (Area2D overlap + is_in_group checks).
	if not is_in_group("player"):
		add_to_group("player")

	if is_local_player:
		# Local player on layer 2 (player body), mask layer 1 (world only).
		# Enemies use Area2D for detection/attacks; physical body collision with enemies causes jitter/stutter (esp. during dash).
		collision_layer = 2
		collision_mask = 1  # 1 (world)
	else:
		# Remote players: keep them on the player body layer so enemy Area2D/RayCast2D can detect/target them,
		# but disable their own collision mask so they don't drive physics responses locally.
		collision_layer = 2
		collision_mask = 0
	
	_apply_slime_size_tuning()
	_configure_dash_particles()
	_capture_original_slime_shader_colors()
	player_sprite.animation_finished.connect(_on_animation_finished)
	hit_stun_timer.timeout.connect(_on_hit_stun_timeout)
	health.died.connect(_on_player_died)
	if death_sequence != null:
		death_sequence.sequence_finished.connect(_on_death_sequence_finished)

	# HealthComponent requires explicit initialization (it does not set current_health on its own).
	# If current_health stays at 0, enemies treat the player as not targetable (and LevelSystem ratio math keeps it at 0).
	if health != null and health.has_method("initialize"):
		health.initialize(null)
	
	# Register with LevelSystem singleton
	LevelSystem.register_player(self)
	
	# Apply class modifiers if a class is selected
	_apply_class_modifiers()
	
	# Add ManaComponent dynamically
	mana = ManaComponent.new()
	mana.name = "Mana"
	add_child(mana)
	mana.mana_changed.connect(_on_mana_changed)
	_apply_mana_modifiers()
	
	# Setup dash timers
	dash_timer.wait_time = dash_duration
	dash_timer.timeout.connect(_on_dash_finished)
	if not is_local_player:
		# Remote players need their own dash cooldown timer since PlayerSkillManager only handles local
		_remote_dash_cooldown_timer = Timer.new()
		_remote_dash_cooldown_timer.one_shot = true
		_remote_dash_cooldown_timer.wait_time = dash_cooldown
		_remote_dash_cooldown_timer.timeout.connect(_on_remote_dash_cooldown_finished)
		add_child(_remote_dash_cooldown_timer)
	if is_local_player:
		var skill_manager := _get_player_skill_manager()
		if skill_manager != null:
			skill_manager.bind_player(self)


func _apply_slime_size_tuning() -> void:
	if player_sprite:
		player_sprite.scale = Vector2.ONE * SLIME_VISUAL_SCALE

	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision and collision.shape is CapsuleShape2D:
		var capsule := collision.shape as CapsuleShape2D
		capsule.radius *= SLIME_COLLISION_SCALE
		capsule.height *= SLIME_COLLISION_SCALE

func _configure_dash_particles() -> void:
	# Burst dust at dash start.
	dash_particles.position = Vector2(0, 6)
	dash_particles.z_index = -1
	dash_particles.amount = 26
	dash_particles.lifetime = 0.22
	dash_particles.one_shot = false
	dash_particles.explosiveness = 0.85
	dash_particles.randomness = 0.7
	dash_particles.spread = 30.0
	dash_particles.gravity = Vector2(0, 20)
	dash_particles.initial_velocity_min = 80.0
	dash_particles.initial_velocity_max = 160.0
	dash_particles.scale_amount_min = 0.9
	dash_particles.scale_amount_max = 1.6
	dash_particles.color = Color(1, 1, 1, 0.95)
	dash_particles.emitting = false

	# Softer white trail while dashing.
	dash_trail.position = Vector2(0, 8)
	dash_trail.z_index = -1
	dash_trail.amount = 42
	dash_trail.lifetime = 0.35
	dash_trail.one_shot = false
	dash_trail.explosiveness = 0.25
	dash_trail.randomness = 0.9
	dash_trail.spread = 55.0
	dash_trail.gravity = Vector2(0, 25)
	dash_trail.initial_velocity_min = 30.0
	dash_trail.initial_velocity_max = 85.0
	dash_trail.scale_amount_min = 0.6
	dash_trail.scale_amount_max = 1.2
	dash_trail.color = Color(1, 1, 1, 0.7)
	dash_trail.emitting = false

func _physics_process(delta):
	# Remote players are controlled by network interpolation, not physics
	if not is_local_player:
		return
	if is_death_sequence_active:
		velocity = Vector2.ZERO
		return
	
	var input_dir := Vector2.ZERO
	
	if can_move and not is_dashing:
		input_dir.x = Input.get_action_strength("right") - Input.get_action_strength("left")
		input_dir.y = Input.get_action_strength("down") - Input.get_action_strength("up")
		
		if input_dir != Vector2.ZERO:
			input_dir = input_dir.normalized()
	
	# BASE MOVEMENT
	if is_dashing:
		velocity = dash_direction * dash_speed
	else:
		velocity = input_dir * speed
	
	# APPLY KNOCKBACK
	if not is_dashing:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	
	_update_sprite_facing(input_dir if not is_dashing else dash_direction)
	move_and_slide()
	
	if is_local_player:
		var skill_manager := _get_player_skill_manager()
		if skill_manager != null:
			skill_manager.process_local_input(self, input_dir)
	
	if is_taking_damage:
		return
	
	if is_dashing:
		return
	
	if velocity.length() > 0.0:
		if player_sprite.animation != "walk":
			player_sprite.play("walk")
	else:
		if player_sprite.animation != "idle":
			player_sprite.play("idle")


func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player:
		return
	if is_death_sequence_active:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			start_basic_attack()
			return

		if player_camera == null:
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_camera_zoom(-camera_zoom_step)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_camera_zoom(camera_zoom_step)

func start_basic_attack():
	if is_death_sequence_active:
		return
	var skill_manager := _get_player_skill_manager()
	if skill_manager != null:
		skill_manager.request_basic_attack(self)


func perform_basic_attack():
	var dir := (get_global_mouse_position() - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(facing, 0)

	attack_rotation = dir.angle()
	is_attacking = true
	attack_seq += 1
	var slash := slash_effect_scene.instantiate()
	get_tree().current_scene.add_child(slash)
	slash.global_position = global_position + dir * 12
	slash.rotation = dir.angle()
	slash.set_damage(attack_damage)
	
	# Sync attack to other players
	var main = get_tree().current_scene
	if main.has_method("send_attack"):
		main.send_attack(global_position, dir.angle())


func emit_attack_particles_at(world_pos: Vector2, rotation_angle: float) -> void:
	if slash_effect_scene == null:
		push_error("Player slash_effect_scene is null! Cannot spawn attack effect.")
		return
	var slash := slash_effect_scene.instantiate()
	if slash == null:
		push_error("Failed to instantiate slash_effect_scene!")
		return
	get_tree().current_scene.add_child(slash)
	slash.global_position = world_pos
	slash.rotation = rotation_angle


func _apply_camera_zoom(delta_zoom: float) -> void:
	var next_zoom := clampf(player_camera.zoom.x + delta_zoom, camera_zoom_min, camera_zoom_max)
	player_camera.zoom = Vector2.ONE * next_zoom




func start_dash(dir):
	if is_death_sequence_active:
		return
	var skill_manager := _get_player_skill_manager()
	if skill_manager != null:
		skill_manager.request_dash(self, dir)


func perform_dash(dir):
	if dir == Vector2.ZERO:
		# Dash in facing direction if no input
		dir = Vector2(facing, 0)
	
	# Remote player cooldown check
	if not is_local_player and not can_dash:
		return
	if not is_local_player and _remote_dash_cooldown_timer:
		can_dash = false
		_remote_dash_cooldown_timer.start()
	
	is_dashing = true
	dash_seq += 1
	dash_direction = dir.normalized()
	_update_sprite_facing(dash_direction)
	if player_sprite.sprite_frames and player_sprite.sprite_frames.has_animation("dash"):
		player_sprite.play("dash")
	
	# Visual feedback - blue tint while dashing + particles
	player_sprite.modulate = Color(1.2, 1.2, 1.5)
	
	# Set particle direction based on dash direction
	var angle = dash_direction.angle()
	if dash_particles:
		dash_particles.direction = Vector2(cos(angle), sin(angle))
	if dash_trail:
		dash_trail.direction = Vector2(cos(angle), sin(angle))
	
	# Emit particles
	if dash_particles:
		dash_particles.emitting = true
	if dash_trail:
		dash_trail.emitting = true
	
	dash_timer.start()

func _on_dash_finished():
	is_dashing = false
	player_sprite.modulate = Color.WHITE
	if dash_particles:
		dash_particles.emitting = false
	if dash_trail:
		dash_trail.emitting = false

func _on_remote_dash_cooldown_finished():
	can_dash = true

func set_ign(_ign: String):
	# IGN is now displayed in the main UI, not on the player
	pass

func _on_animation_finished():
	if player_sprite.animation == "took_damage" and not _damage_flash_active:
		is_taking_damage = false

#DAMAGE & KNOCKBACK-
func apply_damage(amount: int, source_position: Vector2, force: float, attacker_name: String = ""):
	# Prevent damage spam animation
	if is_taking_damage or is_death_sequence_active:
		return
	
	# Apply vulnerability modifier if active
	if has_meta("damage_modifier"):
		var modifier = get_meta("damage_modifier")
		amount = int(amount * modifier)
		print("[Player] Damage modified by %.0f%% to %d" % [modifier * 100, amount])
	if has_meta("defense_modifier"):
		var defense_modifier := maxf(0.05, float(get_meta("defense_modifier")))
		amount = maxi(1, int(round(float(amount) / defense_modifier)))

	last_attacker_name = attacker_name.strip_edges()
	
	health.take_damage(amount)
	
	# Spawn damage number
	DamageNumbers.spawn_damage(global_position + Vector2(0, -20), amount, false, true)
	
	is_taking_damage = true
	_play_hit_flash()
	
	# Emit damage particles
	if damage_particles:
		damage_particles.emitting = true
	
	# Knockback
	var dir := global_position - source_position
	if dir.length_squared() <= 0.0001:
		dir = Vector2.RIGHT * facing
	else:
		dir = dir.normalized()
	knockback_velocity = dir * force
	
	# Enter combat state for mana regen
	if mana:
		mana.enter_combat()
	
	can_move = false
	hit_stun_timer.start(hit_stun_time)


func _play_hit_flash() -> void:
	if _damage_flash_active:
		return

	_damage_flash_active = true
	if player_sprite.sprite_frames != null and player_sprite.sprite_frames.has_animation("dash"):
		player_sprite.play("dash")
	else:
		player_sprite.play("took_damage")

	_apply_white_hit_flash()
	call_deferred("_finish_hit_flash")


func _finish_hit_flash() -> void:
	await get_tree().process_frame
	_restore_slime_shader_colors()
	_damage_flash_active = false
	is_taking_damage = false

	if is_death_sequence_active or is_dashing:
		return

	if velocity.length() > 0.0:
		player_sprite.play("walk")
	else:
		player_sprite.play("idle")

func _on_hit_stun_timeout():
	can_move = true

func _on_player_died():
	if is_death_sequence_active:
		return
	if is_local_player:
		# Check for auto-revive via revive stone
		if ShopManager.has_revive_stone():
			ShopManager.use_revive_stone()
			revive_player()
			return
		var skill_manager := _get_player_skill_manager()
		if death_sequence != null:
			death_sequence.start(self, last_attacker_name, skill_manager)
		else:
			death_sequence_finished.emit(_resolve_death_killer_name())
			queue_free()
		return
	queue_free()


func revive_player(health_percent: float = 0.5) -> void:
	if health != null:
		health.revive(health_percent)
	is_death_sequence_active = false
	is_taking_damage = false
	can_move = true
	knockback_velocity = Vector2.ZERO
	# Brief invincibility flash
	if player_sprite != null:
		player_sprite.modulate = Color(1.0, 1.0, 1.0, 0.5)
		var tween := create_tween()
		tween.tween_property(player_sprite, "modulate", Color.WHITE, 1.5)
	DamageNumbers.spawn_damage(global_position + Vector2(0, -30), 0, false, false)
	# Notify HUD that player revived
	var hud := get_tree().root.get_node_or_null("Game/HUD")
	if hud != null and hud.has_method("on_player_revived"):
		hud.on_player_revived()


func is_targetable() -> bool:
	return not is_death_sequence_active and health != null and int(health.current_health) > 0


func _resolve_death_killer_name() -> String:
	if not last_attacker_name.is_empty():
		return last_attacker_name
	return "something rude"


func _on_death_sequence_finished(killer_name: String) -> void:
	death_sequence_finished.emit(killer_name)


func _exit_tree() -> void:
	if is_local_player:
		var skill_manager := _get_player_skill_manager()
		if skill_manager != null:
			skill_manager.unbind_player(self)


func _apply_mana_modifiers() -> void:
	if mana == null:
		return
	var main_class: PlayerClass = MultiplayerManager.player_class
	var player_subclass: PlayerClass = MultiplayerManager.player_subclass
	
	# Get level-scaled base mana from LevelSystem
	var level_stats := LevelSystem.get_current_stats(self)
	var base_mana: int = int(level_stats.get("max_mana", 0))
	var base_regen: float = float(level_stats.get("mana_regen", 0.0))
	
	var total_mana_bonus: int = 0
	var total_regen_bonus: float = 0.0
	
	if main_class != null:
		total_mana_bonus += main_class.mana_bonus
		total_regen_bonus += main_class.mana_regen_bonus
	if player_subclass != null:
		# Subclass mana at 50% (same as other passive bonuses)
		total_mana_bonus += int(player_subclass.mana_bonus * 0.5)
		total_regen_bonus += player_subclass.mana_regen_bonus * 0.5
	
	var new_max := base_mana + total_mana_bonus
	if new_max > 0:
		var ratio := float(mana.current_mana) / float(maxi(mana.max_mana, 1))
		mana.set_max_mana(new_max)
		mana.current_mana = int(new_max * clampf(ratio, 0.0, 1.0))
		mana.base_mana_regen = base_regen
		mana.mana_regen_bonus = total_regen_bonus
		mana.mana_changed.emit(mana.current_mana, mana.max_mana)
		mana.set_process(true)
	else:
		# Non-mana class: disable component
		mana.set_process(false)


func _on_mana_changed(_current_mana: int, _max_mana: int) -> void:
	pass # HUD listens directly to the signal


func _update_sprite_facing(motion_dir: Vector2 = Vector2.ZERO) -> void:
	if not is_local_player:
		return
	
	var horizontal_dir: float = motion_dir.x
	if abs(horizontal_dir) <= MOVE_FLIP_DEADZONE:
		var mouse_dir := get_global_mouse_position() - global_position
		horizontal_dir = mouse_dir.x
	
	if horizontal_dir > MOVE_FLIP_DEADZONE:
		facing = 1
		player_sprite.flip_h = true
	elif horizontal_dir < -MOVE_FLIP_DEADZONE:
		facing = -1
		player_sprite.flip_h = false


func _capture_original_slime_shader_colors() -> void:
	var shader_material := player_sprite.material as ShaderMaterial
	if shader_material == null:
		return

	for parameter_name in [
		"highlight_color",
		"mid_color",
		"shadow_color",
		"outline_color",
		"iris_color",
		"eye_highlight_color"
	]:
		_original_slime_shader_colors[parameter_name] = shader_material.get_shader_parameter(parameter_name)


func _apply_white_hit_flash() -> void:
	var shader_material := player_sprite.material as ShaderMaterial
	if shader_material == null:
		player_sprite.modulate = Color.WHITE
		return

	for parameter_name in _original_slime_shader_colors.keys():
		shader_material.set_shader_parameter(parameter_name, Color.WHITE)


func _restore_slime_shader_colors() -> void:
	var shader_material := player_sprite.material as ShaderMaterial
	if shader_material == null:
		player_sprite.modulate = Color.WHITE
		return

	for parameter_name in _original_slime_shader_colors.keys():
		shader_material.set_shader_parameter(parameter_name, _original_slime_shader_colors[parameter_name])


# ---------------- CLASS MODIFIERS ----------------
func _apply_class_modifiers():
	var level_stats: Dictionary = LevelSystem.get_current_stats(self)
	reapply_class_modifiers_after_level_sync(level_stats)
	var main_class = MultiplayerManager.player_class
	if main_class != null:
		print("[Player] Applied class modifiers: %s" % main_class.display_name)


func apply_subclass_modifiers(player_subclass: PlayerClass) -> void:
	if player_subclass == null:
		return
	reapply_class_modifiers_after_level_sync(LevelSystem.get_current_stats(self))
	print("[Player] Applied subclass modifiers: %s" % player_subclass.display_name)


func reapply_class_modifiers_after_level_sync(base_stats: Dictionary) -> void:
	var main_class: PlayerClass = MultiplayerManager.player_class
	var player_subclass: PlayerClass = MultiplayerManager.player_subclass

	if main_class == null:
		return

	var speed_mult: float = main_class.modifiers_speed
	var damage_mult: float = main_class.modifiers_damage
	var hp_mult: float = main_class.modifiers_hp
	var defense_mult: float = main_class.modifiers_defense
	var atk_speed_mult: float = main_class.modifiers_attack_speed
	var crit_chance_mult: float = main_class.modifiers_crit_chance
	var crit_damage_mult: float = main_class.modifiers_crit_damage
	var lifesteal: float = 0.0
	var dodge: float = 0.0

	if player_subclass != null:
		speed_mult *= 1.0 + (player_subclass.modifiers_speed - 1.0) * 0.5
		damage_mult *= 1.0 + (player_subclass.modifiers_damage - 1.0) * 0.5
		hp_mult *= 1.0 + (player_subclass.modifiers_hp - 1.0) * 0.5
		defense_mult *= 1.0 + (player_subclass.modifiers_defense - 1.0) * 0.5
		atk_speed_mult *= 1.0 + (player_subclass.modifiers_attack_speed - 1.0) * 0.5
		crit_chance_mult *= 1.0 + (player_subclass.modifiers_crit_chance - 1.0) * 0.5
		crit_damage_mult *= 1.0 + (player_subclass.modifiers_crit_damage - 1.0) * 0.5

	var raw_speed: float = float(base_stats.get("speed", speed))
	var raw_dash_speed: float = float(base_stats.get("dash_speed", dash_speed))
	var raw_dash_cd: float = float(base_stats.get("dash_cooldown", dash_cooldown))
	var raw_attack_damage: int = int(base_stats.get("attack_damage", attack_damage))

	speed = raw_speed * speed_mult
	dash_speed = raw_dash_speed * speed_mult
	dash_cooldown = raw_dash_cd / max(atk_speed_mult, 0.01)
	attack_damage = int(raw_attack_damage * damage_mult)

	if health:
		var raw_max_health: int = int(base_stats.get("max_health", health.max_health))
		var ratio: float = float(health.current_health) / float(max(health.max_health, 1))
		health.max_health = int(raw_max_health * hp_mult)
		health.current_health = int(health.max_health * clamp(ratio, 0.0, 1.0))
		# Apply level-scaled HP regen + class bonus
		var base_hp_regen: float = float(base_stats.get("hp_regen", 0.0))
		var hp_regen_class_bonus: float = 0.0
		if main_class != null:
			hp_regen_class_bonus += main_class.hp_regen_bonus
		if player_subclass != null:
			hp_regen_class_bonus += player_subclass.hp_regen_bonus * 0.5
		health.hp_regen = base_hp_regen
		health.hp_regen_bonus = hp_regen_class_bonus

	set_meta("lifesteal", lifesteal)
	set_meta("dodge_chance", dodge)
	set_meta("crit_chance", (crit_chance_mult - 1.0) * 0.5)
	set_meta("crit_damage", crit_damage_mult)
	set_meta("defense_modifier", defense_mult)
	
	# Apply mana modifiers
	_apply_mana_modifiers()
