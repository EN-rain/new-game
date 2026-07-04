@tool
extends Control
class_name SkillTreeUI


signal closed

const TYPE_COLORS := {
	SkillDefinition.SkillType.STAT: Color(0.34, 0.82, 0.48, 1.0),
	SkillDefinition.SkillType.ABILITY: Color(0.36, 0.66, 0.98, 1.0),
	SkillDefinition.SkillType.PASSIVE: Color(0.76, 0.46, 0.92, 1.0),
	SkillDefinition.SkillType.SPECIAL: Color(0.98, 0.72, 0.28, 1.0),
}

const TREE_TIER_ORDER := [
	SkillDefinition.SkillType.STAT,
	SkillDefinition.SkillType.ABILITY,
	SkillDefinition.SkillType.PASSIVE,
	SkillDefinition.SkillType.SPECIAL,
]

const TREE_TIER_LABELS := {
	SkillDefinition.SkillType.STAT: "Tier 1 - Core Stats",
	SkillDefinition.SkillType.ABILITY: "Tier 2 - Active Skills",
	SkillDefinition.SkillType.PASSIVE: "Tier 3 - Passive Upgrades",
	SkillDefinition.SkillType.SPECIAL: "Tier 4 - Specialization",
}

const SOLO_TREE_CARD_MIN_SIZE := Vector2(156, 176)
const SOLO_TREE_BRANCH_COUNT := 3
const SOLO_TREE_SPACING := 24

@export var skill_card_scene: PackedScene
@export var tab_content_scene: PackedScene
@export var use_custom_colors: bool = false
@export var editor_main_class_id: String = "dps"

@onready var title_label: Label = %TitleLabel
@onready var sp_label: Label = %SpLabel
@onready var apply_button: Button = %ApplyButton
@onready var status_label: Label = %StatusLabel
@onready var bonus_label: Label = %BonusLabel
@onready var tab_container: TabContainer = %Tabs
@onready var action_slot_1: Button = %ActionSlot1
@onready var action_slot_2: Button = %ActionSlot2
@onready var action_slot_3: Button = %ActionSlot3
@onready var action_slot_4: Button = %ActionSlot4
@onready var tooltip_panel: PanelContainer = %TooltipPanel
@onready var panel: Control = %Panel
@onready var tooltip_title: Label = %TooltipTitle
@onready var tooltip_body: Label = %TooltipBody
@onready var close_button: Button = %CloseButton
@onready var status_timer: Timer = %StatusTimer

var _selected_skill_id: String = ""
var _slot_buttons: Array[Button] = []
var _skill_card_refs: Dictionary = {}
var _last_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _action_bar_dirty: bool = true
var _pending_investments: Dictionary = {}


static func skill_type_to_text(skill_type: int) -> String:
	match skill_type:
		SkillDefinition.SkillType.STAT:
			return "Stat"
		SkillDefinition.SkillType.ABILITY:
			return "Ability"
		SkillDefinition.SkillType.PASSIVE:
			return "Passive"
		SkillDefinition.SkillType.SPECIAL:
			return "Special"
		_:
			return "Skill"


func _ready() -> void:
	tooltip_panel.visible = false
	if Engine.is_editor_hint():
		_refresh_all.call_deferred()
		return
	if not status_timer.timeout.is_connected(_on_status_timeout):
		status_timer.timeout.connect(_on_status_timeout)
	_setup_action_bar()
	_connect_signals()
	_refresh_all()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if visible:
		_refresh_action_bar_if_needed()


func open() -> void:
	_pending_investments.clear()
	_action_bar_dirty = true
	_selected_skill_id = ""
	for i in range(4):
		_last_cooldowns[i] = 0.0
	_refresh_all()
	show()
	if close_button != null:
		close_button.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	_pending_investments.clear()
	_selected_skill_id = ""
	hide()
	tooltip_panel.visible = false
	closed.emit()


func _on_close_pressed() -> void:
	close()


