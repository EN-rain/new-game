extends Node
class_name RoomLobbyPartyController


const CROWN_EMOJI = ""

@export var system_sender_name: String = "System"
@export var lobby_welcome_message: String = "Welcome to the lobby!"
@export var lobby_welcome_color: Color = Color(0.9, 0.75, 0.3)
@export var joined_lobby_format: String = "%s joined the lobby."
@export var joined_lobby_color: Color = Color(0.35, 0.65, 0.45)
@export var left_lobby_format: String = "%s left the lobby."
@export var left_lobby_color: Color = Color(0.75, 0.35, 0.35)
@export var selected_class_format: String = "%s chose %s."
@export var selected_class_color: Color = Color(0.4, 0.7, 0.9)
@export var change_class_hint_format: String = "%s is changing class. Drag the carousel to pick a new class."
@export var change_class_hint_color: Color = Color(0.82, 0.72, 0.42)
@export var select_class_button_text: String = "Select Class"
@export var change_class_button_text: String = "Change Class"
@export var taken_class_button_text: String = "Class Taken"
@export var taken_class_message_format: String = "%s is already chosen by another player."
@export var taken_class_message_color: Color = Color(0.85, 0.45, 0.3)

var _player_entries: Dictionary = {}
var _selected_class: PlayerClass = null
var _view: RoomLobbyView
var _title_controller: Node
var _carousel_controller: Node
var _chat_box: Node
var _select_class_button: Button
var _start_button: Button
var _class_selection_locked: bool = false


func setup(refs: Dictionary, title_controller: Node, carousel_controller: Node, chat_box: Node, class_slots: Array[Control], select_class_button: Button, left_button: Button, right_button: Button, start_button: Button) -> void:
	_view = RoomLobbyView.new(refs)
	_view.setup_right_panels()
	_title_controller = title_controller
	_carousel_controller = carousel_controller
	_chat_box = chat_box
	_select_class_button = select_class_button
	_start_button = start_button
	if _title_controller != null and _title_controller.has_method("setup"):
		_title_controller.setup(Callable(self, "get_host_ign"))
	if _carousel_controller != null and _carousel_controller.has_method("setup"):
		_carousel_controller.setup(_view, class_slots, left_button, right_button)
	if _carousel_controller != null and _carousel_controller.has_signal("active_class_changed"):
		var on_active_changed := Callable(self, "_on_active_class_changed")
		if not _carousel_controller.is_connected("active_class_changed", on_active_changed):
			_carousel_controller.connect("active_class_changed", on_active_changed)
	refresh_lobby_title()
	if _chat_box != null and _chat_box.has_method("focus_input"):
		_chat_box.focus_input()
	add_chat_message(system_sender_name, lobby_welcome_message, lobby_welcome_color)
	_selected_class = MultiplayerManager.player_class
	_set_class_selection_locked(_selected_class != null)
	update_class_highlight()


func bootstrap_party_entries() -> void:
	if not MultiplayerManager.is_authenticated():
		refresh_party_cards()
		return

	# Ensure local player is in MultiplayerManager.players with current slime_variant
	var local_id = MultiplayerManager.user_id
	if not MultiplayerManager.players.has(local_id):
		MultiplayerManager.players[local_id] = {
			"ign": MultiplayerManager.player_ign,
			"is_host": MultiplayerManager.is_host,
			"presence": null,
			"slime_variant": MultiplayerManager.player_slime_variant
		}
	else:
		MultiplayerManager.players[local_id]["slime_variant"] = MultiplayerManager.player_slime_variant

	add_player_entry(
		MultiplayerManager.user_id,
		MultiplayerManager.player_ign + " (You)",
		CROWN_EMOJI if MultiplayerManager.is_host else "",
		MultiplayerManager.is_host
	)

	for user_id in MultiplayerManager.players:
		if user_id == MultiplayerManager.user_id:
			continue
		var info = MultiplayerManager.players[user_id]
		var is_host_flag := bool(info.get("is_host", false))
		var ign := str(info.get("ign", "")).strip_edges()
		# Add all players, even with empty IGNs (will use placeholder)
		add_player_entry(user_id, ign, CROWN_EMOJI if is_host_flag else "", is_host_flag)

	refresh_start_button_state()


func get_view() -> RoomLobbyView:
	return _view


