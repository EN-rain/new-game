extends Node

## SoloRunSaveManager - Local save system with 5 slots for solo play
## Each slot is stored as a separate JSON file

const SAVE_DIR := "user://solo_saves/"
const MAX_SLOTS := 5
const SAVE_VERSION := 1

var _pending_continue_snapshot: Dictionary = {}


func _ready() -> void:
	# Ensure save directory exists
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	# Migrate old single-save if it exists
	_migrate_old_save()


func _slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.json" % slot


func _names_path() -> String:
	return SAVE_DIR + "slot_names.json"


func _load_slot_names() -> Dictionary:
	if not FileAccess.file_exists(_names_path()):
		return {}
	var file := FileAccess.open(_names_path(), FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _save_slot_names(names: Dictionary) -> void:
	var file := FileAccess.open(_names_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(names))


func get_slot_name(slot: int) -> String:
	var names := _load_slot_names()
	return str(names.get(str(slot), "Slot %d" % slot))


func rename_slot(slot: int, new_name: String) -> void:
	var names := _load_slot_names()
	names[str(slot)] = new_name
	_save_slot_names(names)


func has_saved_run() -> bool:
	for i in range(1, MAX_SLOTS + 1):
		if not _read_slot(i).is_empty():
			return true
	return false


func has_slot(slot: int) -> bool:
	return not _read_slot(slot).is_empty()


func clear_slot(slot: int) -> void:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func clear_saved_run() -> void:
	_pending_continue_snapshot.clear()
	for i in range(1, MAX_SLOTS + 1):
		clear_slot(i)
	if FileAccess.file_exists(_names_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_names_path()))


func save_to_slot(slot: int, scene_root: Node) -> bool:
	if slot < 1 or slot > MAX_SLOTS:
		return false
	if scene_root == null or not is_instance_valid(scene_root):
		return false
	if not scene_root.has_method("build_solo_run_snapshot"):
		return false
	var snapshot: Dictionary = scene_root.call("build_solo_run_snapshot")
	if snapshot.is_empty():
		return false
	snapshot["version"] = SAVE_VERSION
	snapshot["saved_at"] = Time.get_datetime_string_from_system()
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(snapshot))
	return true


func save_current_run_from_scene(scene_root: Node) -> bool:
	# Legacy: saves to first empty slot, or slot 1 if all full
	var slot := find_empty_slot()
	if slot == 0:
		slot = 1
	return save_to_slot(slot, scene_root)


func load_from_slot(slot: int) -> bool:
	var snapshot := _read_slot(slot)
	if snapshot.is_empty():
		return false
	_apply_snapshot_to_globals(snapshot)
	set_pending_continue_snapshot(snapshot)
	return true


func prepare_continue_run() -> bool:
	# Legacy: loads from first available slot
	for i in range(1, MAX_SLOTS + 1):
		var snapshot := _read_slot(i)
		if not snapshot.is_empty():
			_apply_snapshot_to_globals(snapshot)
			set_pending_continue_snapshot(snapshot)
			return true
	return false


func set_pending_continue_snapshot(snapshot: Dictionary) -> void:
	_pending_continue_snapshot = snapshot.duplicate(true)


func clear_pending_continue_snapshot() -> void:
	_pending_continue_snapshot.clear()


func consume_pending_continue_snapshot() -> Dictionary:
	var snapshot := _pending_continue_snapshot.duplicate(true)
	_pending_continue_snapshot.clear()
	return snapshot


func get_slot_summary(slot: int) -> Dictionary:
	var snapshot := _read_slot(slot)
	if snapshot.is_empty():
		return {}
	return {
		"slot": slot,
		"slot_name": get_slot_name(slot),
		"class_name": str(snapshot.get("player_class_name", "-")),
		"level": int(snapshot.get("player_level", 1)),
		"round": int(snapshot.get("round", 1)),
		"coins": int(snapshot.get("coins", 0)),
		"saved_at": str(snapshot.get("saved_at", "")),
	}


func get_all_slot_summaries() -> Array:
	var summaries := []
	for i in range(1, MAX_SLOTS + 1):
		summaries.append(get_slot_summary(i))
	return summaries


func find_empty_slot() -> int:
	for i in range(1, MAX_SLOTS + 1):
		if _read_slot(i).is_empty():
			return i
	return 0


func auto_save(scene_root: Node) -> Dictionary:
	var slot := find_empty_slot()
	if slot == 0:
		return {"success": false, "error": "All 5 solo slots are full. Delete one first.", "slot": 0}
	var ok := save_to_slot(slot, scene_root)
	if ok:
		return {"success": true, "error": "", "slot": slot}
	return {"success": false, "error": "Save failed", "slot": 0}


func _read_slot(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _read_saved_run() -> Dictionary:
	# Legacy compat: reads slot 1
	return _read_slot(1)


func _apply_snapshot_to_globals(snapshot: Dictionary) -> void:
	MultiplayerManager.player_class = _resolve_class_instance(str(snapshot.get("player_class_id", "")))
	MultiplayerManager.player_subclass = _resolve_class_instance(str(snapshot.get("player_subclass_id", "")))
	MultiplayerManager.subclass_choice_made = bool(snapshot.get("subclass_choice_made", false))
	MultiplayerManager.player_level = int(snapshot.get("player_level", 1))
	if snapshot.has("skill_tree_state"):
		SkillTreeManager.load_state(snapshot.get("skill_tree_state", {}))
	if CoinManager != null and CoinManager.has_method("set_coins"):
		CoinManager.set_coins(int(snapshot.get("coins", 0)))


func _resolve_class_instance(class_id: String) -> PlayerClass:
	if class_id.is_empty():
		return null
	return ClassManager.create_class_instance(class_id)


func _migrate_old_save() -> void:
	var old_path := "user://solo_run_save.json"
	if not FileAccess.file_exists(old_path):
		return
	var file := FileAccess.open(old_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	# Save to slot 1 if slot 1 is empty
	if _read_slot(1).is_empty():
		var write_file := FileAccess.open(_slot_path(1), FileAccess.WRITE)
		if write_file != null:
			write_file.store_string(JSON.stringify(parsed))
	# Remove old file
	DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path))