func _on_apply_pressed() -> void:
	var manager = _skill_tree_manager()
	var registry = _skill_registry()
	if manager == null or registry == null or _pending_investments.is_empty():
		return

	var pending_ids: Array[String] = []
	for skill_id_variant in _pending_investments.keys():
		var skill_id := str(skill_id_variant)
		for _i in range(int(_pending_investments.get(skill_id, 0))):
			pending_ids.append(skill_id)

	pending_ids.sort_custom(func(a: String, b: String) -> bool:
		var a_info: Dictionary = registry.get_skill_path_info(a)
		var b_info: Dictionary = registry.get_skill_path_info(b)
		var a_tree := str(a_info.get("tree_key", ""))
		var b_tree := str(b_info.get("tree_key", ""))
		if a_tree == b_tree:
			return a < b
		if a_tree == "main":
			return true
		if b_tree == "main":
			return false
		return a_tree < b_tree
	)

	var applied_points := 0
	for skill_id in pending_ids:
		if bool(manager.call("invest_sp", skill_id)):
			applied_points += 1

	_pending_investments.clear()
	_refresh_all()
	if applied_points > 0:
		_show_status("Applied %d pending SP." % applied_points, Color(0.62, 0.92, 0.72, 1.0))


func _gui_input(_event: InputEvent) -> void:
	pass


func _connect_signals() -> void:
	if Engine.is_editor_hint():
		return
	var manager = _skill_tree_manager()
	if manager == null:
		return
	if not manager.sp_changed.is_connected(_on_sp_changed):
		manager.sp_changed.connect(_on_sp_changed)
	if not manager.skill_invested.is_connected(_on_skill_invested):
		manager.skill_invested.connect(_on_skill_invested)
	if not manager.subclasses_unlocked.is_connected(_on_subclasses_unlocked):
		manager.subclasses_unlocked.connect(_on_subclasses_unlocked)
	if not manager.subclass_locked.is_connected(_on_subclass_locked):
		manager.subclass_locked.connect(_on_subclass_locked)
	if not manager.insufficient_sp.is_connected(_on_insufficient_sp):
		manager.insufficient_sp.connect(_on_insufficient_sp)
	if not manager.skill_not_learned.is_connected(_on_skill_not_learned):
		manager.skill_not_learned.connect(_on_skill_not_learned)


func _setup_action_bar() -> void:
	if Engine.is_editor_hint():
		return
	_slot_buttons = [action_slot_1, action_slot_2, action_slot_3, action_slot_4]
	for slot_index in range(_slot_buttons.size()):
		var button := _slot_buttons[slot_index]
		if button == null:
			continue
		if not button.pressed.is_connected(_on_action_slot_pressed.bind(slot_index)):
			button.pressed.connect(_on_action_slot_pressed.bind(slot_index))


func _refresh_all() -> void:
	title_label.text = "SKILL TREE"
	_refresh_sp_label()
	_refresh_apply_button()
	_refresh_bonus_label()
	_refresh_tabs()
	_refresh_action_bar()


func _refresh_sp_label() -> void:
	if Engine.is_editor_hint():
		sp_label.text = "SP 0 / 0"
		return
	var manager = _skill_tree_manager()
	sp_label.text = "SP %d / %d" % [_get_effective_sp_available(), manager.get_total_sp_earned()] if manager != null else "SP 0 / 0"


func _refresh_apply_button() -> void:
	if apply_button == null:
		return
	if Engine.is_editor_hint():
		apply_button.disabled = true
		apply_button.text = "Apply"
		return
	var pending_points := _get_pending_point_count()
	apply_button.disabled = pending_points <= 0
	apply_button.text = "Apply" if pending_points <= 0 else "Apply (%d)" % pending_points


func _refresh_bonus_label() -> void:
	if bonus_label == null:
		return
	if Engine.is_editor_hint():
		bonus_label.text = ""
		return
	var player_subclass: PlayerClass = MultiplayerManager.player_subclass
	bonus_label.text = "" if player_subclass == null else _build_class_bonus_summary(player_subclass)


func _refresh_tabs() -> void:
	var previous_tab := tab_container.current_tab
	for child in tab_container.get_children():
		child.queue_free()
	_skill_card_refs.clear()

	var main_class_id := ""
	if Engine.is_editor_hint():
		main_class_id = editor_main_class_id.strip_edges().to_lower()
		if main_class_id.is_empty():
			main_class_id = "dps"
	else:
		var main_class: PlayerClass = MultiplayerManager.player_class
		if main_class != null:
			main_class_id = ClassManager.get_class_id(main_class)
	if main_class_id.is_empty():
		var empty_tab := _instantiate_tab_content()
		if empty_tab == null:
			return
		_set_tab_header_text(empty_tab, "Select a main class to unlock the skill tree.")
		tab_container.add_child(empty_tab)
		tab_container.set_tab_title(0, "Unavailable")
		return

	_add_tree_tab("Main", main_class_id, "main")
	for subclass_id in _get_subclass_ids_for_main_id(main_class_id):
		_add_tree_tab(_class_id_to_display_name(subclass_id), main_class_id, subclass_id)
	if tab_container.get_tab_count() > 0:
		tab_container.current_tab = clampi(previous_tab, 0, tab_container.get_tab_count() - 1)