func get_selected_class() -> PlayerClass:
	return _selected_class


func get_player_count() -> int:
	return MultiplayerManager.players.size()


func get_host_ign() -> String:
	if MultiplayerManager.is_host and not MultiplayerManager.player_ign.strip_edges().is_empty():
		return MultiplayerManager.player_ign

	for entry in _player_entries.values():
		if bool(entry.get("is_host", false)):
			var host_ign: String = str(entry.get("ign", "")).replace(" (You)", "").strip_edges()
			if not host_ign.is_empty():
				return host_ign

	if not MultiplayerManager.player_ign.strip_edges().is_empty():
		return MultiplayerManager.player_ign
	return "Player"


func refresh_lobby_title() -> void:
	if _title_controller != null and _title_controller.has_method("refresh_title"):
		_title_controller.refresh_title()


func refresh_start_button_state() -> void:
	if not is_instance_valid(_start_button):
		return
	_start_button.visible = MultiplayerManager.is_host
	_start_button.disabled = not MultiplayerManager.is_host or get_player_count() < 1 or not all_players_have_class()


func all_players_have_class() -> bool:
	for user_id in _player_entries:
		var entry = _player_entries[user_id]
		var selected_class = str(entry.get("selected_class", ""))
		if selected_class.is_empty():
			return false
	return true


func add_player_entry(user_id: String, ign: String, _prefix: String, is_host_flag: bool) -> void:
	if _player_entries.has(user_id):
		var entry = _player_entries[user_id]
		entry.ign = ign
		entry.is_host = is_host_flag
		refresh_party_cards()
		return

	# Use placeholder name for empty IGNs
	var display_ign = ign if not ign.is_empty() else "Player"

	var accent_color = _view.get_next_player_accent(_player_entries.size())
	var p_class = MultiplayerManager.get_player_class(user_id)
	var selected_class_name = ""
	if p_class != null:
		selected_class_name = p_class.display_name
	_player_entries[user_id] = {
		"ign": display_ign,
		"is_host": is_host_flag,
		"accent_color": accent_color,
		"selected_class": selected_class_name
	}
	refresh_party_cards()
	refresh_lobby_title()
	add_chat_message(system_sender_name, joined_lobby_format % display_ign, joined_lobby_color)


func remove_player_entry(user_id: String) -> void:
	if _player_entries.has(user_id):
		var entry = _player_entries[user_id]
		add_chat_message(system_sender_name, left_lobby_format % str(entry.ign), left_lobby_color)
		_player_entries.erase(user_id)
	refresh_start_button_state()
	refresh_party_cards()
	refresh_lobby_title()
	_refresh_select_class_button_state()


func refresh_party_cards() -> void:
	if _view != null:
		_view.refresh_party_cards(_player_entries)


func get_active_class_name() -> String:
	if _carousel_controller != null and _carousel_controller.has_method("get_active_class_name"):
		return _carousel_controller.get_active_class_name()
	return ""


func update_class_highlight() -> void:
	if _carousel_controller != null and _carousel_controller.has_method("render_carousel"):
		_carousel_controller.render_carousel(0.0)
	_refresh_select_class_button_state()


func move_left() -> void:
	if _carousel_controller != null and _carousel_controller.has_method("move_left"):
		_carousel_controller.move_left()


func move_right() -> void:
	if _carousel_controller != null and _carousel_controller.has_method("move_right"):
		_carousel_controller.move_right()


