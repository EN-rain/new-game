extends MarginContainer
class_name SkillTreeTabContent

@onready var header_label: Label = %HeaderLabel
@onready var skill_grid: Control = %SkillGrid


func _ensure_ui_refs() -> void:
	if header_label == null:
		header_label = get_node_or_null("%HeaderLabel")
	if skill_grid == null:
		skill_grid = get_node_or_null("%SkillGrid")


func set_header_text(text: String) -> void:
	_ensure_ui_refs()
	if header_label != null:
		header_label.text = text


func get_skill_grid() -> Control:
	_ensure_ui_refs()
	return skill_grid
