extends Button
class_name SkillTreeCard

signal detail_requested(skill_id: String)

@export var locked_style: StyleBoxFlat
@export var maxed_style: StyleBoxFlat
@export var selected_style: StyleBoxFlat
@export var learned_style: StyleBoxFlat
@export var default_style: StyleBoxFlat
@export var use_type_colors: bool = false

@onready var indicator: ColorRect = %Indicator
@onready var icon_frame: PanelContainer = %IconFrame
@onready var icon: TextureRect = %Icon
@onready var info_button: Button = %InfoButton
@onready var title_label: Label = %TitleLabel
@onready var level_label: Label = %LevelLabel
@onready var type_label: Label = %TypeLabel
@onready var role_label: Label = %RoleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var state_label: Label = %StateLabel

var skill_id: String = ""
var tree_key: String = ""
var _is_hovered := false
var _is_maxed := false
var _is_selected := false
var _is_learned := false
var _is_unlocked := true


func _ensure_ui_refs() -> void:
	if indicator == null:
		indicator = get_node_or_null("%Indicator")
	if icon_frame == null:
		icon_frame = get_node_or_null("%IconFrame")
	if icon == null:
		icon = get_node_or_null("%Icon")
	if info_button == null:
		info_button = get_node_or_null("%InfoButton")
	if title_label == null:
		title_label = get_node_or_null("%TitleLabel")
	if level_label == null:
		level_label = get_node_or_null("%LevelLabel")
	if type_label == null:
		type_label = get_node_or_null("%TypeLabel")
	if role_label == null:
		role_label = get_node_or_null("%RoleLabel")
	if description_label == null:
		description_label = get_node_or_null("%DescriptionLabel")
	if state_label == null:
		state_label = get_node_or_null("%StateLabel")


func _ready() -> void:
	_ensure_ui_refs()
	flat = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if info_button != null and not info_button.pressed.is_connected(_on_info_pressed):
		info_button.pressed.connect(_on_info_pressed)
	_apply_empty_button_style()
	_refresh_icon_style(false, false, false, true)


func configure(skill_definition: Resource, next_tree_key: String, role_text: String = "", skill_icon: Texture2D = null) -> void:
	if skill_definition == null:
		return
	_ensure_ui_refs()
	skill_id = str(skill_definition.skill_id)
	tree_key = next_tree_key
	if title_label != null:
		title_label.text = str(skill_definition.display_name)
	if indicator != null:
		indicator.color = SkillTreeUI.TYPE_COLORS.get(int(skill_definition.skill_type), Color.WHITE) if use_type_colors else Color.WHITE
		indicator.visible = use_type_colors
	if icon != null:
		icon.texture = skill_icon
	if type_label != null:
		type_label.text = SkillTreeUI.skill_type_to_text(int(skill_definition.skill_type))
	if role_label != null:
		role_label.text = role_text


func refresh_display(description: String, state_text: String, level: int, max_level: int, unlocked: bool, is_maxed: bool, is_selected: bool) -> void:
	_ensure_ui_refs()
	if level_label != null:
		level_label.text = "%d / %d" % [level, max_level]
	if description_label != null:
		description_label.text = description
	if state_label != null:
		state_label.text = state_text
	disabled = false
	text = ""
	_is_maxed = is_maxed
	_is_selected = is_selected
	_is_learned = level > 0
	_is_unlocked = unlocked
	tooltip_text = "%s\n%s\n%d / %d" % [state_text, description, level, max_level]
	if icon != null:
		icon.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.35)
	if title_label != null:
		title_label.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.5)
	_refresh_icon_style(_is_maxed, _is_selected, _is_learned, _is_unlocked)

	_apply_empty_button_style()


func _on_info_pressed() -> void:
	detail_requested.emit(skill_id)


func _on_mouse_entered() -> void:
	_is_hovered = true
	_refresh_icon_style(_is_maxed, _is_selected, _is_learned, _is_unlocked)


func _on_mouse_exited() -> void:
	_is_hovered = false
	_refresh_icon_style(_is_maxed, _is_selected, _is_learned, _is_unlocked)


func _apply_empty_button_style() -> void:
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, empty)


func _refresh_icon_style(is_maxed: bool, is_selected: bool, is_learned: bool, unlocked: bool) -> void:
	if icon_frame == null:
		return
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 42
	style.corner_radius_top_right = 42
	style.corner_radius_bottom_right = 42
	style.corner_radius_bottom_left = 42
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.bg_color = Color(0.08, 0.08, 0.08, 0.15)
	style.border_color = Color(0.62, 0.62, 0.62, 0.65)
	if not unlocked:
		style.border_color = Color(0.35, 0.35, 0.35, 0.45)
	elif is_selected:
		style.border_color = Color(0.45, 0.75, 1.0, 1.0)
	elif is_maxed:
		style.border_color = Color(0.95, 0.85, 0.3, 1.0)
	elif is_learned:
		style.border_color = Color(0.55, 0.9, 0.65, 0.9)
	if _is_hovered and unlocked:
		style.bg_color = Color(1, 1, 1, 0.08)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
	icon_frame.add_theme_stylebox_override("panel", style)
