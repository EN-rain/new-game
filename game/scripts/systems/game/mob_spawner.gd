extends Node
class_name MobSpawner
## MobSpawner - Handles spawning and management of mobs
## Encapsulates common and elite mob spawning logic

signal mob_spawned(mob: Node)
signal mob_died(mob: Node, score_value: int, xp_value: int)
signal active_mob_count_changed(current_alive: int, total_in_round: int)
signal round_started(round_number: int, total_mobs: int)
signal round_cleared(round_number: int)

@export var slime_mob_scene: PackedScene
@export var elite_mob_lancer_scene: PackedScene
@export var elite_mob_archer_scene: PackedScene
@export var warden_mob_scene: PackedScene
@export var boss_mob_scene: PackedScene

var MOB_NAME_MAP: Dictionary = {}

@export var initial_slime_mob_count: int = 7
@export var initial_elite_mob_count: int = 3
@export var additional_mobs_per_round: int = 10
@export_range(0.0, 1.0, 0.01) var elite_ratio_per_round: float = 0.3

@export var spawn_area_size: Vector2 = Vector2(800, 600)
@export var min_distance_from_player: float = 150.0
@export var offscreen_margin: float = 8.0
@export var offscreen_spawn_band: float = 24.0

var current_slime_mob_count := 0
var current_elite_mob_count := 0

var _parent: Node
var _player: Node
var _round_manager: RoundManager
var _current_round: int = 1
var _round_total_mobs: int = 0
var _round_active_mobs: int = 0
var _round_in_progress: bool = false
var _network_spawn_enabled: bool = false


func initialize(parent: Node, player: Node):
	_parent = parent
	_player = player
	_build_mob_name_map()


func _build_mob_name_map() -> void:
	MOB_NAME_MAP = MobSceneRegistry.build_mob_name_map(
		slime_mob_scene,
		elite_mob_lancer_scene,
		elite_mob_archer_scene,
		warden_mob_scene
	)


func set_round_manager(round_manager: RoundManager) -> void:
	_round_manager = round_manager


func set_network_spawn_enabled(enabled: bool) -> void:
	# When disabled, this spawner will not generate random spawns locally.
	# Used for non-host clients where mob spawns are replicated from the host.
	_network_spawn_enabled = enabled


func begin_network_round(round_number: int) -> void:
	# Prepare internal counters for a replicated round (mobs will be spawned via *_at()).
	_current_round = max(1, round_number)
	_round_total_mobs = get_round_total_mobs(_current_round)
	_round_active_mobs = 0
	current_slime_mob_count = 0
	current_elite_mob_count = 0
	_round_in_progress = true
	_emit_active_count()
	round_started.emit(_current_round, _round_total_mobs)


func spawn_initial_mobs() -> void:
	start_round(1)


func start_round(round_number: int) -> void:
	if _network_spawn_enabled:
		# Non-host client: round is driven by replicated spawn messages.
		begin_network_round(round_number)
		return
	_current_round = max(1, round_number)
	_round_total_mobs = get_round_total_mobs(_current_round)
	_round_active_mobs = 0
	current_slime_mob_count = 0
	current_elite_mob_count = 0
	_round_in_progress = true

	var elite_target: int = get_round_elite_count(_current_round)
	var common_target: int = maxi(_round_total_mobs - elite_target, 0)

	for i in range(common_target):
		spawn_slime_mob()
	for i in range(elite_target):
		spawn_elite_mob()

	_emit_active_count()
	round_started.emit(_current_round, _round_total_mobs)


func spawn_slime_mob() -> void:
	if _network_spawn_enabled:
		return
	if slime_mob_scene == null:
		return
	
	var mob: Node2D = slime_mob_scene.instantiate() as Node2D
	if mob == null:
		return
	mob.global_position = get_random_spawn_position()
	mob.set_meta("mob_type", "slime")
	mob.tree_exiting.connect(_on_slime_mob_died.bind(mob))
	
	_parent.add_child(mob)
	if _round_manager != null:
		_round_manager.register_mob(mob)
	mob_spawned.emit(mob)
	
	current_slime_mob_count += 1
	_round_active_mobs += 1
	_emit_active_count()


