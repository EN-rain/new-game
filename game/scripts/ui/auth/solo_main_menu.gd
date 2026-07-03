extends Control

@onready var start_button: Button = %StartButton
@onready var load_button: Button = %LoadButton
@onready var ign_input: LineEdit = %IGNInput
@onready var status_label: Label = %StatusLabel

@export_file("*.tscn") var settings_scene_path: String = "res://scenes/ui/settings.tscn"
@export_file("*.tscn") var main_game_scene_path: String = "res://scenes/levels/main.tscn"
@export_file("*.tscn") var save_slots_scene_path: String = "res://scenes/ui/save_slots_ui.tscn"
@export var default_player_name_prefix: String = "Player"
@export var solo_status_text: String = "Solo mode ready."
@export var preparing_solo_run_text: String = "Preparing solo run..."

var _menu_busy: bool = false
var _save_slots_ui: Control = null


func _ready() -> void:
	if ign_input.text.strip_edges().is_empty():
		ign_input.text = MultiplayerManager.player_ign if not MultiplayerManager.player_ign.is_empty() else default_player_name_prefix + str(randi_range(1000, 9999))
	if start_button != null:
		start_button.grab_focus.call_deferred()
	_set_status(solo_status_text)
	_update_buttons()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().quit()
		get_viewport().set_input_as_handled()


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _set_menu_busy(busy: bool) -> void:
	_menu_busy = busy
	_update_buttons()


func _update_buttons() -> void:
	if start_button != null:
		start_button.disabled = _menu_busy
	if load_button != null:
		load_button.disabled = _menu_busy


func _get_ign() -> String:
	var ign := ign_input.text.strip_edges()
	if ign.is_empty():
		ign = default_player_name_prefix + str(randi_range(1000, 9999))
	return ign


func _prepare_solo_run() -> void:
	MultiplayerManager.player_ign = _get_ign()
	MultiplayerManager.player_class = null
	MultiplayerManager.player_subclass = null
	MultiplayerManager.subclass_choice_made = false
	MultiplayerManager.player_level = 1
	CoinManager.reset_coins()
	LevelSystem.reset_run_state()


func _on_ign_submitted(_text: String) -> void:
	MultiplayerManager.player_ign = _get_ign()
	if ign_input != null:
		ign_input.release_focus()
	if start_button != null and not start_button.disabled:
		start_button.grab_focus()


func _on_start_pressed() -> void:
	_set_menu_busy(true)
	_set_status(preparing_solo_run_text)
	await MultiplayerManager.disconnect_server()
	_prepare_solo_run()
	SoloRunSaveManager.clear_pending_continue_snapshot()
	if not main_game_scene_path.is_empty():
		get_tree().change_scene_to_file(main_game_scene_path)


func _on_load_pressed() -> void:
	_set_menu_busy(true)
	_set_status("Loading saved round...")
	_set_menu_busy(false)
	if _save_slots_ui != null and is_instance_valid(_save_slots_ui):
		_save_slots_ui.show()
		return
	if save_slots_scene_path.is_empty():
		return
	var scene: PackedScene = load(save_slots_scene_path)
	if scene == null:
		return
	_save_slots_ui = scene.instantiate()
	add_child(_save_slots_ui)
	_save_slots_ui.slot_loaded.connect(_on_slot_loaded)
	_save_slots_ui.closed.connect(_on_save_slots_closed)


func _on_slot_loaded(slot: int) -> void:
	_set_menu_busy(true)
	_set_status("Loading save from slot %d..." % slot)
	if _save_slots_ui != null and is_instance_valid(_save_slots_ui):
		_save_slots_ui.queue_free()
		_save_slots_ui = null
	MultiplayerManager.player_ign = _get_ign()
	if not main_game_scene_path.is_empty():
		get_tree().change_scene_to_file(main_game_scene_path)


func _on_save_slots_closed() -> void:
	if _save_slots_ui != null and is_instance_valid(_save_slots_ui):
		_save_slots_ui.queue_free()
		_save_slots_ui = null


func _on_settings_pressed() -> void:
	if settings_scene_path.is_empty():
		return
	get_tree().change_scene_to_file(settings_scene_path)


func _on_quit_pressed() -> void:
	get_tree().quit()
