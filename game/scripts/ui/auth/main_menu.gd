extends Control

@onready var account_label: Label = %AccountLabel
@onready var logout_button: Button = %LogoutButton
@onready var start_button: Button = %StartButton
@onready var load_button: Button = %LoadButton
@onready var host_button: Button = %HostButton
@onready var connect_button: Button = %ConnectButton
@onready var code_input: LineEdit = %CodeInput
@onready var ign_input: LineEdit = %IGNInput
@onready var status_label: Label = %StatusLabel
@onready var quit_button: Button = %QuitButton
@onready var settings_button: Button = %SettingsButton

@export_file("*.tscn") var auth_menu_scene_path: String = "res://scenes/ui/auth_menu.tscn"
@export_file("*.tscn") var settings_scene_path: String = "res://scenes/ui/settings.tscn"
@export_file("*.tscn") var main_game_scene_path: String = "res://scenes/levels/main.tscn"
@export_file("*.tscn") var room_lobby_scene_path: String = "res://scenes/ui/room_lobby.tscn"
@export_file("*.tscn") var save_slots_scene_path: String = "res://scenes/ui/save_slots_ui.tscn"
@export var show_multiplayer_controls: bool = false
@export var default_player_name_prefix: String = "Player"
@export var offline_account_name: String = "Offline"
@export var account_label_format: String = "Account: %s"
@export var default_status_color: Color = Color(0.6, 0.62, 0.75, 0.7)
@export var solo_status_text: String = "Solo mode ready."
@export var signed_in_status_text: String = "Ready."
@export var signed_in_status_color: Color = Color(0.2, 0.8, 0.55)
@export var offline_status_text: String = "Ready."
@export var offline_status_color: Color = Color(0.9, 0.7, 0.3)
@export var preparing_solo_run_text: String = "Preparing solo run..."
@export var preparing_solo_run_color: Color = Color(0.4, 0.65, 0.9)
@export var continuing_solo_run_text: String = "Loading saved round..."
@export var connecting_status_text: String = "Connecting..."
@export var host_connecting_color: Color = Color(0.7, 0.55, 0.95)
@export var guest_connecting_color: Color = Color(0.2, 0.8, 0.55)
@export var creating_room_format: String = "Creating room on %s..."
@export var joining_room_format: String = "Joining via %s..."
@export var room_code_required_text: String = "Enter a room code first"
@export var warning_status_color: Color = Color(0.9, 0.7, 0.3)
@export var create_room_failed_text: String = "Failed to create room"
@export var join_room_failed_text: String = "Failed to join room"
@export var connection_failed_format: String = "Connection failed: %s"
@export var error_status_color: Color = Color(0.9, 0.4, 0.4)

var _menu_busy: bool = false


func _ready() -> void:
	if ign_input.text.strip_edges().is_empty():
		ign_input.text = MultiplayerManager.player_ign if not MultiplayerManager.player_ign.is_empty() else default_player_name_prefix + str(randi_range(1000, 9999))

	if start_button != null:
		start_button.grab_focus.call_deferred()
	_update_auth_ui()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().quit()
		get_viewport().set_input_as_handled()

func _set_status(text: String, color: Color = default_status_color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)

func _set_menu_busy(busy: bool) -> void:
	_menu_busy = busy
	if not is_inside_tree():
		return
	_update_auth_ui()


func _update_auth_ui() -> void:
	var authenticated = MultiplayerManager.is_authenticated()
	var account_name = MultiplayerManager.player_ign
	if account_name.is_empty() and MultiplayerManager.is_authenticated():
		account_name = MultiplayerManager.username
	if account_name.is_empty():
		account_name = offline_account_name

	account_label.text = account_label_format % account_name
	logout_button.disabled = _menu_busy or not authenticated
	start_button.disabled = _menu_busy
	load_button.disabled = _menu_busy
	_apply_multiplayer_visibility(authenticated)

	if not show_multiplayer_controls:
		_set_status(solo_status_text, signed_in_status_color)
		return

	if authenticated:
		_set_status(signed_in_status_text, signed_in_status_color)
	else:
		_set_status(offline_status_text, offline_status_color)

func _apply_multiplayer_visibility(authenticated: bool) -> void:
	var account_row := account_label.get_parent() as Control
	if account_row != null:
		account_row.visible = show_multiplayer_controls
	host_button.visible = show_multiplayer_controls
	var join_row := code_input.get_parent() as Control
	if join_row != null:
		join_row.visible = show_multiplayer_controls

	logout_button.disabled = _menu_busy or not authenticated or not show_multiplayer_controls
	host_button.disabled = _menu_busy or not authenticated or not show_multiplayer_controls
	connect_button.disabled = _menu_busy or not authenticated or not show_multiplayer_controls
	code_input.editable = show_multiplayer_controls

