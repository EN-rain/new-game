extends Node
class_name RoomLobbyMatchFlow

var _room_code_button: Button
var _leave_button: Button
var _start_button: Button
@export_file("*.tscn") var main_game_scene_path: String = "res://scenes/levels/main.tscn"
@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/ui/main_menu.tscn"
@export_file("*.tscn") var loading_screen_scene_path: String = "res://scenes/ui/loading_screen.tscn"
var _join_game_button_text: String = "Join Quest"
var _party_controller: RoomLobbyPartyController
var _title_controller: Node
var _is_transitioning: bool = false


func setup(
	room_code_button: Button,
	leave_button: Button,
	start_button: Button,
	main_game_scene_arg: String,
	main_menu_scene_arg: String,
	join_game_button_text: String,
	party_controller: RoomLobbyPartyController,
	title_controller: Node
) -> void:
	_room_code_button = room_code_button
	_leave_button = leave_button
	_start_button = start_button
	main_game_scene_path = main_game_scene_arg
	main_menu_scene_path = main_menu_scene_arg
	_join_game_button_text = join_game_button_text
	_party_controller = party_controller
	_title_controller = title_controller


func enter_lobby() -> void:
	_is_transitioning = false
	if MultiplayerManager.match_phase != "lobby":
		MultiplayerManager.match_phase = "lobby"
	if is_instance_valid(_room_code_button):
		_room_code_button.text = MultiplayerManager.room_code
		_party_controller.bootstrap_party_entries()

	if not MultiplayerManager.player_joined.is_connected(_on_player_joined_signal):
		MultiplayerManager.player_joined.connect(_on_player_joined_signal)
	if not MultiplayerManager.player_left.is_connected(_on_player_left_signal):
		MultiplayerManager.player_left.connect(_on_player_left_signal)
	if not MultiplayerManager.match_phase_changed.is_connected(_on_match_phase_changed):
		MultiplayerManager.match_phase_changed.connect(_on_match_phase_changed)
	if not MultiplayerManager.socket_opened.is_connected(_on_socket_opened):
		MultiplayerManager.socket_opened.connect(_on_socket_opened)

	if MultiplayerManager.socket:
		if not MultiplayerManager.received_match_state.is_connected(_on_match_state):
			MultiplayerManager.received_match_state.connect(_on_match_state)
		MultiplayerManager.send_match_state({
			"type": "player_info",
			"user_id": MultiplayerManager.user_id,
			"ign": MultiplayerManager.player_ign,
			"is_host": MultiplayerManager.is_host,
			"slime_variant": MultiplayerManager.player_slime_variant
		})
		if MultiplayerManager.is_host and _title_controller != null and _title_controller.has_method("broadcast_lobby_name"):
			_title_controller.broadcast_lobby_name()


func cleanup() -> void:
	if MultiplayerManager.player_joined.is_connected(_on_player_joined_signal):
		MultiplayerManager.player_joined.disconnect(_on_player_joined_signal)
	if MultiplayerManager.player_left.is_connected(_on_player_left_signal):
		MultiplayerManager.player_left.disconnect(_on_player_left_signal)
	if MultiplayerManager.match_phase_changed.is_connected(_on_match_phase_changed):
		MultiplayerManager.match_phase_changed.disconnect(_on_match_phase_changed)
	if MultiplayerManager.socket_opened.is_connected(_on_socket_opened):
		MultiplayerManager.socket_opened.disconnect(_on_socket_opened)
	if MultiplayerManager.socket and MultiplayerManager.received_match_state.is_connected(_on_match_state):
		MultiplayerManager.received_match_state.disconnect(_on_match_state)