func on_select_class_pressed() -> void:
	if _class_selection_locked:
		# Clear current selection so user can freely re-select any class
		var previous_class_name := ""
		if _selected_class != null:
			previous_class_name = _selected_class.display_name
		_selected_class = null
		MultiplayerManager.player_class = null
		if MultiplayerManager.is_authenticated():
			MultiplayerManager.player_classes.erase(MultiplayerManager.user_id)
			if _player_entries.has(MultiplayerManager.user_id):
				_player_entries[MultiplayerManager.user_id]["selected_class"] = ""
		refresh_party_cards()
		_set_class_selection_locked(false)
		refresh_start_button_state()
		# Notify remote players that this class was cleared
		if not previous_class_name.is_empty() and MultiplayerManager.is_socket_open() and not MultiplayerManager.match_id.is_empty():
			add_chat_message(system_sender_name, change_class_hint_format % _get_local_player_chat_name(), change_class_hint_color)
			MultiplayerManager.send_match_state({
				"type": "class_selected",
				"user_id": MultiplayerManager.user_id,
				"class_name": "",
				"slime_variant": MultiplayerManager.player_slime_variant
			})
		return
	var active_class := get_active_class_name()
	if _is_class_taken_by_other_player(active_class):
		add_chat_message(system_sender_name, taken_class_message_format % active_class, taken_class_message_color)
		_refresh_select_class_button_state()
		return
	_selected_class = get_player_class_for_name(active_class)
	add_chat_message(system_sender_name, selected_class_format % [_get_local_player_chat_name(), active_class], selected_class_color)
	if _selected_class != null:
		_selected_class.player_scene = MultiplayerManager.resolve_player_scene()
		MultiplayerManager.player_class = _selected_class
		if MultiplayerManager.is_authenticated():
			MultiplayerManager.set_player_class(MultiplayerManager.user_id, _selected_class)
		# Set slime variant based on carousel preview for this class
		if _carousel_controller != null and _carousel_controller.has_method("_get_preview_variant_for_class"):
			MultiplayerManager.player_slime_variant = _carousel_controller._get_preview_variant_for_class(active_class)
			# Also update in players dictionary for party card display
			if MultiplayerManager.is_authenticated() and MultiplayerManager.players.has(MultiplayerManager.user_id):
				MultiplayerManager.players[MultiplayerManager.user_id]["slime_variant"] = MultiplayerManager.player_slime_variant
		# Update local player entry with selected class
		if MultiplayerManager.is_authenticated() and _player_entries.has(MultiplayerManager.user_id):
			_player_entries[MultiplayerManager.user_id]["selected_class"] = active_class
			refresh_party_cards()
		_set_class_selection_locked(true)
		refresh_start_button_state()
		if MultiplayerManager.is_socket_open() and not MultiplayerManager.match_id.is_empty():
			MultiplayerManager.send_match_state({
				"type": "class_selected",
				"user_id": MultiplayerManager.user_id,
				"class_name": active_class,
				"slime_variant": MultiplayerManager.player_slime_variant
			})


func _set_class_selection_locked(locked: bool) -> void:
	_class_selection_locked = locked
	_refresh_select_class_button_state()
	if _carousel_controller != null and _carousel_controller.has_method("set_interaction_enabled"):
		_carousel_controller.set_interaction_enabled(not locked)


func _refresh_select_class_button_state() -> void:
	if is_instance_valid(_select_class_button):
		if _class_selection_locked:
			_select_class_button.text = change_class_button_text
			_select_class_button.disabled = false
		else:
			var active_class := get_active_class_name()
			var is_taken := _is_class_taken_by_other_player(active_class)
			_select_class_button.text = taken_class_button_text if is_taken else select_class_button_text
			_select_class_button.disabled = is_taken


func _is_class_taken_by_other_player(class_display_name: String) -> bool:
	if class_display_name.is_empty():
		return false
	var normalized_target := class_display_name.to_lower().strip_edges()
	var local_user_id := ""
	if MultiplayerManager.is_authenticated():
		local_user_id = MultiplayerManager.user_id

	# Prefer authoritative lobby entries (what the UI actually shows).
	for user_id in _player_entries.keys():
		if not local_user_id.is_empty() and user_id == local_user_id:
			continue
		var entry: Dictionary = _player_entries[user_id]
		var selected_name := str(entry.get("selected_class", "")).to_lower().strip_edges()
		if not selected_name.is_empty() and selected_name == normalized_target:
			return true

	# Fallback to manager cache if an entry has not been materialized yet.
	for user_id in MultiplayerManager.player_classes.keys():
		if not local_user_id.is_empty() and user_id == local_user_id:
			continue
		var assigned_class: PlayerClass = MultiplayerManager.player_classes.get(user_id, null)
		if assigned_class == null:
			continue
		if assigned_class.display_name.to_lower().strip_edges() == normalized_target:
			return true

	return false


func _on_active_class_changed(_class_name: String) -> void:
	_refresh_select_class_button_state()


func get_player_class_for_name(selected_name: String) -> PlayerClass:
	var class_id := ClassManager.display_name_to_class_id(selected_name)
	if not class_id.is_empty():
		return ClassManager.create_class_instance(class_id)
	return null