func spawn_slime_mob_at(world_pos: Vector2) -> Node2D:
	if slime_mob_scene == null:
		return null
	var mob: Node2D = slime_mob_scene.instantiate() as Node2D
	if mob == null:
		return null
	mob.global_position = world_pos
	mob.set_meta("mob_type", "slime")
	mob.tree_exiting.connect(_on_slime_mob_died.bind(mob))
	_parent.add_child(mob)
	if _round_manager != null:
		_round_manager.register_mob(mob)
	mob_spawned.emit(mob)
	current_slime_mob_count += 1
	_round_active_mobs += 1
	_emit_active_count()
	return mob


func _on_slime_mob_died(_mob: Node) -> void:
	current_slime_mob_count = max(current_slime_mob_count - 1, 0)
	_round_active_mobs = max(_round_active_mobs - 1, 0)
	if _was_mob_killed(_mob):
		mob_died.emit(_mob, 1, _get_int_property(_mob, "xp_value", 10))
	_emit_active_count()
	_check_round_clear()


func spawn_elite_mob() -> void:
	if _network_spawn_enabled:
		return
	if elite_mob_lancer_scene == null or elite_mob_archer_scene == null:
		return
	
	var elite_scene: PackedScene = elite_mob_lancer_scene if randf() < 0.5 else elite_mob_archer_scene
	var elite_type := "lancer" if elite_scene == elite_mob_lancer_scene else "archer"
	
	var elite: Node2D = elite_scene.instantiate() as Node2D
	if elite == null:
		return
	elite.global_position = get_random_spawn_position()
	elite.set_meta("mob_type", elite_type)
	elite.tree_exiting.connect(_on_elite_mob_died.bind(elite))
	
	_parent.add_child(elite)
	if _round_manager != null:
		_round_manager.register_mob(elite)
	mob_spawned.emit(elite)
	
	current_elite_mob_count += 1
	_round_active_mobs += 1
	_emit_active_count()


func spawn_elite_mob_at(elite_type: String, world_pos: Vector2) -> Node2D:
	if elite_mob_lancer_scene == null or elite_mob_archer_scene == null:
		return null
	var normalized := elite_type.to_lower().strip_edges()
	var elite_scene: PackedScene = elite_mob_lancer_scene if normalized == "lancer" else elite_mob_archer_scene
	var elite: Node2D = elite_scene.instantiate() as Node2D
	if elite == null:
		return null
	elite.global_position = world_pos
	elite.set_meta("mob_type", "lancer" if elite_scene == elite_mob_lancer_scene else "archer")
	elite.tree_exiting.connect(_on_elite_mob_died.bind(elite))
	_parent.add_child(elite)
	if _round_manager != null:
		_round_manager.register_mob(elite)
	mob_spawned.emit(elite)
	current_elite_mob_count += 1
	_round_active_mobs += 1
	_emit_active_count()
	return elite


func _on_elite_mob_died(_elite: Node) -> void:
	current_elite_mob_count = max(current_elite_mob_count - 1, 0)
	_round_active_mobs = max(_round_active_mobs - 1, 0)
	if _was_mob_killed(_elite):
		mob_died.emit(_elite, 5, _get_int_property(_elite, "xp_value", 25))
	_emit_active_count()
	_check_round_clear()


func _on_common_mob_died(_mob: Node) -> void:
	_round_active_mobs = max(_round_active_mobs - 1, 0)
	if _was_mob_killed(_mob):
		var score_value: int = _get_int_property(_mob, "score_value", 1)
		var xp: int = _get_int_property(_mob, "xp_value", 10)
		mob_died.emit(_mob, score_value, xp)
	_emit_active_count()
	_check_round_clear()


func get_round_total_mobs(round_number: int) -> int:
	return initial_slime_mob_count + initial_elite_mob_count + max(round_number - 1, 0) * additional_mobs_per_round


func get_round_added_mobs(round_number: int) -> int:
	return 0 if round_number <= 1 else additional_mobs_per_round


func get_round_elite_count(round_number: int) -> int:
	var total: int = get_round_total_mobs(round_number)
	var elite_count: int = int(round(float(total) * elite_ratio_per_round))
	return clampi(elite_count, initial_elite_mob_count, max(total - 1, 0))


func spawn_mob_by_name(mob_name: String, count: int = 1) -> int:
	if _network_spawn_enabled:
		return 0
	var key := mob_name.to_lower().strip_edges()
	var scene := MOB_NAME_MAP.get(key) as PackedScene
	if scene == null:
		return 0
	var spawned := 0
	for i in range(count):
		var mob: Node2D = scene.instantiate() as Node2D
		if mob == null:
			continue
		mob.global_position = get_random_spawn_position()
		mob.set_meta("mob_type", key)
		mob.tree_exiting.connect(_on_common_mob_died.bind(mob))
		_parent.add_child(mob)
		if _round_manager != null:
			_round_manager.register_mob(mob)
		mob_spawned.emit(mob)
		_round_active_mobs += 1
		spawned += 1
	_emit_active_count()
	return spawned


