extends Node

const SKILL_ROOT := "res://resources/skills"
const SKILL_ICON_ROOT := "res://assets/class_icons"
const SKILL_ICON_ALIASES := {
	"tank_main_fortify_stat": "fortification",
	"dps_assassin_shadow_step_ability": "shadow_teleport",
	"dps_mage_meteor_shower_ability": "meteor_storm",
	"controller_chronomancer_slow_field_ability": "time_fracture",
}
const SKILL_ICON_FALLBACKS := {
	"dps_ranger_trap_master_ability": "ranger_icon",
	"dps_ranger_trap_network_special": "ranger_icon",
}

var _skills_by_id: Dictionary = {}
var _skills_by_class: Dictionary = {}
var _skill_path_info: Dictionary = {}
var _icon_cache: Dictionary = {}


func _ready() -> void:
	_reload_registry()


func get_skill(skill_id: String):
	return _skills_by_id.get(skill_id, null)


func get_skills_for_class(class_key: String) -> Array:
	var target_key := class_key.strip_edges().to_lower()
	var skills: Array = []
	if _skills_by_class.has(target_key):
		for skill in _skills_by_class[target_key]:
			if skill != null:
				skills.append(skill)
	skills.sort_custom(func(a, b) -> bool:
		return a.skill_id < b.skill_id
	)
	return skills


func get_skills_for_tree(main_class: String, tree_key: String) -> Array:
	var results: Array = []
	for skill_id in _skill_path_info.keys():
		var info: Dictionary = _skill_path_info[skill_id]
		if str(info.get("main_class", "")) != main_class:
			continue
		if str(info.get("tree_key", "")) != tree_key:
			continue
		var skill = get_skill(skill_id)
		if skill != null:
			results.append(skill)
	results.sort_custom(func(a, b) -> bool:
		return a.skill_id < b.skill_id
	)
	return results


func get_special_skill_for_class(class_id: String) -> SkillDefinition:
	var main_class: String = ""
	var tree_key: String = ""
	if class_id in ClassManager.MAIN_CLASS_IDS:
		main_class = class_id
		tree_key = "main"
	else:
		for mc in ClassManager.MAIN_CLASS_IDS:
			if class_id in ClassManager.MAIN_TO_SUBCLASS_IDS.get(mc, []):
				main_class = mc
				tree_key = class_id
				break
	if main_class.is_empty():
		return null
	var skills := get_skills_for_tree(main_class, tree_key)
	for skill in skills:
		if skill.skill_type == SkillDefinition.SkillType.SPECIAL:
			return skill
	return null


func get_passive_skill_for_class(class_id: String) -> SkillDefinition:
	var main_class: String = ""
	var tree_key: String = ""
	if class_id in ClassManager.MAIN_CLASS_IDS:
		main_class = class_id
		tree_key = "main"
	else:
		for mc in ClassManager.MAIN_CLASS_IDS:
			if class_id in ClassManager.MAIN_TO_SUBCLASS_IDS.get(mc, []):
				main_class = mc
				tree_key = class_id
				break
	if main_class.is_empty():
		return null
	var skills := get_skills_for_tree(main_class, tree_key)
	for skill in skills:
		if skill.skill_type == SkillDefinition.SkillType.PASSIVE:
			return skill
	return null


func get_skill_path_info(skill_id: String) -> Dictionary:
	return (_skill_path_info.get(skill_id, {}) as Dictionary).duplicate(true)


func get_skill_icon(skill_id: String) -> Texture2D:
	var resolved_skill_id := skill_id.strip_edges()
	if resolved_skill_id.is_empty():
		return null

	if _icon_cache.has(resolved_skill_id):
		return _icon_cache[resolved_skill_id] as Texture2D

	var skill = get_skill(resolved_skill_id)
	if skill != null and skill.icon != null:
		_icon_cache[resolved_skill_id] = skill.icon
		return skill.icon

	var info := get_skill_path_info(resolved_skill_id)
	if info.is_empty():
		return null

	var folder_name := str(info.get("tree_key", ""))
	if folder_name == "main":
		folder_name = str(info.get("main_class", ""))
	if folder_name.is_empty():
		return null

	var icon_path := ""
	for icon_base in _resolve_icon_base_names(resolved_skill_id):
		var candidate_path := "%s/%s/%s.png" % [SKILL_ICON_ROOT, folder_name, icon_base]
		if ResourceLoader.exists(candidate_path):
			icon_path = candidate_path
			break
	if icon_path.is_empty():
		var fallback_base := str(SKILL_ICON_FALLBACKS.get(resolved_skill_id, ""))
		if fallback_base.is_empty():
			fallback_base = "%s_icon" % folder_name
		icon_path = "%s/%s/%s.png" % [SKILL_ICON_ROOT, folder_name, fallback_base]
		if not ResourceLoader.exists(icon_path):
			return null

	var texture := load(icon_path) as Texture2D
	if skill != null:
		skill.icon = texture
	if texture != null:
		_icon_cache[resolved_skill_id] = texture
	return texture


func all_skill_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray(_skills_by_id.keys())
	ids.sort()
	return ids


func _reload_registry() -> void:
	_skills_by_id.clear()
	_skills_by_class.clear()
	_skill_path_info.clear()
	_icon_cache.clear()
	_walk_skill_directory(SKILL_ROOT)


func _walk_skill_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("SkillRegistry could not open %s" % path)
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = dir.get_next()
			continue

		var child_path := "%s/%s" % [path, entry]
		if dir.current_is_dir():
			_walk_skill_directory(child_path)
		elif entry.ends_with(".tres"):
			_register_skill_resource(child_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _register_skill_resource(resource_path: String) -> void:
	var skill = load(resource_path)
	if skill == null or skill.skill_id.is_empty():
		return

	_skills_by_id[skill.skill_id] = skill
	var info := _parse_skill_path(resource_path)
	_skill_path_info[skill.skill_id] = info

	for key in [info.get("main_class", ""), info.get("tree_key", "")]:
		var normalized_key := str(key).strip_edges().to_lower()
		if normalized_key.is_empty():
			continue
		if not _skills_by_class.has(normalized_key):
			_skills_by_class[normalized_key] = []
		_skills_by_class[normalized_key].append(skill)


func _parse_skill_path(resource_path: String) -> Dictionary:
	var normalized := resource_path.replace("\\", "/")
	var prefix := "%s/" % SKILL_ROOT
	if not normalized.begins_with(prefix):
		return {}

	var relative_path := normalized.trim_prefix(prefix)
	var segments := relative_path.split("/", false)
	if segments.size() < 3:
		return {}

	return {
		"main_class": segments[0],
		"tree_key": segments[1],
		"resource_path": resource_path,
	}


func _resolve_icon_base_names(skill_id: String) -> PackedStringArray:
	var candidates: PackedStringArray = []
	var segments := skill_id.split("_", false)
	if segments.size() > 3:
		candidates.append("_".join(segments.slice(2)))
	if SKILL_ICON_ALIASES.has(skill_id):
		candidates.append(str(SKILL_ICON_ALIASES[skill_id]))
	var legacy_base := _resolve_icon_base_name(skill_id)
	if not candidates.has(legacy_base):
		candidates.append(legacy_base)
	return candidates


func _resolve_icon_base_name(skill_id: String) -> String:
	if SKILL_ICON_ALIASES.has(skill_id):
		return str(SKILL_ICON_ALIASES[skill_id])

	var segments := skill_id.split("_", false)
	if segments.size() <= 3:
		return skill_id

	var parts: PackedStringArray = []
	for index in range(2, segments.size() - 1):
		parts.append(segments[index])
	return "_".join(parts)