func _add_tree_tab(tab_name: String, main_class_id: String, tree_key: String) -> void:
	var root := _instantiate_tab_content()
	if root == null:
		return
	_set_tab_header_text(root, _build_tab_header_text(tree_key))
	var grid := _get_tab_skill_grid(root)
	if grid == null:
		root.queue_free()
		return

	var skills = _get_skills_for_tree(main_class_id, tree_key)
	if use_custom_colors:
		for skill in skills:
			var card := _create_skill_card(skill, tree_key)
			if card != null:
				grid.add_child(card)
	else:
		_populate_tiered_tree(grid, skills, tree_key)

	tab_container.add_child(root)
	tab_container.set_tab_title(tab_container.get_tab_count() - 1, tab_name)


func _instantiate_tab_content() -> Control:
	if tab_content_scene == null:
		push_warning("[SkillTreeUI] tab_content_scene is not assigned.")
		return null
	var content := tab_content_scene.instantiate() as Control
	if content == null:
		push_warning("[SkillTreeUI] Failed to instantiate tab content.")
		return null
	return content


func _set_tab_header_text(tab_content: Control, text: String) -> void:
	if tab_content == null:
		return
	if Engine.is_editor_hint():
		var header_label := tab_content.get_node_or_null("%HeaderLabel") as Label
		if header_label != null:
			header_label.text = text
		return
	if tab_content.has_method("set_header_text"):
		tab_content.call("set_header_text", text)


func _get_tab_skill_grid(tab_content: Control) -> Control:
	if tab_content == null:
		return null
	if Engine.is_editor_hint():
		return tab_content.get_node_or_null("%SkillGrid") as Control
	if tab_content.has_method("get_skill_grid"):
		return tab_content.call("get_skill_grid") as Control
	return null


func _populate_tiered_tree(container: Control, skills: Array, tree_key: String) -> void:
	if container == null:
		return
	var grouped := _group_skills_by_tier(skills)
	var stats: Array = grouped.get(SkillDefinition.SkillType.STAT, [])
	var abilities: Array = grouped.get(SkillDefinition.SkillType.ABILITY, [])
	var passives: Array = grouped.get(SkillDefinition.SkillType.PASSIVE, [])
	var specials: Array = grouped.get(SkillDefinition.SkillType.SPECIAL, [])

	container.add_child(_create_tree_tier_label("Class Root"))
	_add_scroll_row(container, stats.slice(0, min(SOLO_TREE_BRANCH_COUNT, stats.size())), tree_key)
	container.add_child(_create_tree_connector())

	var branch_row := HBoxContainer.new()
	branch_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	branch_row.alignment = BoxContainer.ALIGNMENT_CENTER
	branch_row.add_theme_constant_override("separation", SOLO_TREE_SPACING)
	for branch_index in range(SOLO_TREE_BRANCH_COUNT):
		var branch := VBoxContainer.new()
		branch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		branch.custom_minimum_size = Vector2(SOLO_TREE_CARD_MIN_SIZE.x, 0)
		branch.alignment = BoxContainer.ALIGNMENT_BEGIN
		branch.add_theme_constant_override("separation", SOLO_TREE_SPACING)
		branch.add_child(_create_tree_tier_label(_get_branch_label(branch_index)))
		_add_branch_skills(branch, stats, branch_index, tree_key, SOLO_TREE_BRANCH_COUNT)
		_add_branch_skills(branch, abilities, branch_index, tree_key, SOLO_TREE_BRANCH_COUNT)
		_add_branch_skills(branch, passives, branch_index, tree_key, SOLO_TREE_BRANCH_COUNT)
		branch_row.add_child(branch)
	container.add_child(branch_row)

	if not specials.is_empty():
		container.add_child(_create_tree_connector())
		container.add_child(_create_tree_tier_label("Capstone Skills"))
		_add_scroll_row(container, specials, tree_key)


func _add_branch_skills(branch: VBoxContainer, skills: Array, branch_index: int, tree_key: String, branch_count: int) -> void:
	var added := false
	for skill_index in range(skills.size()):
		if skill_index % branch_count != branch_index:
			continue
		if branch.get_child_count() > 1 or added:
			branch.add_child(_create_tree_connector())
		var card := _create_skill_card(skills[skill_index], tree_key)
		if card != null:
			card.custom_minimum_size = SOLO_TREE_CARD_MIN_SIZE
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			branch.add_child(card)
			added = true


