extends CanvasLayer

@onready var pause_panel: Panel = %PausePanel
@onready var overlay: ColorRect = %Overlay
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var save_round_button: Button = %SaveRoundButton
@onready var save_slots_button: Button = %SaveSlotsButton
@onready var menu_button: Button = %MenuButton

@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/ui/main_menu.tscn"
@export_file("*.tscn") var save_slots_scene_path: String = "res://scenes/ui/save_slots_ui.tscn"

var _save_slots_ui: Control = null


func _ready():
	show()
	pause_panel.hide()
	overlay.hide()

func _input(event):
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _toggle_pause():
	if get_tree().paused:
		_resume()
	else:
		_pause()

func _pause():
	show()
	get_tree().paused = true
	pause_panel.show()
	overlay.show()
	if save_round_button != null:
		save_round_button.text = "Save Round"

func _resume():
	get_tree().paused = false
	pause_panel.hide()
	overlay.hide()

func _on_resume_pressed():
	_resume()

func _on_restart_pressed():
	await _restart_current_run()

func _on_menu_pressed():
	get_tree().paused = false
	await MultiplayerManager.disconnect_server()
	if not main_menu_scene_path.is_empty():
		get_tree().change_scene_to_file(main_menu_scene_path)


func _on_save_round_pressed() -> void:
	if save_round_button != null:
		save_round_button.text = "Saving..."
	var tree := get_tree()
	if tree == null:
		return
	var session_ok := true
	if not session_ok:
		if save_round_button != null:
			save_round_button.text = "Save Failed"
		return
	var result = await CloudSaveManager.auto_save("solo")
	var slot: int = int(result.get("slot", 0))
	if save_round_button != null:
		save_round_button.text = "Saved (Slot %d)" % slot if result.get("success", false) else "Save Failed"


func _on_save_slots_pressed():
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
	_save_slots_ui.closed.connect(_on_save_slots_closed)


func _on_save_slots_closed() -> void:
	if _save_slots_ui != null and is_instance_valid(_save_slots_ui):
		_save_slots_ui.queue_free()
		_save_slots_ui = null


func _restart_current_run() -> void:
	var tree := get_tree()
	if tree == null:
		return

	get_tree().paused = false
	restart_button.disabled = true
	menu_button.disabled = true
	resume_button.disabled = true
	if save_round_button != null:
		save_round_button.disabled = true
	pause_panel.hide()
	overlay.hide()

	var current_scene := tree.current_scene
	var scene_path := current_scene.scene_file_path if current_scene != null else ""
	if scene_path.is_empty():
		push_error("[PauseMenu] Cannot restart run without a valid current scene path.")
		restart_button.disabled = false
		menu_button.disabled = false
		resume_button.disabled = false
		if save_round_button != null:
			save_round_button.disabled = false
		return

	var preserved_class: PlayerClass = MultiplayerManager.player_class
	await MultiplayerManager.disconnect_server()
	MultiplayerManager.player_class = preserved_class
	MultiplayerManager.player_subclass = null
	MultiplayerManager.subclass_choice_made = false
	MultiplayerManager.player_level = 1
	CoinManager.reset_coins()
	LevelSystem.reset_run_state()

	await tree.process_frame
	tree.call_deferred("change_scene_to_file", scene_path)