func get_slime_scene_path_for_class(selected_name: String) -> String:
	if _carousel_controller != null and _carousel_controller.has_method("get_slime_scene_path_for_class"):
		return _carousel_controller.get_slime_scene_path_for_class(selected_name)
	return ""


func handle_snapshot_players(players: Array) -> void:
	for player_data in players:
		var user_id := str(player_data.get("user_id", ""))
		var ign := str(player_data.get("ign", ""))
		var is_host_flag := bool(player_data.get("is_host", false))
		if user_id.is_empty() or user_id == MultiplayerManager.user_id:
			continue
		if MultiplayerManager.players.has(user_id):
			MultiplayerManager.players[user_id]["ign"] = ign
			MultiplayerManager.players[user_id]["is_host"] = is_host_flag
		add_player_entry(user_id, ign, CROWN_EMOJI if is_host_flag else "", is_host_flag)
	refresh_start_button_state()


func handle_player_info_state(data: Dictionary) -> void:
	var ign := str(data.get("ign", ""))
	var is_host_flag := bool(data.get("is_host", false))
	var entry_id := str(data.get("user_id", ""))
	if entry_id.is_empty():
		return
	var slime_variant := str(data.get("slime_variant", "blue"))
	var was_known = MultiplayerManager.players.has(entry_id)
	if was_known:
		MultiplayerManager.players[entry_id]["ign"] = ign
		MultiplayerManager.players[entry_id]["is_host"] = is_host_flag
		MultiplayerManager.players[entry_id]["slime_variant"] = slime_variant
	else:
		MultiplayerManager.players[entry_id] = {"ign": ign, "is_host": is_host_flag, "presence": null, "slime_variant": slime_variant}
	add_player_entry(entry_id, ign, CROWN_EMOJI if is_host_flag else "", is_host_flag)
	refresh_start_button_state()
	_refresh_select_class_button_state()


func handle_remote_class_selected(sender_id: String, selected_name: String, slime_variant: String = "") -> void:
	if sender_id.is_empty() or sender_id == MultiplayerManager.user_id:
		return
	if selected_name.is_empty():
		# Remote player cleared their class selection
		MultiplayerManager.player_classes.erase(sender_id)
		if _player_entries.has(sender_id):
			_player_entries[sender_id]["selected_class"] = ""
			refresh_party_cards()
		add_chat_message(system_sender_name, change_class_hint_format % _get_player_chat_name(sender_id), change_class_hint_color)
	else:
		var player_class := get_player_class_for_name(selected_name)
		if player_class != null:
			MultiplayerManager.set_player_class(sender_id, player_class)
		# Update player entry with selected class
		if _player_entries.has(sender_id):
			_player_entries[sender_id]["selected_class"] = selected_name
			refresh_party_cards()
		add_chat_message(system_sender_name, selected_class_format % [_get_player_chat_name(sender_id), selected_name], selected_class_color)
	# Update slime variant if provided
	if not slime_variant.is_empty() and MultiplayerManager.players.has(sender_id):
		MultiplayerManager.players[sender_id]["slime_variant"] = slime_variant
	_refresh_select_class_button_state()
	refresh_start_button_state()


func add_chat_message(sender: String, message: String, color: Color) -> void:
	if _chat_box != null and _chat_box.has_method("add_message"):
		_chat_box.add_message(sender, message, color)


func _get_local_player_chat_name() -> String:
	if MultiplayerManager.player_ign.strip_edges().is_empty():
		return "You"
	return MultiplayerManager.player_ign.strip_edges()


func _get_player_chat_name(user_id: String) -> String:
	if MultiplayerManager.is_authenticated() and user_id == MultiplayerManager.user_id:
		return _get_local_player_chat_name()
	if _player_entries.has(user_id):
		var entry: Dictionary = _player_entries[user_id]
		var ign: String = str(entry.get("ign", "")).replace(" (You)", "").strip_edges()
		if not ign.is_empty():
			return ign
	if MultiplayerManager.players.has(user_id):
		var player_info: Dictionary = MultiplayerManager.players[user_id]
		var player_ign: String = str(player_info.get("ign", "")).strip_edges()
		if not player_ign.is_empty():
			return player_ign
	return "Player"