func _add_scroll_row(container: Control, skills: Array, tree_key: String) -> void:
	if skills.is_empty():
		return
	var scroller := ScrollContainer.new()
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.custom_minimum_size = Vector2(0, SOLO_TREE_CARD_MIN_SIZE.y + 24.0)
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", SOLO_TREE_SPACING)
	for skill in skills:
		var card := _create_skill_card(skill, tree_key)
		if card != null:
			card.custom_minimum_size = SOLO_TREE_CARD_MIN_SIZE
			card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			row.add_child(card)
	scroller.add_child(row)
	container.add_child(scroller)


func _group_skills_by_tier(skills: Array) -> Dictionary:
	var grouped := {}
	for tier_type in TREE_TIER_ORDER:
		grouped[tier_type] = []
	for skill in skills:
		if skill == null:
			continue
		var skill_type := int(skill.skill_type)
		if not grouped.has(skill_type):
			grouped[skill_type] = []
		grouped[skill_type].append(skill)
	for tier_type in grouped.keys():
		var tier_skills: Array = grouped[tier_type]
		tier_skills.sort_custom(func(a, b) -> bool:
			return str(a.display_name).nocasecmp_to(str(b.display_name)) < 0
		)
	return grouped


func _create_tree_tier_label(label_text: Variant) -> Label:
	var label := Label.new()
	label.text = str(TREE_TIER_LABELS.get(label_text, label_text))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _create_tree_connector() -> Label:
	var label := Label.new()
	label.text = "|"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _get_branch_label(branch_index: int) -> String:
	match branch_index:
		0:
			return "Damage Branch"
		1:
			return "Survival Branch"
		2:
			return "Utility Branch"
		_:
			return "Branch"


func _build_tab_header_text(tree_key: String) -> String:
	if Engine.is_editor_hint():
		if tree_key == "main":
			return "Spend 20 SP in the main tree to unlock subclass tabs. [0 / 20]"
		return "%s tree locked until 20 SP are invested in the main tree." % _class_id_to_display_name(tree_key)
	if tree_key == "main":
		return "Spend 20 SP in the main tree to unlock subclass tabs. [%d / %d]" % [_get_effective_main_tree_sp_spent(), 20]
	var spent := _get_effective_subclass_sp_spent(tree_key)
	if _are_subclasses_effectively_unlocked():
		return "%s tree unlocked. %d / 30 SP invested." % [_class_id_to_display_name(tree_key), spent]
	return "%s tree locked until 20 SP are invested in the main tree." % _class_id_to_display_name(tree_key)


func _create_skill_card(skill, tree_key: String) -> Control:
	if skill_card_scene == null:
		push_warning("[SkillTreeUI] skill_card_scene is not assigned.")
		return null
	var card := skill_card_scene.instantiate() as SkillTreeCard
	if card == null:
		push_warning("[SkillTreeUI] Failed to instantiate SkillTreeCard.")
		return null
	card.use_type_colors = use_custom_colors
	var registry = _skill_registry()
	var skill_icon: Texture2D = null
	if registry != null:
		skill_icon = registry.get_skill_icon(skill.skill_id) as Texture2D
	if skill_icon == null and Engine.is_editor_hint():
		skill_icon = _load_editor_skill_icon(skill)
	card.configure(skill, tree_key, _build_skill_role_text(skill), skill_icon)
	if not Engine.is_editor_hint():
		card.pressed.connect(_on_skill_card_pressed.bind(skill.skill_id))

	_skill_card_refs[skill.skill_id] = {
		"card": card,
		"tree_key": tree_key,
	}
	if Engine.is_editor_hint():
		card.refresh_display(_summarize_skill(skill, 0), "Unlearned", 0, skill.max_level, true, false, false)
	else:
		_refresh_skill_card(skill.skill_id)
	return card


func _refresh_skill_card(skill_id: String) -> void:
	if not _skill_card_refs.has(skill_id):
		return
	var manager = _skill_tree_manager()
	var registry = _skill_registry()
	if manager == null or registry == null:
		return
	var refs: Dictionary = _skill_card_refs[skill_id]
	var skill = registry.get_skill(skill_id)
	if skill == null:
		return

	var committed_level := int(manager.call("get_skill_level", skill_id))
	var pending_level := int(_pending_investments.get(skill_id, 0))
	var level := committed_level + pending_level
	var is_subclass_tree := str(refs.get("tree_key", "")) != "main"
	var unlocked := not is_subclass_tree or _are_subclasses_effectively_unlocked()
	var slottable := _is_skill_effectively_slottable(skill_id)

	var card: SkillTreeCard = refs["card"]
	card.refresh_display(
		_summarize_skill(skill, level),
		_build_skill_state_text(skill, level, pending_level, slottable, unlocked),
		level,
		skill.max_level,
		unlocked,
		level >= skill.max_level,
		_selected_skill_id == skill_id
	)


