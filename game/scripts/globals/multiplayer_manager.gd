extends Node

 
class MatchState:
	var data: String
	var op_code: int
	var presence: Presence = null

class Presence:
	var user_id: String

# --- Custom Networking ---
var auth_token: String = ""
var user_id: String = ""
var username: String = ""
var player_ign: String = ""
var account_email: String = ""

var socket: WebSocketPeer = WebSocketPeer.new()
var match_id: String = ""
var room_code: String = ""
var lobby_name: String = ""
var is_host: bool = false
var is_admin: bool = false
var players: Dictionary = {}  # user_id -> {ign, is_host, slime_variant}
var player_classes: Dictionary = {} # user_id -> PlayerClass
var player_subclasses: Dictionary = {} # user_id -> PlayerClass
var player_slime_variant: String = "blue"
var player_class: PlayerClass = null
var player_subclass: PlayerClass = null
var subclass_choice_made: bool = false
var player_level: int = 1
var match_phase: String = "lobby":
	set(value):
		if match_phase == value:
			return
		match_phase = value
		match_phase_changed.emit(match_phase)

# Configuration
const SERVER_CONFIG_FILE = "server_config.cfg"
const TOKEN_SAVE_PATH = "user://auth_session.json"
var _base_url: String = "http://35.247.150.45:3000"
var debug_network_logs: bool = false
var _debug_log_last_msec: Dictionary = {}
var _pending_outbox: Array[Dictionary] = []
var _last_socket_state: int = WebSocketPeer.STATE_CLOSED
var _input_backpressure_until_msec: int = 0

# Signals
signal player_joined(user_id: String, ign: String, is_host_flag: bool)
signal player_left(user_id: String)
signal match_joined()
signal match_phase_changed(new_phase: String)
signal auth_state_changed(is_authenticated: bool, username: String, email: String)
signal connection_lost()
signal received_match_state(match_state)
signal socket_opened()

func _ready():
	_load_config()
	set_process(true)

