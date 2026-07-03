extends Node2D

const PLAYER_SCENE := preload("res://scenes/entities/player/slime_blue.tscn")
const LANCER_SCENE := preload("res://scenes/entities/enemies/plagued_lancer.tscn")

var _player: CharacterBody2D
var _lancer: CharacterBody2D
var _start_hp := 0
var _min_distance := INF
var _blink_seen := false
var _damage_seen := false
var _blink_start_count := 0
var _was_teleporting := false
var _blink_facing_failures := 0


func _ready() -> void:
	_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	_lancer = LANCER_SCENE.instantiate() as CharacterBody2D

	_lancer.speed = 180.0
	_lancer.stop_distance = 10.0
	_lancer.teleport_distance = 10.0
	_lancer.blink_cooldown = 0.4
	_lancer.attack_cooldown = 0.35
	_lancer.damage_cooldown = 0.25
	_lancer.contact_damage = 10

	add_child(_player)
	add_child(_lancer)

	_player.global_position = Vector2.ZERO
	_lancer.global_position = Vector2(120, 0)

	_start_hp = int(_player.health.current_health)
	_run_test.call_deferred()


func _physics_process(_delta: float) -> void:
	if _player == null or _lancer == null:
		return
	if not is_instance_valid(_player) or not is_instance_valid(_lancer):
		return

	var distance := _player.global_position.distance_to(_lancer.global_position)
	_min_distance = minf(_min_distance, distance)
	var is_teleporting := bool(_lancer.get("is_teleporting"))
	if is_teleporting and not _was_teleporting:
		_blink_start_count += 1
	if not is_teleporting and _was_teleporting and not _is_lancer_facing_player():
		_blink_facing_failures += 1
	_was_teleporting = is_teleporting
	_blink_seen = _blink_seen or is_teleporting or bool(_lancer.get("can_blink")) == false
	_damage_seen = int(_player.health.current_health) < _start_hp


func _run_test() -> void:
	for i in range(300):
		await get_tree().physics_frame
		if _damage_seen and i > 30:
			break

	while bool(_lancer.get("is_teleporting")) or bool(_lancer.get("is_attacking")):
		await get_tree().physics_frame

	_player.global_position = _lancer.global_position + Vector2(20, 0)
	_lancer.player = _player
	_lancer.can_attack = true
	_lancer.can_damage = true
	for i in range(3):
		await get_tree().physics_frame

	var blink_count_after_first_hit := _blink_start_count
	_lancer.can_blink = true
	var basic_attack_started_in_range := false
	for i in range(10):
		await get_tree().physics_frame
		if bool(_lancer.get("is_attacking")):
			basic_attack_started_in_range = true
			break
	var blink_count_while_in_attack_range := _blink_start_count - blink_count_after_first_hit

	_lancer.can_blink = true
	_lancer.begin_melee_attack(_player, 1, 0.0)
	var blink_count_before_forced_attack := _blink_start_count
	for i in range(20):
		await get_tree().physics_frame
	var blink_count_during_attack := _blink_start_count - blink_count_before_forced_attack

	while bool(_lancer.get("is_attacking")):
		await get_tree().physics_frame

	_player.global_position = _lancer.global_position + Vector2(120, 0)
	_lancer.player = _player
	_lancer.can_blink = false
	var cooldown_timer := _lancer.get_node_or_null("BlinkCooldownTimer") as Timer
	if cooldown_timer != null:
		cooldown_timer.wait_time = 0.2
		cooldown_timer.start()
	var blink_count_before_detection_reblink := _blink_start_count
	for i in range(90):
		await get_tree().physics_frame
		if _blink_start_count > blink_count_before_detection_reblink:
			break
	var blink_count_after_detection_cooldown := _blink_start_count - blink_count_before_detection_reblink
	for i in range(90):
		if not bool(_lancer.get("is_teleporting")):
			break
		await get_tree().physics_frame

	var hp := int(_player.health.current_health)
	var overlap_limit := 14.0
	var failures: Array[String] = []
	if _start_hp <= 0:
		failures.append("player health was not initialized")
	if not _blink_seen:
		failures.append("lancer never started blink/cooldown")
	if hp >= _start_hp:
		failures.append("lancer did not damage player")
	if _min_distance < overlap_limit:
		failures.append("lancer overlapped player too closely: %.2fpx" % _min_distance)
	if bool(_lancer.get("is_teleporting")):
		failures.append("lancer remained stuck in teleport state")
	if blink_count_while_in_attack_range > 0:
		failures.append("lancer blinked again while already in attack range")
	if not basic_attack_started_in_range:
		failures.append("lancer did not start basic attack while already in attack range")
	if blink_count_during_attack > 0:
		failures.append("lancer blinked during basic attack animation")
	if blink_count_after_detection_cooldown <= 0:
		failures.append("lancer did not blink again after cooldown while player was in detection area")
	if _blink_facing_failures > 0:
		failures.append("lancer faced away after blink %d time(s)" % _blink_facing_failures)

	if failures.is_empty():
		print("[LancerSoloTest] PASS start_hp=%d end_hp=%d min_distance=%.2f blinks=%d facing_failures=%d basic_in_range=%s in_range_reblinks=%d attack_reblinks=%d detection_reblinks=%d" % [_start_hp, hp, _min_distance, _blink_start_count, _blink_facing_failures, str(basic_attack_started_in_range), blink_count_while_in_attack_range, blink_count_during_attack, blink_count_after_detection_cooldown])
		get_tree().quit(0)
	else:
		push_error("[LancerSoloTest] FAIL " + "; ".join(failures))
		print("[LancerSoloTest] FAIL start_hp=%d end_hp=%d min_distance=%.2f blinks=%d facing_failures=%d basic_in_range=%s in_range_reblinks=%d attack_reblinks=%d detection_reblinks=%d teleporting=%s" % [_start_hp, hp, _min_distance, _blink_start_count, _blink_facing_failures, str(basic_attack_started_in_range), blink_count_while_in_attack_range, blink_count_during_attack, blink_count_after_detection_cooldown, str(_lancer.get("is_teleporting"))])
		get_tree().quit(1)


func _is_lancer_facing_player() -> bool:
	var sprite := _lancer.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return true
	var direction := _player.global_position - _lancer.global_position
	if absf(direction.x) <= 0.001:
		return true
	return sprite.flip_h == (direction.x < 0.0)
