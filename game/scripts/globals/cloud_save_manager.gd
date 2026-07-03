extends Node

## CloudSaveManager (Custom API Version)
## Custom REST endpoints for cloud saves on /saves

signal save_completed(slot: int, success: bool)
signal load_completed(slot: int, success: bool)
signal slots_loaded(slots: Array)

const MAX_SLOTS := 5
const SAVE_VERSION := 1

var _cached_slots: Array = []

func _ready() -> void:
	_cached_slots.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		_cached_slots[i] = {}

func build_save_snapshot(mode: String = "solo") -> Dictionary:
	var tree := get_tree()
	if tree == null: return {}
	var current_scene := tree.current_scene
	if current_scene == null or not current_scene.has_method("build_solo_run_snapshot"):
		return {}
	var snapshot: Dictionary = current_scene.call("build_solo_run_snapshot")
	if snapshot.is_empty(): return {}
	snapshot["version"] = SAVE_VERSION
	snapshot["saved_at"] = Time.get_datetime_string_from_system()
	snapshot["mode"] = mode
	return snapshot

func save_to_slot(slot: int, mode: String = "solo") -> Dictionary:
	if not MultiplayerManager.is_authenticated():
		return {"success": false, "error": "Not authenticated"}

	var snapshot := build_save_snapshot(mode)
	if snapshot.is_empty(): return {"success": false, "error": "No data"}

	var result = await _http_request("/saves/%d" % slot, HTTPClient.METHOD_POST, JSON.stringify({"data": snapshot}))
	if result.get("success", false):
		_cached_slots[slot - 1] = snapshot
		save_completed.emit(slot, true)
		return {"success": true}
	
	save_completed.emit(slot, false)
	return {"success": false, "error": result.get("error", "Save failed")}

func load_slots() -> Dictionary:
	if not MultiplayerManager.is_authenticated():
		return {"success": false, "error": "Not authenticated"}

	var result = await _http_request("/saves", HTTPClient.METHOD_GET)
	if result.get("success", false):
		# Clear cache
		for i in range(MAX_SLOTS): _cached_slots[i] = {}
		
		# Fill cache
		for s_data in result.slots:
			var slot_idx := int(s_data.get("slot", 0)) - 1
			if slot_idx >= 0 and slot_idx < MAX_SLOTS:
				var data: Dictionary = s_data.get("data", {}) if s_data.get("data", {}) is Dictionary else {}
				if data.is_empty():
					data = {}
				data["slot"] = slot_idx + 1
				data["slot_name"] = str(s_data.get("slot_name", data.get("slot_name", "Slot %d" % (slot_idx + 1))))
				data["saved_at"] = str(s_data.get("saved_at", data.get("saved_at", "")))
				_cached_slots[slot_idx] = data
		
		slots_loaded.emit(_cached_slots.duplicate())
		return {"success": true, "slots": _cached_slots}
	
	slots_loaded.emit([])
	return {"success": false}

func load_from_slot(slot: int) -> Dictionary:
	if not MultiplayerManager.is_authenticated(): return {"success": false, "error": "Not authenticated"}

	var result = await _http_request("/saves/%d" % slot, HTTPClient.METHOD_GET)
	if result.get("success", false):
		var data: Dictionary = result.get("data", {}) if result.get("data", {}) is Dictionary else {}
		if data.is_empty():
			return {"success": false, "error": "Save data is empty"}
		_cached_slots[slot - 1] = data
		_apply_snapshot(data)
		if SoloRunSaveManager != null and SoloRunSaveManager.has_method("set_pending_continue_snapshot"):
			SoloRunSaveManager.set_pending_continue_snapshot(data)
		load_completed.emit(slot, true)
		return {"success": true, "data": data}

	load_completed.emit(slot, false)
	return {"success": false}

func delete_slot(slot: int) -> Dictionary:
	var result = await _http_request("/saves/%d" % slot, HTTPClient.METHOD_DELETE)
	if result.get("success", false):
		_cached_slots[slot - 1] = {}
		return {"success": true}
	return {"success": false}