func _load_config():
	var config = ConfigFile.new()
	if config.load("res://" + SERVER_CONFIG_FILE) == OK:
		var host = config.get_value("server", "host", "35.247.150.45")
		var port = config.get_value("server", "port", 3000)
		var scheme = config.get_value("server", "scheme", "http")
		_base_url = "%s://%s:%d" % [scheme, host, port]

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()
	if state != _last_socket_state:
		_on_socket_state_changed(_last_socket_state, state)
		_last_socket_state = state
	if state == WebSocketPeer.STATE_OPEN:
		_flush_pending_outbox()
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet()
			_on_data_received(packet.get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		# Handle unexpected close
		pass

# --- Auth Methods (API Compatibility) ---

func is_authenticated() -> bool:
	return not auth_token.is_empty()

func clear_session():
	auth_token = ""
	user_id = ""
	username = ""
	if FileAccess.file_exists(TOKEN_SAVE_PATH):
		DirAccess.remove_absolute(TOKEN_SAVE_PATH)
	auth_state_changed.emit(false, "", "")

func restore_saved_session():
	if not FileAccess.file_exists(TOKEN_SAVE_PATH):
		return {"success": false}
	
	var file = FileAccess.open(TOKEN_SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if data and data.has("token"):
		auth_token = data.token
		user_id = data.user_id
		username = data.username
		player_ign = data.username
		auth_state_changed.emit(true, username, "")
		return {"success": true}
	return {"success": false}

func login_with_email(p_email, p_password):
	var uname = p_email
	# Normalize username/email if it's not a full email (to match normalized DB usernames)
	# However, if it's a full email, we should probably keep it as is since the DB email column isn't normalized
	if not "@" in uname:
		var regex = RegEx.new()
		regex.compile("[^a-zA-Z0-9_]")
		uname = regex.sub(uname, "_", true)
		
	var body = JSON.stringify({"username": uname, "password": p_password})
	var result = await _http_request("/auth/login", HTTPClient.METHOD_POST, body)
	if result.has("token"):
		auth_token = result.token
		user_id = result.user_id
		username = result.username
		player_ign = result.username
		_save_session(result)
		auth_state_changed.emit(true, username, p_email)
		return {"success": true}
	
	var error_msg = "Login failed"
	if result.has("error"):
		error_msg = result.error
	elif result.has("errors") and result.errors is Array:
		error_msg = ", ".join(result.errors)
		
	return {"success": false, "error": error_msg}

func register_with_email(p_email, p_password, p_username = ""):
	var uname = p_username if not p_username.is_empty() else p_email.split("@")[0]
	# Normalize username to meet API requirements (alphanumeric and underscores only)
	var regex = RegEx.new()
	regex.compile("[^a-zA-Z0-9_]")
	uname = regex.sub(uname, "_", true)
	
	if uname.length() < 3:
		uname += "_usr"
		
	var body = JSON.stringify({"username": uname, "email": p_email, "password": p_password})
	var result = await _http_request("/auth/register", HTTPClient.METHOD_POST, body)
	if result.has("token"):
		auth_token = result.token
		user_id = result.user_id
		username = result.username
		player_ign = result.username
		_save_session(result)
		auth_state_changed.emit(true, username, p_email)
		return {"success": true}
	
	var error_msg = "Registration failed"
	if result.has("error"):
		error_msg = result.error
	elif result.has("errors") and result.errors is Array:
		error_msg = ", ".join(result.errors)
	
	return {"success": false, "error": error_msg}

# --- Room Methods ---

func create_room(title = "Moon Room"):
	var body = JSON.stringify({"title": title})
	var result = await _http_request("/rooms/create", HTTPClient.METHOD_POST, body)
	if result.has("ws_url"):
		room_code = result.room_code
		match_id = result.room_id
		is_host = true
		_connect_to_game_server(result.ws_url)
		return room_code
	return ""

func logout():
	clear_session()

func disconnect_server():
	socket.close()
	_pending_outbox.clear()
	_input_backpressure_until_msec = 0
	match_id = ""
	room_code = ""
	lobby_name = ""
	is_host = false
	is_admin = false
	match_phase = "lobby"
	players.clear()
	player_classes.clear()
	player_subclasses.clear()

func get_server_endpoint_summary() -> String:
	return _base_url

func get_last_room_error() -> String:
	return ""

func resolve_player_scene() -> PackedScene:
	var variant_path = SlimePaletteRegistry.get_scene_path(player_slime_variant)
	if variant_path.is_empty():
		return null
	return load(variant_path) as PackedScene

func is_socket_open() -> bool:
	return socket.get_ready_state() == WebSocketPeer.STATE_OPEN

func join_room(p_room_code):
	var body = JSON.stringify({"room_code": p_room_code})
	var result = await _http_request("/rooms/join", HTTPClient.METHOD_POST, body)
	if result.has("ws_url"):
		room_code = result.room_code
		match_id = result.room_id
		is_host = false
		_connect_to_game_server(result.ws_url)
		return true
	return false

# --- Internal Helpers ---

func connect_to_server(_p_room_code: String) -> bool:
	# In our custom system, we don't need a separate connect call before creating/joining
	# but we return true to satisfy the UI flow.
	return true

func get_player_class(p_user_id: String):
	return player_classes.get(p_user_id, null)

func set_player_class(p_user_id: String, p_class: PlayerClass):
	player_classes[p_user_id] = p_class

func get_player_subclass(p_user_id: String):
	return player_subclasses.get(p_user_id, null)

func set_player_subclass(p_user_id: String, p_subclass: PlayerClass):
	player_subclasses[p_user_id] = p_subclass

func _save_session(data):
	var file = FileAccess.open(TOKEN_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))

func _http_request(path: String, method: int, body: String = ""):
	var http = HTTPRequest.new()
	add_child(http)
	var headers = ["Content-Type: application/json"]
	if not auth_token.is_empty():
		headers.append("Authorization: Bearer " + auth_token)
	
	http.request(_base_url + path, headers, method, body)
	var response = await http.request_completed
	var status_code = response[1]
	var response_body = response[3].get_string_from_utf8()
	http.queue_free()
	
	var json = JSON.parse_string(response_body)
	if json == null:
		if status_code >= 400:
			return {"error": "Server error (%d): %s" % [status_code, response_body.substr(0, 100)]}
		return {}
		
	return json

func _connect_to_game_server(url: String):
	var ws_url = url
	if not auth_token.is_empty():
		ws_url += "&token=" + auth_token
	var err := socket.connect_to_url(ws_url)
	_debug_log_limited("connect", "[Net] ws connect url=%s room=%s" % [ws_url, room_code], 1500)
	if err != OK:
		_debug_log_limited("connect_err", "[Net] ws connect_to_url error=%d" % err, 100)
	match_joined.emit()

func _on_data_received(data_str: String):
	var envelope = JSON.parse_string(data_str)
	if envelope == null:
		return

	var payload: Variant = envelope
	if envelope is Dictionary and envelope.has("data"):
		var raw_payload: Variant = envelope.get("data")
		if raw_payload is String:
			var parsed_payload = JSON.parse_string(raw_payload)
			if parsed_payload != null:
				payload = parsed_payload
		elif raw_payload is Dictionary:
			payload = raw_payload

	var payload_dict: Dictionary = payload if payload is Dictionary else {}
	# moon_server uses "op" at top-level; keep "op_code" fallback for compatibility.
	var op_code: int = int(envelope.get("op", envelope.get("op_code", NetworkMessaging.OP_MESSAGE)))
	var msg_type := str(payload_dict.get("type", ""))
	_debug_log_limited("recv:%d:%s" % [op_code, msg_type], "[Net] recv op=%d type=%s sender=%s keys=%s" % [op_code, msg_type, str(envelope.get("user_id", payload_dict.get("user_id", ""))), str(payload_dict.keys())], 1500)

	# Emit normalized match state for compatibility with existing handlers.
	var ms = MatchState.new()
	ms.data = JSON.stringify(payload_dict)
	ms.op_code = op_code

	var sender_id := str(envelope.get("user_id", ""))
	if sender_id.is_empty():
		sender_id = str(payload_dict.get("user_id", ""))
	if not sender_id.is_empty():
		ms.presence = Presence.new()
		ms.presence.user_id = sender_id
	received_match_state.emit(ms)

	if op_code == NetworkMessaging.OP_PLAYER_JOIN or msg_type == "player_joined":
		var pid := str(payload_dict.get("user_id", ""))
		if not pid.is_empty():
			var ign := str(payload_dict.get("ign", "Unknown"))
			var joined_is_host := bool(payload_dict.get("is_host", false))
			players[pid] = {
				"ign": ign,
				"is_host": joined_is_host,
				"slime_variant": str(payload_dict.get("slime_variant", "blue"))
			}
			player_joined.emit(pid, ign, joined_is_host)
	elif op_code == NetworkMessaging.OP_PLAYER_LEAVE or msg_type == "player_left":
		var left_id := str(payload_dict.get("user_id", ""))
		if not left_id.is_empty():
			players.erase(left_id)
			player_left.emit(left_id)

func send_match_state(data: Dictionary):
	send_match_state_op(NetworkMessaging.OP_MESSAGE, data)


func send_match_state_op(op_code: int, data: Dictionary) -> void:
	# High-frequency input packets should be dropped during active backpressure.
	if op_code == NetworkMessaging.OP_INPUT:
		var now_msec := Time.get_ticks_msec()
		if now_msec < _input_backpressure_until_msec:
			return
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		# Do not queue OP_INPUT while disconnected; stale inputs are useless.
		if op_code != NetworkMessaging.OP_INPUT:
			_queue_outbound(op_code, data)
		_debug_log_limited("send_queue:%d:%s" % [op_code, str(data.get("type", ""))], "[Net] queue op=%d type=%s reason=socket_not_open state=%d" % [op_code, str(data.get("type", "")), socket.get_ready_state()], 1200)
		return
	_send_payload(op_code, data)


func _send_payload(op_code: int, data: Dictionary) -> void:
	var payload := data.duplicate()
	payload["op"] = op_code
	var err := socket.send_text(JSON.stringify(payload))
	if err == ERR_OUT_OF_MEMORY:
		# WebSocket outbound buffer is full. Drop/slow only OP_INPUT; keep gameplay/control events.
		if op_code == NetworkMessaging.OP_INPUT:
			_input_backpressure_until_msec = Time.get_ticks_msec() + 300
			_debug_log_limited("input_backpressure", "[Net] input backpressure active (300ms)", 800)
			return
		# Retry important messages later.
		_queue_outbound(op_code, data)
		_debug_log_limited("send_backpressure:%d" % op_code, "[Net] backpressure queued op=%d type=%s" % [op_code, str(data.get("type", ""))], 800)
		return
	if err != OK:
		_debug_log_limited("send_err:%d" % op_code, "[Net] send failed err=%d op=%d type=%s" % [err, op_code, str(data.get("type", ""))], 1000)
		return
	_debug_log_limited("send:%d:%s" % [op_code, str(data.get("type", ""))], "[Net] send op=%d type=%s room=%s keys=%s" % [op_code, str(data.get("type", "")), room_code, str(data.keys())], 1500)


func _queue_outbound(op_code: int, data: Dictionary) -> void:
	_pending_outbox.append({
		"op_code": op_code,
		"data": data.duplicate(true)
	})
	if _pending_outbox.size() > 64:
		_pending_outbox.pop_front()


func _flush_pending_outbox() -> void:
	if _pending_outbox.is_empty():
		return
	_debug_log_limited("flush", "[Net] flush queued messages count=%d" % _pending_outbox.size(), 500)
	var batch: Array[Dictionary] = _pending_outbox.duplicate(true)
	_pending_outbox.clear()
	for entry in batch:
		_send_payload(int(entry.get("op_code", NetworkMessaging.OP_MESSAGE)), entry.get("data", {}))


func _on_socket_state_changed(previous_state: int, current_state: int) -> void:
	_debug_log_limited("state_change", "[Net] socket state %d -> %d" % [previous_state, current_state], 200)
	if current_state == WebSocketPeer.STATE_OPEN:
		socket_opened.emit()
	elif previous_state == WebSocketPeer.STATE_OPEN and current_state == WebSocketPeer.STATE_CLOSED:
		connection_lost.emit()
	elif current_state == WebSocketPeer.STATE_CLOSED:
		var close_code := socket.get_close_code()
		var close_reason := socket.get_close_reason()
		_debug_log_limited(
			"closed_reason",
			"[Net] socket closed code=%d reason=%s was_open=%s" % [close_code, close_reason, str(previous_state == WebSocketPeer.STATE_OPEN)],
			200
		)


func _debug_log_limited(key: String, message: String, min_interval_ms: int = 1000) -> void:
	if not debug_network_logs:
		return
	var now := Time.get_ticks_msec()
	var last := int(_debug_log_last_msec.get(key, 0))
	if now - last < min_interval_ms:
		return
	_debug_log_last_msec[key] = now
	print(message)