func _build_skill_state_text(skill, level: int, pending_level: int, slottable: bool, unlocked: bool) -> String:
	if not unlocked:
		return "Locked"
	if level >= skill.max_level:
		return "Maxed" if pending_level <= 0 else "Maxed | Pending"
	if pending_level > 0:
		return "Pending +%d" % pending_level
	if slottable and (skill.skill_type == SkillDefinition.SkillType.ABILITY or skill.skill_type == SkillDefinition.SkillType.SPECIAL):
		return "Ready to slot"
	if level > 0:
		return "Learned"
	return "Unlearned"


func _summarize_skill(skill, level: int) -> String:
	var description: String = str(skill.get_description(max(level, 1)))
	var lines: PackedStringArray = description.split("\n", false)
	return lines[0] if not lines.is_empty() else description


func _show_tooltip(skill_id: String) -> void:
	var registry = _skill_registry()
	if registry == null:
		return
	var skill = registry.get_skill(skill_id)
	if skill == null:
		return
	var level := _get_effective_skill_level(skill_id)
	var current_text: String = str(skill.get_description(max(level, 1)))
	var next_text: String = "Max rank reached." if level >= skill.max_level else str(skill.get_description(level + 1))
	tooltip_title.text = "%s  [%d / %d]" % [skill.display_name, level, skill.max_level]
	tooltip_body.text = "Current\n%s\n\nNext\n%s" % [current_text, next_text]
	tooltip_panel.visible = true
	call_deferred("_position_tooltip_for_skill", skill_id)


func _hide_tooltip() -> void:
	tooltip_panel.visible = false


func _position_tooltip_for_skill(skill_id: String) -> void:
	if not tooltip_panel.visible or not _skill_card_refs.has(skill_id):
		return
	var refs: Dictionary = _skill_card_refs[skill_id]
	var card := refs.get("card") as Control
	if card == null or not is_instance_valid(card):
		return
	var card_rect := card.get_global_rect()
	var clamp_rect := panel.get_global_rect() if panel != null else Rect2(Vector2.ZERO, get_viewport_rect().size)
	var popup_size := tooltip_panel.get_combined_minimum_size()
	var right_space := clamp_rect.end.x - card_rect.end.x
	var left_space := card_rect.position.x - clamp_rect.position.x
	var next_x := card_rect.end.x + 16.0
	if right_space < popup_size.x + 16.0 and left_space > right_space:
		next_x = card_rect.position.x - popup_size.x - 16.0
	next_x = clampf(next_x, clamp_rect.position.x + 12.0, maxf(clamp_rect.position.x + 12.0, clamp_rect.end.x - popup_size.x - 12.0))
	var next_y := clampf(card_rect.position.y, clamp_rect.position.y + 12.0, maxf(clamp_rect.position.y + 12.0, clamp_rect.end.y - popup_size.y - 12.0))
	tooltip_panel.position = Vector2(next_x, next_y)


func _refresh_action_bar() -> void:
	_action_bar_dirty = true


func _refresh_action_bar_if_needed() -> void:
	var manager = _skill_tree_manager()
	var registry = _skill_registry()
	if manager == null:
		return

	var cooldowns_changed := false
	for slot_index in range(_slot_buttons.size()):
		var cooldown := PlayerSkillManager.get_ability_cooldown_remaining(slot_index)
		if cooldown != _last_cooldowns[slot_index]:
			_last_cooldowns[slot_index] = cooldown
			cooldowns_changed = true

	if not _action_bar_dirty and not cooldowns_changed:
		return
	_action_bar_dirty = false

	for slot_index in range(_slot_buttons.size()):
		var button := _slot_buttons[slot_index]
		var skill_id := str(manager.call("get_slotted_skill", slot_index))
		if skill_id.is_empty():
			button.text = "Slot %d\nEmpty" % (slot_index + 1)
			continue
		var skill = registry.get_skill(skill_id) if registry != null else null
		var cooldown := _last_cooldowns[slot_index]
		button.text = "Slot %d\n%s\n%s" % [
			slot_index + 1,
			skill.display_name if skill != null else skill_id,
			"%.1fs" % cooldown if cooldown > 0.0 else "Ready"
		]


