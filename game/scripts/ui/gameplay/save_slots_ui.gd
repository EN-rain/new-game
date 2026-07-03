extends Control

## Save Slots UI - 5 cloud slots with solo/multiplayer indicator, rename support

signal slot_loaded(slot: int)
signal closed()

@onready var slot_container: VBoxContainer = %SlotContainer
@onready var close_button: Button = %CloseButton
@onready var status_label: Label = %StatusLabel

var _busy: bool = false


func _ready() -> void:
	_refresh_slots()


func _refresh_slots() -> void:
	for child in slot_container.get_children():
		child.queue_free()
	if not MultiplayerManager.is_authenticated():
		_set_status("Login required for cloud saves", Color(0.9, 0.4, 0.4))
		return
	_set_status("Loading save slots...", Color(0.55, 0.75, 0.95))
	_refresh_async.call_deferred()


func _refresh_async() -> void:
	_busy = true
	var result = await CloudSaveManager.load_slots()
	_busy = false
	if not result.get("success", false):
		_set_status("Failed to load: %s" % str(result.get("error", "")), Color(0.9, 0.4, 0.4))
		return
	var summaries: Array = CloudSaveManager.get_all_slot_summaries()
	for i in range(summaries.size()):
		var summary: Dictionary = summaries[i]
		var card := _create_slot_card(i + 1, summary)
		slot_container.add_child(card)
	_set_status("Select a slot to save or load", Color(0.6, 0.7, 0.8))


func _create_slot_card(slot_num: int, summary: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 72)

	var is_empty := summary.is_empty()
	var mode: String = str(summary.get("mode", "solo")) if not is_empty else ""

	var style := StyleBoxFlat.new()
	if is_empty:
		style.bg_color = Color(0.06, 0.05, 0.09, 0.7)
		style.border_color = Color(0.25, 0.22, 0.3, 0.4)
	elif mode == "multiplayer":
		style.bg_color = Color(0.06, 0.08, 0.14, 0.9)
		style.border_color = Color(0.2, 0.35, 0.6, 0.7)
	else:
		style.bg_color = Color(0.08, 0.07, 0.12, 0.9)
		style.border_color = Color(0.35, 0.3, 0.2, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_top = 6
	style.content_margin_right = 10
	style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)

	# Slot name (renamable)
	var slot_label := Label.new()
	var display_name: String = str(summary.get("slot_name", "Slot %d" % slot_num))
	if display_name.is_empty():
		display_name = "Slot %d" % slot_num
	slot_label.text = display_name
	slot_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35, 1))
	slot_label.add_theme_font_size_override("font_size", 15)
	slot_label.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(slot_label)

	# Mode badge (Solo / Multi)
	if not is_empty:
		var badge := Label.new()
		if mode == "multiplayer":
			badge.text = "[MP]"
			badge.add_theme_color_override("font_color", Color(0.4, 0.65, 1, 1))
		else:
			badge.text = "[Solo]"
			badge.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3, 1))
		badge.add_theme_font_size_override("font_size", 11)
		badge.custom_minimum_size = Vector2(50, 0)
		hbox.add_child(badge)

	# Info section
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 1)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	if is_empty:
		var empty_label := Label.new()
		empty_label.text = "Empty Slot"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 0.7))
		empty_label.add_theme_font_size_override("font_size", 13)
		info_vbox.add_child(empty_label)
	else:
		var class_level := Label.new()
		class_level.text = "%s  Lv.%d  Round %d" % [
			str(summary.get("class_name", "-")),
			int(summary.get("level", 1)),
			int(summary.get("round", 1))
		]
		class_level.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
		class_level.add_theme_font_size_override("font_size", 13)
		info_vbox.add_child(class_level)

		var detail := Label.new()
		var coins := int(summary.get("coins", 0))
		var saved_at := str(summary.get("saved_at", ""))
		detail.text = "Coins: %d  |  %s" % [coins, saved_at]
		detail.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 0.85))
		detail.add_theme_font_size_override("font_size", 10)
		info_vbox.add_child(detail)

	# Buttons
	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 4)
	btn_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(btn_box)

	# Save Solo button
	var save_solo_btn := Button.new()
	save_solo_btn.text = "Save Solo"
	save_solo_btn.add_theme_font_size_override("font_size", 11)
	save_solo_btn.tooltip_text = "Save as solo run"
	save_solo_btn.pressed.connect(_on_save_slot.bind(slot_num, "solo"))
	btn_box.add_child(save_solo_btn)

	# Save Multi button
	var save_multi_btn := Button.new()
	save_multi_btn.text = "Save MP"
	save_multi_btn.add_theme_font_size_override("font_size", 11)
	save_multi_btn.tooltip_text = "Save as multiplayer run"
	save_multi_btn.pressed.connect(_on_save_slot.bind(slot_num, "multiplayer"))
	btn_box.add_child(save_multi_btn)

	if not is_empty:
		# Load button
		var load_btn := Button.new()
		load_btn.text = "Load"
		load_btn.add_theme_font_size_override("font_size", 12)
		load_btn.tooltip_text = "Load save from this slot"
		load_btn.pressed.connect(_on_load_slot.bind(slot_num))
		btn_box.add_child(load_btn)

		# Rename button
		var rename_btn := Button.new()
		rename_btn.text = "Rename"
		rename_btn.add_theme_font_size_override("font_size", 12)
		rename_btn.tooltip_text = "Rename this slot"
		rename_btn.pressed.connect(_on_rename_slot.bind(slot_num))
		btn_box.add_child(rename_btn)

		# Delete button
		var delete_btn := Button.new()
		delete_btn.text = "Delete"
		delete_btn.add_theme_font_size_override("font_size", 12)
		delete_btn.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		delete_btn.tooltip_text = "Delete this save"
		delete_btn.pressed.connect(_on_delete_slot.bind(slot_num))
		btn_box.add_child(delete_btn)

	return card