func spawn_mob_by_name_at(mob_name: String, world_pos: Vector2) -> Node2D:
	var key := mob_name.to_lower().strip_edges()
	var scene := MOB_NAME_MAP.get(key) as PackedScene
	if scene == null:
		return null
	var mob: Node2D = scene.instantiate() as Node2D
	if mob == null:
		return null
	mob.global_position = world_pos
	mob.set_meta("mob_type", key)
	mob.tree_exiting.connect(_on_common_mob_died.bind(mob))
	_parent.add_child(mob)
	if _round_manager != null:
		_round_manager.register_mob(mob)
	mob_spawned.emit(mob)
	_round_active_mobs += 1
	_emit_active_count()
	return mob


func get_alive_mob_count() -> int:
	return _round_active_mobs


func get_total_mob_count() -> int:
	return _round_total_mobs


func _emit_active_count() -> void:
	active_mob_count_changed.emit(_round_active_mobs, _round_total_mobs)


func _check_round_clear() -> void:
	if not _round_in_progress:
		return
	if _round_active_mobs > 0:
		return
	_round_in_progress = false
	round_cleared.emit(_current_round)


func _get_int_property(node: Node, property_name: String, default_value: int) -> int:
	if node == null or not is_instance_valid(node):
		return default_value
	if property_name in node:
		return int(node.get(property_name))
	return default_value


func _was_mob_killed(node: Node) -> bool:
	if node == null:
		return false
	if "is_dying" in node and bool(node.get("is_dying")):
		return true
	if "health" in node and node.get("health") is HealthComponent:
		return bool((node.get("health") as HealthComponent).is_dead)
	return false


func get_random_spawn_position() -> Vector2:
	if not is_instance_valid(_player):
		return Vector2.ZERO
	return _get_forced_offscreen_spawn_position()


func _is_outside_visible_area(world_pos: Vector2) -> bool:
	var camera := _player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return true

	var half_visible := _get_half_visible_world_size(camera)
	if half_visible == Vector2.ZERO:
		return true

	var player_pos: Vector2 = _player.global_position
	return abs(world_pos.x - player_pos.x) > half_visible.x or abs(world_pos.y - player_pos.y) > half_visible.y


func _get_forced_offscreen_spawn_position() -> Vector2:
	if not is_instance_valid(_player):
		return Vector2.ZERO

	var camera := _player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return _player.global_position + Vector2(min_distance_from_player + offscreen_margin, 0)

	var half_visible := _get_half_visible_world_size(camera)
	if half_visible == Vector2.ZERO:
		return _player.global_position + Vector2(min_distance_from_player + offscreen_margin, 0)
	var spawn_from_horizontal_edge := randf() < 0.5
	var offset := Vector2.ZERO

	if spawn_from_horizontal_edge:
		offset.x = randf_range(half_visible.x, half_visible.x + offscreen_spawn_band)
		offset.x *= -1 if randf() < 0.5 else 1
		offset.y = randf_range(-half_visible.y * 0.45, half_visible.y * 0.45)
	else:
		offset.y = randf_range(half_visible.y, half_visible.y + offscreen_spawn_band)
		offset.y *= -1 if randf() < 0.5 else 1
		offset.x = randf_range(-half_visible.x * 0.45, half_visible.x * 0.45)

	if offset.length() < min_distance_from_player:
		offset = offset.normalized() * min_distance_from_player

	return _player.global_position + offset


func _get_half_visible_world_size(camera: Camera2D) -> Vector2:
	var viewport_size := camera.get_viewport().get_visible_rect().size if camera.get_viewport() != null else Vector2.ZERO
	if viewport_size == Vector2.ZERO:
		return Vector2.ZERO

	var zoom := camera.zoom
	var safe_zoom := Vector2(
		maxf(absf(zoom.x), 0.001),
		maxf(absf(zoom.y), 0.001)
	)
	return Vector2(
		viewport_size.x * 0.5 / safe_zoom.x + offscreen_margin,
		viewport_size.y * 0.5 / safe_zoom.y + offscreen_margin
	)