func _on_skill_card_pressed(skill_id: String) -> void:
	var registry = _skill_registry()
	if registry == null:
		return
	var skill = registry.get_skill(skill_id)
	if skill == null:
		return
	var refs: Dictionary = _skill_card_refs.get(skill_id, {})
	var tree_key := str(refs.get("tree_key", ""))
	if tree_key != "main" and not _are_subclasses_effectively_unlocked():
		_show_status("%s is still locked." % _class_id_to_display_name(tree_key), Color(1, 0.55, 0.45, 1.0))
		return

	if _can_stage_invest(skill):
		_stage_invest(skill)
		return

	if skill.skill_type != SkillDefinition.SkillType.ABILITY and skill.skill_type != SkillDefinition.SkillType.SPECIAL:
		return
	if not _is_skill_effectively_slottable(skill_id):
		_show_status("Learn the skill before slotting it.", Color(1, 0.6, 0.45, 1.0))
		return
	_selected_skill_id = "" if _selected_skill_id == skill_id else skill_id
	for key in _skill_card_refs.keys():
		_refresh_skill_card(str(key))
	_show_status("Selected %s for slotting." % skill.display_name, Color(0.65, 0.85, 1.0, 1.0))


func _on_action_slot_pressed(slot_index: int) -> void:
	var manager = _skill_tree_manager()
	var registry = _skill_registry()
	if manager == null:
		return
	if not _selected_skill_id.is_empty():
		if bool(manager.call("slot_ability", slot_index, _selected_skill_id)):
			var skill = registry.get_skill(_selected_skill_id) if registry != null else null
			_show_status("Slotted %s into slot %d." % [skill.display_name if skill != null else _selected_skill_id, slot_index + 1], Color(0.65, 0.85, 1.0, 1.0))
			_selected_skill_id = ""
			for key in _skill_card_refs.keys():
				_refresh_skill_card(str(key))
			_action_bar_dirty = true
		return
	if not str(manager.call("get_slotted_skill", slot_index)).is_empty():
		manager.call("clear_slot", slot_index)
		_show_status("Cleared slot %d." % (slot_index + 1), Color(1, 0.8, 0.55, 1.0))
	_action_bar_dirty = true


func _show_status(message: String, color: Color) -> void:
	status_label.text = message
	status_label.modulate = color if use_custom_colors else Color.WHITE
	status_timer.start()


func _on_status_timeout() -> void:
	status_label.text = ""


func _on_sp_changed(_available: int, _total: int) -> void:
	_refresh_sp_label()
	_refresh_apply_button()
	_refresh_bonus_label()
	for skill_id in _skill_card_refs.keys():
		_refresh_skill_card(str(skill_id))


func _on_skill_invested(skill_id: String, _new_level: int) -> void:
	_refresh_sp_label()
	_refresh_apply_button()
	_refresh_bonus_label()
	if _skill_card_refs.has(skill_id):
		_refresh_skill_card(skill_id)
	_action_bar_dirty = true


func _on_subclasses_unlocked(_main_class: String) -> void:
	_show_status("Subclass trees unlocked.", Color(0.85, 0.95, 0.55, 1.0))
	_refresh_bonus_label()
	_refresh_tabs()


func _on_subclass_locked(subclass_key: String, reason: String) -> void:
	var class_display_name := _class_id_to_display_name(subclass_key)
	_show_status("%s reached its 30 SP cap." % class_display_name if reason == "subclass_cap_reached" else "%s is still locked." % class_display_name, Color(1, 0.55, 0.45, 1.0))


func _on_insufficient_sp(required: int, available: int) -> void:
	_show_status("Need %d SP, only %d available." % [required, available], Color(1, 0.55, 0.45, 1.0))


func _on_skill_not_learned(skill_id: String) -> void:
	var registry = _skill_registry()
	var skill = registry.get_skill(skill_id) if registry != null else null
	_show_status("%s is not available for slotting." % (skill.display_name if skill != null else skill_id), Color(1, 0.55, 0.45, 1.0))


func _skill_tree_manager() -> Node:
	if Engine.is_editor_hint():
		return null
	return SkillTreeManager


func _skill_registry() -> Node:
	if Engine.is_editor_hint():
		return null
	return SkillRegistry


func _get_skills_for_tree(main_class_id: String, tree_key: String) -> Array:
	if Engine.is_editor_hint():
		return _load_editor_skills_for_tree(main_class_id, tree_key)
	var registry = _skill_registry()
	return registry.get_skills_for_tree(main_class_id, tree_key) if registry != null else []