# Actions

func _on_save_slot(slot: int, mode: String) -> void:
	if _busy:
		return
	_busy = true
	_set_status("Saving to slot %d (%s)..." % [slot, mode], Color(0.55, 0.75, 0.95))
	var result = await CloudSaveManager.save_to_slot(slot, mode)
	_busy = false
	if result.get("success", false):
		_set_status("Saved to slot %d!" % slot, Color(0.4, 0.78, 0.55))
		_refresh_slots()
	else:
		_set_status("Save failed: %s" % str(result.get("error", "")), Color(0.9, 0.4, 0.4))


func _on_load_slot(slot: int) -> void:
	if _busy:
		return
	_busy = true
	_set_status("Loading slot %d..." % slot, Color(0.55, 0.75, 0.95))
	var result = await CloudSaveManager.load_from_slot(slot)
	_busy = false
	if result.get("success", false):
		_set_status("Loaded slot %d!" % slot, Color(0.4, 0.78, 0.55))
		slot_loaded.emit(slot)
	else:
		_set_status("Load failed: %s" % str(result.get("error", "")), Color(0.9, 0.4, 0.4))


func _on_delete_slot(slot: int) -> void:
	if _busy:
		return
	_busy = true
	_set_status("Deleting slot %d..." % slot, Color(0.9, 0.6, 0.3))
	var result = await CloudSaveManager.delete_slot(slot)
	_busy = false
	if result.get("success", false):
		_set_status("Slot %d deleted" % slot, Color(0.4, 0.78, 0.55))
		_refresh_slots()
	else:
		_set_status("Delete failed: %s" % str(result.get("error", "")), Color(0.9, 0.4, 0.4))


func _on_rename_slot(slot: int) -> void:
	var summary := CloudSaveManager.get_slot_summary(slot)
	var current_name: String = str(summary.get("slot_name", "Slot %d" % slot))

	var dialog := ConfirmationDialog.new()
	dialog.title = "Rename Slot %d" % slot
	dialog.min_size = Vector2(300, 120)

	var vbox := VBoxContainer.new()
	var line_edit := LineEdit.new()
	line_edit.text = current_name
	line_edit.placeholder_text = "Enter slot name..."
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(line_edit)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.add_child(vbox)

	dialog.add_child(margin)
	dialog.move_child(margin, 0)
	add_child(dialog)
	dialog.popup_centered()
	line_edit.grab_focus()

	dialog.confirmed.connect(func():
		var new_name := line_edit.text.strip_edges()
		if new_name.is_empty():
			new_name = "Slot %d" % slot
		_rename_cloud_slot(slot, new_name)
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
	)


func _rename_cloud_slot(slot: int, new_name: String) -> void:
	if _busy:
		return
	_busy = true
	_set_status("Renaming slot %d..." % slot, Color(0.55, 0.75, 0.95))
	var result = await CloudSaveManager.rename_slot(slot, new_name)
	_busy = false
	if result.get("success", false):
		_set_status("Renamed slot %d!" % slot, Color(0.4, 0.78, 0.55))
		_refresh_slots()
	else:
		_set_status("Rename failed: %s" % str(result.get("error", "")), Color(0.9, 0.4, 0.4))


# Quick Save

func _on_auto_save_pressed() -> void:
	if _busy:
		return
	_busy = true
	_set_status("Quick saving...", Color(0.55, 0.75, 0.95))
	var result = await CloudSaveManager.auto_save("solo")
	_busy = false
	if result.get("success", false):
		var slot := int(result.get("slot", 0))
		_set_status("Quick saved to slot %d!" % slot, Color(0.4, 0.78, 0.55))
		_refresh_slots()
	else:
		_set_status("Quick save failed: %s" % str(result.get("error", "")), Color(0.9, 0.4, 0.4))


# Close

func _on_close_pressed() -> void:
	closed.emit()
	hide()


func _set_status(text: String, color: Color = Color(0.6, 0.7, 0.8)) -> void:
	if status_label != null:
		status_label.text = text
		status_label.add_theme_color_override("font_color", color)