func _get_ign() -> String:
	var ign = ign_input.text.strip_edges()
	if ign.is_empty():
		ign = default_player_name_prefix + str(randi_range(1000, 9999))
	return ign

func _go_to_auth_menu() -> void:
	call_deferred("_deferred_go_to_auth_menu")

func _deferred_go_to_auth_menu() -> void:
	if not is_inside_tree():
		return
	if not auth_menu_scene_path.is_empty():
		get_tree().change_scene_to_file(auth_menu_scene_path)

func _on_logout_pressed() -> void:
	_set_menu_busy(true)
	await MultiplayerManager.logout()
	_set_menu_busy(false)
	_go_to_auth_menu()


func _on_ign_submitted(_text: String) -> void:
	MultiplayerManager.player_ign = _get_ign()
	if ign_input != null:
		ign_input.release_focus()
	if start_button != null and not start_button.disabled:
		start_button.grab_focus()


func _on_code_submitted(_text: String) -> void:
	if not show_multiplayer_controls:
		return
	if code_input != null:
		code_input.release_focus()
	if connect_button != null and not connect_button.disabled:
		connect_button.grab_focus()

func _on_start_pressed() -> void:
	_set_menu_busy(true)
	_set_status(preparing_solo_run_text, preparing_solo_run_color)
	await MultiplayerManager.disconnect_server()
	MultiplayerManager.player_ign = _get_ign()
	MultiplayerManager.player_class = null
	MultiplayerManager.player_subclass = null
	MultiplayerManager.subclass_choice_made = false
	MultiplayerManager.player_level = 1
	SoloRunSaveManager.clear_pending_continue_snapshot()
	CoinManager.reset_coins()
	LevelSystem.reset_run_state()
	if not main_game_scene_path.is_empty():
		get_tree().change_scene_to_file(main_game_scene_path)


var _save_slots_ui: Control = null


func _on_load_pressed() -> void:
	_set_menu_busy(true)
	_set_status("Connecting...", preparing_solo_run_color)
	var session_ok := true
	_set_menu_busy(false)
	if not session_ok:
		_set_status("Failed to connect", error_status_color)
		return
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
	_set_status("Loading save from slot %d..." % slot, preparing_solo_run_color)
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

func _on_host_pressed() -> void:
	if not show_multiplayer_controls:
		return
	_set_menu_busy(true)
	_set_status(connecting_status_text, host_connecting_color)
	await MultiplayerManager.disconnect_server()

	var ign = _get_ign()
	MultiplayerManager.player_ign = ign
	var connected = await MultiplayerManager.connect_to_server("host_" + str(Time.get_unix_time_from_system()))
	if connected:
		_set_status(creating_room_format % MultiplayerManager.get_server_endpoint_summary(), host_connecting_color)
		var room_id = await MultiplayerManager.create_room()
		if not room_id.is_empty():
			if not room_lobby_scene_path.is_empty():
				get_tree().change_scene_to_file(room_lobby_scene_path)
			return
		else:
			_set_status(create_room_failed_text, error_status_color)
	else:
		_set_status(connection_failed_format % MultiplayerManager.get_server_endpoint_summary(), error_status_color)
	_set_menu_busy(false)

func _on_connect_pressed() -> void:
	if not show_multiplayer_controls:
		return
	var room_code = code_input.text.strip_edges()
	if room_code.is_empty():
		_set_status(room_code_required_text, warning_status_color)
		return

	_set_menu_busy(true)
	_set_status(connecting_status_text, guest_connecting_color)
	await MultiplayerManager.disconnect_server()

	var ign = _get_ign()
	MultiplayerManager.player_ign = ign
	var connected = await MultiplayerManager.connect_to_server("guest_" + str(Time.get_unix_time_from_system()))
	if connected:
		_set_status(joining_room_format % MultiplayerManager.get_server_endpoint_summary(), guest_connecting_color)
		var joined = await MultiplayerManager.join_room(room_code)
		if joined:
			if not room_lobby_scene_path.is_empty():
				get_tree().change_scene_to_file(room_lobby_scene_path)
			return
		else:
			var detail := MultiplayerManager.get_last_room_error()
			_set_status(join_room_failed_text if detail.is_empty() else (join_room_failed_text + "\n" + detail), error_status_color)
	else:
		_set_status(connection_failed_format % MultiplayerManager.get_server_endpoint_summary(), error_status_color)
	_set_menu_busy(false)

func _on_settings_pressed() -> void:
	if settings_scene_path.is_empty():
		return
	get_tree().change_scene_to_file(settings_scene_path)

func _on_quit_pressed() -> void:
	get_tree().quit()