func _load_editor_skills_for_tree(main_class_id: String, tree_key: String) -> Array:
	var skill_dir := "res://resources/skills/%s/%s" % [main_class_id, tree_key]
	var dir := DirAccess.open(skill_dir)
	if dir == null:
		return []
	var skills: Array = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry.ends_with(".tres"):
			var skill = load("%s/%s" % [skill_dir, entry])
			if skill != null:
				skills.append(skill)
		entry = dir.get_next()
	dir.list_dir_end()
	skills.sort_custom(func(a, b) -> bool:
		return str(a.skill_id) < str(b.skill_id)
	)
	return skills


func _load_editor_skill_icon(skill) -> Texture2D:
	if skill == null:
		return null
	var skill_id := str(skill.skill_id)
	var parts := skill_id.split("_", false)
	if parts.size() < 4:
		return null
	var folder_name := parts[0]
	var resource_path := str(skill.resource_path).replace("\\", "/")
	var path_segments := resource_path.split("/", false)
	var skills_index := path_segments.find("skills")
	if skills_index >= 0 and path_segments.size() > skills_index + 2:
		var tree_key := str(path_segments[skills_index + 2])
		folder_name = parts[0] if tree_key == "main" else tree_key
	var icon_base := "_".join(parts.slice(2))
	var icon_path := "res://assets/class_icons/%s/%s.png" % [folder_name, icon_base]
	if ResourceLoader.exists(icon_path):
		return load(icon_path) as Texture2D
	return null


func _get_subclass_ids_for_main_id(main_class_id: String) -> Array:
	if Engine.is_editor_hint():
		match main_class_id:
			"tank":
				return ["guardian", "berserker", "paladin"]
			"dps":
				return ["assassin", "ranger", "mage", "samurai"]
			"support":
				return ["cleric", "bard", "alchemist", "necromancer"]
			"hybrid":
				return ["spellblade", "shadow_knight", "monk"]
			"controller":
				return ["chronomancer", "warden", "hexbinder", "stormcaller"]
			_:
				return []
	return ClassManager.get_subclass_ids_for_main_id(main_class_id)


func _class_id_to_display_name(class_id: String) -> String:
	if Engine.is_editor_hint():
		match class_id:
			"tank":
				return "Tank"
			"dps":
				return "DPS"
			"support":
				return "Support"
			"hybrid":
				return "Hybrid"
			"controller":
				return "Controller"
			"guardian":
				return "Guardian"
			"berserker":
				return "Berserker"
			"paladin":
				return "Paladin"
			"assassin":
				return "Assassin"
			"ranger":
				return "Ranger"
			"mage":
				return "Mage"
			"samurai":
				return "Samurai"
			"cleric":
				return "Cleric"
			"bard":
				return "Bard"
			"alchemist":
				return "Alchemist"
			"necromancer":
				return "Necromancer"
			"spellblade":
				return "Spellblade"
			"shadow_knight":
				return "Shadow Knight"
			"monk":
				return "Monk"
			"chronomancer":
				return "Chronomancer"
			"warden":
				return "Warden"
			"hexbinder":
				return "Hexbinder"
			"stormcaller":
				return "Stormcaller"
			_:
				return class_id.capitalize()
	return ClassManager.class_id_to_display_name(class_id)


func _get_pending_point_count() -> int:
	var total := 0
	for value in _pending_investments.values():
		total += int(value)
	return total


func _get_effective_sp_available() -> int:
	var manager = _skill_tree_manager()
	return 0 if manager == null else int(manager.get_sp_available()) - _get_pending_point_count()


func _get_effective_skill_level(skill_id: String) -> int:
	var manager = _skill_tree_manager()
	return 0 if manager == null else int(manager.call("get_skill_level", skill_id)) + int(_pending_investments.get(skill_id, 0))


func _get_effective_main_tree_sp_spent() -> int:
	var manager = _skill_tree_manager()
	if manager == null:
		return 0
	var total := int(manager.call("get_main_tree_sp_spent"))
	var registry = _skill_registry()
	if registry == null:
		return total
	for skill_id_variant in _pending_investments.keys():
		var skill_id := str(skill_id_variant)
		var info: Dictionary = registry.get_skill_path_info(skill_id)
		if str(info.get("tree_key", "")) == "main":
			total += int(_pending_investments[skill_id])
	return total


