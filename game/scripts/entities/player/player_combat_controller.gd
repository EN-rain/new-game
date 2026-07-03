extends Node
class_name PlayerCombatController

var _player: CharacterBody2D
var _health: Node
var _death_sequence: Node
var _hit_stun_timer: Timer
var _dash_timer: Timer
var _visual_controller: PlayerVisualController


func setup(
	player: CharacterBody2D,
	health: Node,
	death_sequence: Node,
	hit_stun_timer: Timer,
	dash_timer: Timer,
	visual_controller: PlayerVisualController
) -> void:
	_player = player
	_health = health
	_death_sequence = death_sequence
	_hit_stun_timer = hit_stun_timer
	_dash_timer = dash_timer
	_visual_controller = visual_controller


func perform_basic_attack() -> void:
	var dir := (_player.get_global_mouse_position() - _player.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(_player.facing, 0)

	var slash: Node2D = _player.slash_effect_scene.instantiate() as Node2D
	if slash == null:
		return
	_player.get_tree().current_scene.add_child(slash)
	slash.global_position = _player.global_position + dir * 12
	slash.rotation = dir.angle()
	if slash.has_method("set_damage"):
		slash.call("set_damage", _player.attack_damage)
	if slash.has_method("set_slash_color"):
		slash.call("set_slash_color", _visual_controller.get_slash_effect_color())

	var main = _player.get_tree().current_scene
	if main.has_method("send_attack"):
		main.send_attack(_player.global_position, dir.angle())


func emit_attack_particles_at(world_pos: Vector2, rotation_angle: float) -> void:
	if _player.slash_effect_scene == null:
		push_error("Player slash_effect_scene is null! Cannot spawn attack effect.")
		return
	var slash: Node2D = _player.slash_effect_scene.instantiate() as Node2D
	if slash == null:
		push_error("Failed to instantiate slash_effect_scene!")
		return
	_player.get_tree().current_scene.add_child(slash)
	slash.global_position = world_pos
	slash.rotation = rotation_angle
	if slash.has_method("set_slash_color"):
		slash.call("set_slash_color", _visual_controller.get_slash_effect_color())


func perform_dash(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		dir = Vector2(_player.facing, 0)

	_player.is_dashing = true
	_player.dash_direction = dir.normalized()
	_visual_controller.on_dash_started(_player.dash_direction)
	_dash_timer.start()


func on_dash_finished() -> void:
	_player.is_dashing = false
	_visual_controller.on_dash_finished()
	# Notify reconciliation system that dash ended — start grace period
	MultiplayerUtils._dash_end_time = Time.get_ticks_usec() / 1000000.0


func apply_damage(amount: int, source_position: Vector2, force: float, attacker_name: String = "") -> void:
	if _player.is_taking_damage or _player.is_death_sequence_active:
		return

	if _player.has_meta("damage_modifier"):
		var modifier = _player.get_meta("damage_modifier")
		amount = int(amount * modifier)
		print("[Player] Damage modified by %.0f%% to %d" % [modifier * 100, amount])
	if _player.has_meta("defense_modifier"):
		var defense_modifier := maxf(0.05, float(_player.get_meta("defense_modifier")))
		amount = maxi(1, int(round(float(amount) / defense_modifier)))

	_player.last_attacker_name = attacker_name.strip_edges()
	_health.take_damage(amount)
	DamageNumbers.spawn_damage(_player.global_position + Vector2(0, -20), amount, false, true)

	_player.is_taking_damage = true
	_visual_controller.play_hit_flash()

	if _player.damage_particles:
		_player.damage_particles.emitting = true

	var dir := _player.global_position - source_position
	if dir.length_squared() <= 0.0001:
		dir = Vector2.RIGHT * _player.facing
	else:
		dir = dir.normalized()
	_player.knockback_velocity = dir * force
	_player.can_move = false
	_hit_stun_timer.start(_player.hit_stun_time)


func on_hit_stun_timeout() -> void:
	_player.can_move = true


func on_player_died() -> void:
	if _player.is_death_sequence_active:
		return
	if _player.is_local_player:
		# Check for auto-revive via revive stone
		if ShopManager.has_revive_stone():
			ShopManager.use_revive_stone()
			_player.revive_player()
			return
		var skill_manager: Node = _player._get_player_skill_manager()
		if _death_sequence != null:
			_death_sequence.start(_player, _player.last_attacker_name, skill_manager)
		else:
			_player.notify_death_sequence_finished(resolve_death_killer_name())
			_player.queue_free()
		return
	_player.queue_free()


func is_targetable() -> bool:
	return not _player.is_death_sequence_active and _health != null and int(_health.current_health) > 0


func resolve_death_killer_name() -> String:
	if not _player.last_attacker_name.is_empty():
		return _player.last_attacker_name
	return "something rude"


func on_death_sequence_finished(killer_name: String) -> void:
	_player.notify_death_sequence_finished(killer_name)