func rename_slot(slot: int, new_name: String) -> Dictionary:
	if not MultiplayerManager.is_authenticated():
		return {"success": false, "error": "Not authenticated"}
	if slot < 1 or slot > MAX_SLOTS:
		return {"success": false, "error": "Invalid slot"}
	var data: Dictionary = _cached_slots[slot - 1].duplicate(true) if _cached_slots[slot - 1] is Dictionary else {}
	if data.is_empty():
		var loaded = await _http_request("/saves/%d" % slot, HTTPClient.METHOD_GET)
		if not loaded.get("success", false):
			return {"success": false, "error": str(loaded.get("error", "Slot is empty"))}
		data = loaded.get("data", {}) if loaded.get("data", {}) is Dictionary else {}
		if data.is_empty():
			return {"success": false, "error": "Slot is empty"}
	data["slot_name"] = new_name
	var result = await _http_request("/saves/%d" % slot, HTTPClient.METHOD_POST, JSON.stringify({"data": data}))
	if result.get("success", false):
		_cached_slots[slot - 1] = data
		return {"success": true}
	return {"success": false, "error": str(result.get("error", "Rename failed"))}


func get_all_slot_summaries() -> Array:
	var summaries := []
	for slot in range(1, MAX_SLOTS + 1):
		summaries.append(get_slot_summary(slot))
	return summaries


func find_empty_slot() -> int:
	for slot in range(1, MAX_SLOTS + 1):
		var data = _cached_slots[slot - 1]
		if not (data is Dictionary) or data.is_empty():
			return slot
	return 0


func auto_save(mode: String = "solo") -> Dictionary:
	var slots_result = await load_slots()
	if not slots_result.get("success", false):
		return {"success": false, "error": str(slots_result.get("error", "Failed to load slots")), "slot": 0}
	var slot := find_empty_slot()
	if slot == 0:
		return {"success": false, "error": "All 5 cloud save slots are full. Delete one first.", "slot": 0}
	var result = await save_to_slot(slot, mode)
	if result.get("success", false):
		return {"success": true, "error": "", "slot": slot}
	return {"success": false, "error": str(result.get("error", "Save failed")), "slot": 0}

# --- Internal Helpers ---

func _http_request(path: String, method: int, body: String = ""):
	# Delegate to MultiplayerManager for auth-aware HTTP requests
	return await MultiplayerManager._http_request(path, method, body)

func _apply_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty(): return
	var class_id := str(snapshot.get("player_class_id", ""))
	if not class_id.is_empty() and ClassManager != null:
		MultiplayerManager.player_class = ClassManager.create_class_instance(class_id)
	var subclass_id := str(snapshot.get("player_subclass_id", ""))
	MultiplayerManager.player_subclass = ClassManager.create_class_instance(subclass_id) if not subclass_id.is_empty() and ClassManager != null else null
	MultiplayerManager.subclass_choice_made = bool(snapshot.get("subclass_choice_made", false))
	
	MultiplayerManager.player_level = int(snapshot.get("player_level", 1))
	if snapshot.has("skill_tree_state") and SkillTreeManager != null:
		SkillTreeManager.load_state(snapshot.get("skill_tree_state", {}))
	if CoinManager != null and CoinManager.has_method("set_coins"):
		CoinManager.set_coins(int(snapshot.get("coins", 0)))

func get_slot_summary(slot: int) -> Dictionary:
	if slot < 1 or slot > MAX_SLOTS: return {}
	var data = _cached_slots[slot - 1]
	if not (data is Dictionary) or data.is_empty(): return {}
	return {
		"slot": slot,
		"slot_name": str(data.get("slot_name", "Slot %d" % slot)),
		"class_name": str(data.get("player_class_name", "-")),
		"level": int(data.get("player_level", 1)),
		"round": int(data.get("round", 1)),
		"coins": int(data.get("coins", 0)),
		"mode": str(data.get("mode", "solo")),
		"saved_at": str(data.get("saved_at", ""))
	}