func _get_effective_subclass_sp_spent(tree_key: String) -> int:
	var manager = _skill_tree_manager()
	if manager == null:
		return 0
	var total := int(manager.call("get_subclass_sp_spent", tree_key))
	var registry = _skill_registry()
	if registry == null:
		return total
	for skill_id_variant in _pending_investments.keys():
		var skill_id := str(skill_id_variant)
		var info: Dictionary = registry.get_skill_path_info(skill_id)
		if str(info.get("tree_key", "")) == tree_key:
			total += int(_pending_investments[skill_id])
	return total


func _are_subclasses_effectively_unlocked() -> bool:
	return _get_effective_main_tree_sp_spent() >= 20


func _is_skill_effectively_slottable(skill_id: String) -> bool:
	var registry = _skill_registry()
	if registry == null:
		return false
	var skill = registry.get_skill(skill_id)
	if skill == null:
		return false
	if skill.skill_type != SkillDefinition.SkillType.ABILITY and skill.skill_type != SkillDefinition.SkillType.SPECIAL:
		return false
	return _get_effective_skill_level(skill_id) > 0


func _can_stage_invest(skill) -> bool:
	if skill == null:
		return false
	var current_level := _get_effective_skill_level(skill.skill_id)
	if current_level >= skill.max_level:
		return false
	if _get_effective_sp_available() < int(skill.sp_cost_per_level):
		return false
	var registry = _skill_registry()
	if registry == null:
		return false
	var info: Dictionary = registry.get_skill_path_info(skill.skill_id)
	if info.is_empty():
		return false
	var tree_key := str(info.get("tree_key", ""))
	if tree_key != "main":
		if not _are_subclasses_effectively_unlocked():
			return false
		if _get_effective_subclass_sp_spent(tree_key) >= 30:
			return false
	return true


func _stage_invest(skill) -> void:
	_pending_investments[skill.skill_id] = int(_pending_investments.get(skill.skill_id, 0)) + 1
	_refresh_sp_label()
	_refresh_apply_button()
	_refresh_tabs()
	_show_status("Queued %s." % skill.display_name, Color(0.62, 0.92, 0.72, 1.0))


func _build_skill_role_text(skill) -> String:
	var tags: Array[String] = []
	var skill_id := str(skill.skill_id)
	var stat_rule: Dictionary = SkillTreeRuntimeData.STAT_RULES.get(skill_id, {})
	var passive_rule: Dictionary = SkillTreeRuntimeData.PASSIVE_RULES.get(skill_id, {})
	var target_key := ""
	if not stat_rule.is_empty():
		target_key = str(stat_rule.get("target", ""))
	if target_key.is_empty() and not passive_rule.is_empty():
		target_key = str(passive_rule.get("target", ""))
	var description := str(skill.description_template).to_lower()
	var merged_text := "%s %s" % [target_key.to_lower(), description]

	if "debuff" in merged_text or "slow" in merged_text or "curse" in merged_text or "stun" in merged_text or "poison" in merged_text or "bleed" in merged_text or "reducing armor" in merged_text:
		tags.append("Debuff")
	elif "buff" in merged_text or "heal" in merged_text or "shield" in merged_text or "regen" in merged_text:
		tags.append("Buff")

	if "max_health" in merged_text or " hp" in merged_text or "healing" in merged_text:
		if not tags.has("HP"):
			tags.append("HP")
	elif "defense" in merged_text or "armor" in merged_text or "block" in merged_text or "barrier" in merged_text:
		if not tags.has("Defense"):
			tags.append("Defense")
	elif "attack_damage" in merged_text or "damage" in merged_text or "crit" in merged_text:
		if not tags.has("Attack"):
			tags.append("Attack")

	return " | ".join(tags.slice(0, 2))


func _build_class_bonus_summary(player_class: PlayerClass) -> String:
	var parts: Array[String] = []
	_append_class_bonus(parts, "HP", player_class.modifiers_hp)
	_append_class_bonus(parts, "DMG", player_class.modifiers_damage)
	_append_class_bonus(parts, "DEF", player_class.modifiers_defense)
	_append_class_bonus(parts, "SPD", player_class.modifiers_speed)
	_append_class_bonus(parts, "ATK SPD", player_class.modifiers_attack_speed)
	_append_class_bonus(parts, "CRIT", player_class.modifiers_crit_chance)
	_append_class_bonus(parts, "CRIT DMG", player_class.modifiers_crit_damage)
	return "" if parts.is_empty() else "%s Bonus: %s" % [player_class.display_name, " | ".join(parts)]


func _append_class_bonus(parts: Array[String], label: String, modifier: float) -> void:
	if is_equal_approx(modifier, 1.0):
		return
	parts.append("%s %+.0f%%" % [label, (modifier - 1.0) * 100.0])
