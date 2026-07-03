extends Node2D

const PLAYER_SCENE := preload("res://scenes/entities/player/slime_blue.tscn")
const SLIME_SCENE := preload("res://scenes/entities/enemies/blue_slime.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud_ui.tscn")

var _player: CharacterBody2D
var _slime: CharacterBody2D
var _hud: CanvasLayer
var _death_signal_seen := false


func _ready() -> void:
	_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	_slime = SLIME_SCENE.instantiate() as CharacterBody2D
	_hud = HUD_SCENE.instantiate() as CanvasLayer

	_slime.speed = 220.0
	_slime.contact_damage = 999
	_slime.damage_cooldown = 0.1

	add_child(_player)
	add_child(_slime)
	add_child(_hud)

	_player.global_position = Vector2.ZERO
	_slime.global_position = Vector2(80, 0)

	_hud.set_player(_player)
	_player.death_sequence_finished.connect(func(_killer_name: String) -> void:
		_death_signal_seen = true
	)

	_run_test.call_deferred()


func _run_test() -> void:
	var target_seen := false
	var damage_seen := false
	var start_hp := int(_player.health.current_health)

	for i in range(360):
		await get_tree().physics_frame
		target_seen = target_seen or (_slime.get("player") == _player)
		damage_seen = damage_seen or int(_player.health.current_health) < start_hp
		if _death_signal_seen:
			break

	var death_screen := _hud.get_node_or_null("%Death") as Control
	var failures: Array[String] = []
	if not target_seen:
		failures.append("blue slime never targeted player")
	if not damage_seen:
		failures.append("blue slime never damaged player")
	if not _death_signal_seen:
		failures.append("player death_sequence_finished was not emitted")
	if death_screen == null or not death_screen.visible:
		failures.append("death overlay stayed hidden")

	if failures.is_empty():
		print("[SlimeDetectionDeathTest] PASS start_hp=%d end_hp=%d death_visible=%s" % [start_hp, int(_player.health.current_health), str(death_screen.visible)])
		get_tree().quit(0)
	else:
		push_error("[SlimeDetectionDeathTest] FAIL " + "; ".join(failures))
		print("[SlimeDetectionDeathTest] FAIL start_hp=%d end_hp=%d target_seen=%s damage_seen=%s death_signal=%s death_visible=%s" % [
			start_hp,
			int(_player.health.current_health),
			str(target_seen),
			str(damage_seen),
			str(_death_signal_seen),
			str(death_screen != null and death_screen.visible)
		])
		get_tree().quit(1)
