extends Control
class_name HudControlPanel

const SCORE_FORMAT := "Score: %d"
const ROUND_POPUP_FADE_IN_SEC := 0.25
const ROUND_POPUP_HOLD_SEC := 3.0
const ROUND_POPUP_FADE_OUT_SEC := 0.45

@onready var player_stats_root: Control = $PlayerStats
@onready var players_root: Control = $Players
@onready var score_label: Label = %Score
@onready var mob_count_label: Label = %MobCount
@onready var round_level_label: Label = %RoundLevelPopup
@onready var store_button: Button = %Store
@onready var skill_tree_button: Button = %SkillTree
@onready var minimap: HudMinimap = %Map
@onready var class_selection_ui: Control = $"../SoloClassSelection"
@onready var shop_ui: ShopUI = $"../ShopUI"
@onready var skill_tree_ui: SkillTreeUI = $"../SkillTreeUI"
@onready var death_screen: Control = $"../Death"
@onready var skills_root: HudSkillBar = $"../Skills" as HudSkillBar
@onready var stats_root: Control = $"../Stats"

var current_score: int = 0
var _overlay_pause_active: bool = false
var _round_popup_tween: Tween
var _block_input_when_overlay_open: bool = false


func _ready() -> void:
	if shop_ui != null:
		shop_ui.hide()
		if shop_ui.has_signal("closed") and not shop_ui.closed.is_connected(_on_overlay_closed):
			shop_ui.closed.connect(_on_overlay_closed)
	if skill_tree_ui != null:
		skill_tree_ui.hide()
		if skill_tree_ui.has_signal("closed") and not skill_tree_ui.closed.is_connected(_on_overlay_closed):
			skill_tree_ui.closed.connect(_on_overlay_closed)
	if mob_count_label != null:
		mob_count_label.text = "Mobs: 0"
	if round_level_label != null:
		round_level_label.visible = false
		round_level_label.modulate = Color(1, 1, 1, 0)
		round_level_label.scale = Vector2(0.92, 0.92)


func set_block_input_when_overlay_open(value: bool) -> void:
	_block_input_when_overlay_open = value
	_update_overlay_pause()


func add_score(amount: int) -> void:
	current_score += amount
	update_score_display()


func get_current_score() -> int:
	return current_score


func set_current_score(value: int) -> void:
	current_score = max(0, value)
	update_score_display()


func update_score_display() -> void:
	if score_label != null:
		score_label.text = SCORE_FORMAT % current_score


func update_mob_counter(current_alive: int, total_in_round: int) -> void:
	if mob_count_label == null:
		return
	mob_count_label.text = "Mobs: %d/%d" % [current_alive, total_in_round]


func show_round_level(round_number: int, added_mobs: int, profile: Dictionary) -> void:
	if round_level_label == null:
		return
	if _round_popup_tween != null and _round_popup_tween.is_valid():
		_round_popup_tween.kill()

	var growth_line := "+%d Mobs  HP +%d%%  DMG +%d%%  SPD +%d%%" % [
		added_mobs,
		int(profile.get("health_growth_pct", 0)),
		int(profile.get("damage_growth_pct", 0)),
		int(profile.get("speed_growth_pct", 0))
	]
	round_level_label.text = "Round %d\n%s" % [round_number, growth_line]
	round_level_label.visible = true
	round_level_label.modulate = Color(1, 1, 1, 0)
	round_level_label.scale = Vector2(0.92, 0.92)

	_round_popup_tween = create_tween()
	_round_popup_tween.set_trans(Tween.TRANS_CUBIC)
	_round_popup_tween.set_ease(Tween.EASE_OUT)
	_round_popup_tween.set_parallel(true)
	_round_popup_tween.tween_property(round_level_label, "modulate", Color.WHITE, ROUND_POPUP_FADE_IN_SEC)
	_round_popup_tween.tween_property(round_level_label, "scale", Vector2.ONE, ROUND_POPUP_FADE_IN_SEC)
	_round_popup_tween.chain().tween_interval(ROUND_POPUP_HOLD_SEC)
	_round_popup_tween.chain().set_parallel(true)
	_round_popup_tween.tween_property(round_level_label, "modulate", Color(1, 1, 1, 0), ROUND_POPUP_FADE_OUT_SEC)
	_round_popup_tween.tween_property(round_level_label, "scale", Vector2(1.04, 1.04), ROUND_POPUP_FADE_OUT_SEC)
	_round_popup_tween.finished.connect(_on_round_popup_finished)


func _on_round_popup_finished() -> void:
	if round_level_label != null:
		round_level_label.visible = false
	_round_popup_tween = null


func _on_store_pressed() -> void:
	toggle_shop()


func toggle_shop() -> void:
	if shop_ui == null:
		return
	if shop_ui.visible:
		shop_ui.close()
	else:
		if skill_tree_ui != null and skill_tree_ui.visible:
			skill_tree_ui.close()
		shop_ui.open()
	_update_overlay_pause()


func _on_skill_tree_pressed() -> void:
	toggle_skill_tree()


func toggle_skill_tree() -> void:
	if skill_tree_ui == null:
		return
	if skill_tree_ui.visible:
		skill_tree_ui.close()
	else:
		if shop_ui != null and shop_ui.visible:
			shop_ui.close()
		skill_tree_ui.open()
	_update_overlay_pause()


func _on_overlay_closed() -> void:
	_update_overlay_pause()


func _update_overlay_pause() -> void:
	_overlay_pause_active = _block_input_when_overlay_open and _is_overlay_open()
	var overlay_open := _is_overlay_open()
	if skills_root != null:
		skills_root.visible = not overlay_open
	if stats_root != null:
		stats_root.visible = not overlay_open
	if minimap != null:
		minimap.visible = not overlay_open


func has_blocking_overlay_open() -> bool:
	return _overlay_pause_active


func is_pointer_over_ui(pointer_position: Vector2) -> bool:
	var interactive_roots: Array[Control] = [
		player_stats_root,
		score_label,
		mob_count_label,
		round_level_label,
		players_root,
		store_button,
		skill_tree_button,
		minimap,
		class_selection_ui,
		shop_ui,
		skill_tree_ui,
		death_screen,
		skills_root,
		stats_root
	]
	for root in interactive_roots:
		if _control_tree_contains_point(root, pointer_position):
			return true
	return false


func _is_overlay_open() -> bool:
	return (shop_ui != null and shop_ui.visible) or (skill_tree_ui != null and skill_tree_ui.visible)


func _control_tree_contains_point(root: Control, pointer_position: Vector2) -> bool:
	if root == null or not is_instance_valid(root) or not root.visible:
		return false
	if _control_contains_point(root, pointer_position):
		return true
	for child in root.get_children():
		if child is Control and _control_tree_contains_point(child as Control, pointer_position):
			return true
	return false


func _control_contains_point(control: Control, pointer_position: Vector2) -> bool:
	if control == null or not is_instance_valid(control) or not control.visible:
		return false
	var global_rect := Rect2(control.global_position, control.size)
	if global_rect.size.x <= 0.0 or global_rect.size.y <= 0.0:
		return false
	return global_rect.has_point(pointer_position)