func show_join_game_ui() -> void:
	if is_instance_valid(_room_code_button):
		_room_code_button.text = MultiplayerManager.room_code
	if is_instance_valid(_start_button):
		_start_button.text = _join_game_button_text
		_start_button.visible = true
		_start_button.disabled = false
	_party_controller.bootstrap_party_entries()
	if MultiplayerManager.socket and not MultiplayerManager.received_match_state.is_connected(_on_match_state):
		MultiplayerManager.received_match_state.connect(_on_match_state)


func on_start_pressed() -> void:
	print("[Lobby] on_start_pressed called: is_host=%s player_count=%d socket_open=%s match_id=%s" % [
		MultiplayerManager.is_host,
		_party_controller.get_player_count(),
		MultiplayerManager.is_socket_open(),
		MultiplayerManager.match_id
	])
	if not MultiplayerManager.is_host:
		push_warning("[Lobby] Start pressed but not host!")
		return
	if _party_controller.get_player_count() < 1:
		push_warning("[Lobby] Start pressed but not enough players: %d" % _party_controller.get_player_count())
		_party_controller.refresh_start_button_state()
		return
	if not _party_controller.all_players_have_class():
		push_warning("[Lobby] Start pressed but not all players have selected a class")
		return
	if MultiplayerManager.is_socket_open() and not MultiplayerManager.match_id.is_empty():
		print("[Lobby] Sending OP_START_GAME to server...")
		MultiplayerManager.send_match_state_op(MultiplayerUtils.OP_START_GAME, {"type": "start_game"})
		print("[Lobby] OP_START_GAME sent successfully")
		if is_instance_valid(_start_button):
			_start_button.disabled = true


func on_join_game_pressed() -> void:
	_transition_to_game_scene("join_game_button")


func on_back_pressed() -> void:
	MultiplayerManager.disconnect_server()
	var tree := get_tree()
	if tree != null:
		if not main_menu_scene_path.is_empty():
			tree.change_scene_to_file(main_menu_scene_path)


func on_copy_code_pressed() -> void:
	DisplayServer.clipboard_set(MultiplayerManager.room_code)


func _transition_to_game_scene(source: String) -> void:
	if _is_transitioning or not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	_is_transitioning = true
	print("[Lobby] Transitioning to loading screen from ", source, "...")
	# Go to loading screen first, which will then transition to game
	if not loading_screen_scene_path.is_empty():
		tree.change_scene_to_file(loading_screen_scene_path)


func _on_player_joined_signal(user_id: String, ign: String, is_host_flag: bool) -> void:
	_party_controller.add_player_entry(user_id, ign, "?? " if is_host_flag else "", is_host_flag)
	_party_controller.refresh_start_button_state()


func _on_player_left_signal(user_id: String) -> void:
	_party_controller.remove_player_entry(user_id)


func _on_socket_opened() -> void:
	MultiplayerManager.send_match_state({
		"type": "player_info",
		"user_id": MultiplayerManager.user_id,
		"ign": MultiplayerManager.player_ign,
		"is_host": MultiplayerManager.is_host,
		"slime_variant": MultiplayerManager.player_slime_variant
	})
	if MultiplayerManager.is_host and _title_controller != null and _title_controller.has_method("broadcast_lobby_name"):
		_title_controller.broadcast_lobby_name()


func _on_match_state(match_state) -> void:
	if match_state.op_code == MultiplayerUtils.OP_START_GAME:
		print("[Lobby] Received OP_START_GAME from server, transitioning...")
		_transition_to_game_scene("op_code_5")
		return
	if match_state.op_code == NetworkMessaging.OP_WAVE_START:
		print("[Lobby] Received OP_WAVE_START from server, transitioning...")
		_transition_to_game_scene("op_code_7")
		return

	if match_state.op_code == MultiplayerUtils.OP_STATE:
		return

	var data = JSON.parse_string(match_state.data)
	if data == null:
		return

	if data.has("players") and data.has("tick"):
		if str(data.get("phase", "lobby")) == "in_game":
			_transition_to_game_scene("snapshot_phase")
			return
		_party_controller.handle_snapshot_players(data.players)
		return

	var msg_type := str(data.get("type", ""))
	match msg_type:
		"player_info":
			_party_controller.handle_player_info_state(data)
		"request_players":
			# Send our own info
			MultiplayerManager.send_match_state({
				"type": "player_info",
				"user_id": MultiplayerManager.user_id,
				"ign": MultiplayerManager.player_ign,
				"is_host": MultiplayerManager.is_host,
				"slime_variant": MultiplayerManager.player_slime_variant
			})
			# If host, also send info for all other known players
			if MultiplayerManager.is_host:
				for user_id in MultiplayerManager.players:
					if user_id != MultiplayerManager.user_id:
						var info = MultiplayerManager.players[user_id]
						var ign = str(info.get("ign", ""))
						if not ign.is_empty():
							MultiplayerManager.send_match_state({
								"type": "player_info",
								"user_id": user_id,
								"ign": ign,
								"is_host": bool(info.get("is_host", false)),
								"slime_variant": str(info.get("slime_variant", "blue"))
							})
				if _title_controller != null and _title_controller.has_method("broadcast_lobby_name"):
					_title_controller.broadcast_lobby_name()
		"lobby_name":
			MultiplayerManager.lobby_name = str(data.get("name", "")).strip_edges()
			if _title_controller != null and _title_controller.has_method("refresh_title"):
				_title_controller.refresh_title()
		"chat_message":
			var sender := str(data.get("sender", "Unknown"))
			var message := str(data.get("message", ""))
			if not message.is_empty() and sender != MultiplayerManager.player_ign.strip_edges():
				_party_controller.add_chat_message(sender, message, Color(0.7, 0.65, 0.85))
		"class_selected":
			_party_controller.handle_remote_class_selected(
				str(data.get("user_id", "")),
				str(data.get("class_name", "")),
				str(data.get("slime_variant", ""))
			)
		"admin_action":
			_handle_admin_action(data)
		"admin_broadcast":
			var sender := str(data.get("sender", "ADMIN"))
			var message := str(data.get("message", ""))
			if not message.is_empty():
				_party_controller.add_chat_message(sender, message, Color(0.9, 0.3, 0.3))


func _on_match_phase_changed(new_phase: String) -> void:
	if new_phase == "in_game":
		if not MultiplayerManager.is_host and is_instance_valid(_start_button) and _start_button.visible:
			show_join_game_ui()
		else:
			_transition_to_game_scene("manager_phase")


func _handle_admin_action(data: Dictionary) -> void:
	var action := str(data.get("action", ""))
	var target_id := str(data.get("target_user_id", ""))

	match action:
		"kicked":
			if target_id == MultiplayerManager.user_id:
				_party_controller.add_chat_message("SYSTEM", "You were kicked from the lobby.", Color(0.9, 0.3, 0.3))
				await get_tree().create_timer(2.0).timeout
				if not main_menu_scene_path.is_empty():
					get_tree().change_scene_to_file(main_menu_scene_path)
		"host_changed":
			var new_host_id := str(data.get("new_host_id", ""))
			MultiplayerManager.is_host = (new_host_id == MultiplayerManager.user_id)
			_party_controller.add_chat_message("SYSTEM", "Host has been changed.", Color(0.9, 0.7, 0.3))
		"lobby_closed":
			var reason := str(data.get("reason", "Admin closed lobby"))
			_party_controller.add_chat_message("SYSTEM", reason, Color(0.9, 0.3, 0.3))
			await get_tree().create_timer(2.0).timeout
			if not main_menu_scene_path.is_empty():
				get_tree().change_scene_to_file(main_menu_scene_path)
		"teleport":
			if target_id == MultiplayerManager.user_id:
				var x: float = data.get("x", 400.0)
				var y: float = data.get("y", 300.0)
				# Handle teleport in game if needed
				print("[Admin] Teleported to %s, %s" % [x, y])
