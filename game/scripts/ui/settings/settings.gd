extends Control

signal settings_closed

@onready var back_button: Button = %BackButton
@onready var master_volume_slider: HSlider = %MasterVolumeSlider
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = %SFXVolumeSlider
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var vsync_check: CheckBox = %VsyncCheck
@onready var fps_limit_input: SpinBox = %FPSLimitInput
@onready var screen_shake_check: CheckBox = %ScreenShakeCheck
@onready var show_damage_numbers_check: CheckBox = %ShowDamageNumbersCheck
@onready var show_fps_check: CheckBox = %ShowFPSCheck
@onready var language_option: OptionButton = %LanguageOption

@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/ui/main_menu.tscn"

const SETTINGS_PATH := "user://settings.cfg"
const KEYBIND_SECTION := "keybinds"

# Remappable actions and their display names
const REMAPPABLE_ACTIONS: Dictionary = {
	"up": "Move Up",
	"down": "Move Down",
	"left": "Move Left",
	"right": "Move Right",
	"dash": "Dash",
	"pause": "Pause",
}

const KeybindRowScene := preload("res://scenes/ui/keybind_row.tscn")

var _keybind_buttons: Dictionary = {}  # action_name -> Button
var _listening_for_action: String = ""
var _listening_button: Button = null


func _ready() -> void:
	_load_settings()
	_connect_signals()
	_create_keybind_ui()
	_load_keybinds()


func _connect_signals() -> void:
	if back_button != null:
		back_button.pressed.connect(_on_back_pressed)
	if master_volume_slider != null:
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if music_volume_slider != null:
		music_volume_slider.value_changed.connect(_on_music_volume_changed)
	if sfx_volume_slider != null:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	if fullscreen_check != null:
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	if vsync_check != null:
		vsync_check.toggled.connect(_on_vsync_toggled)
	if fps_limit_input != null:
		fps_limit_input.value_changed.connect(_on_fps_limit_changed)
	if screen_shake_check != null:
		screen_shake_check.toggled.connect(_on_screen_shake_toggled)
	if show_damage_numbers_check != null:
		show_damage_numbers_check.toggled.connect(_on_show_damage_numbers_toggled)
	if show_fps_check != null:
		show_fps_check.toggled.connect(_on_show_fps_toggled)
	if language_option != null:
		language_option.item_selected.connect(_on_language_selected)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		_apply_defaults()
		return

	# Audio
	var master_vol: float = config.get_value("audio", "master_volume", 1.0)
	var music_vol: float = config.get_value("audio", "music_volume", 0.8)
	var sfx_vol: float = config.get_value("audio", "sfx_volume", 1.0)

	if master_volume_slider != null:
		master_volume_slider.value = master_vol
	if music_volume_slider != null:
		music_volume_slider.value = music_vol
	if sfx_volume_slider != null:
		sfx_volume_slider.value = sfx_vol

	# Video
	var fullscreen: bool = config.get_value("video", "fullscreen", false)
	var vsync: bool = config.get_value("video", "vsync", true)
	var fps_limit: int = config.get_value("video", "fps_limit", 0)

	if fullscreen_check != null:
		fullscreen_check.button_pressed = fullscreen
	if vsync_check != null:
		vsync_check.button_pressed = vsync
	if fps_limit_input != null:
		fps_limit_input.value = fps_limit

	# Gameplay
	var screen_shake: bool = config.get_value("gameplay", "screen_shake", true)
	var show_damage_numbers: bool = config.get_value("gameplay", "show_damage_numbers", true)

	if screen_shake_check != null:
		screen_shake_check.button_pressed = screen_shake
	if show_damage_numbers_check != null:
		show_damage_numbers_check.button_pressed = show_damage_numbers

	# HUD
	var show_fps: bool = config.get_value("hud", "show_fps", false)
	var language: int = config.get_value("hud", "language", 0)

	if show_fps_check != null:
		show_fps_check.button_pressed = show_fps
	if language_option != null:
		language_option.select(language)

	_apply_video_settings()


func _apply_defaults() -> void:
	if master_volume_slider != null:
		master_volume_slider.value = 1.0
	if music_volume_slider != null:
		music_volume_slider.value = 0.8
	if sfx_volume_slider != null:
		sfx_volume_slider.value = 1.0
	if fullscreen_check != null:
		fullscreen_check.button_pressed = false
	if vsync_check != null:
		vsync_check.button_pressed = true
	if fps_limit_input != null:
		fps_limit_input.value = 0
	if screen_shake_check != null:
		screen_shake_check.button_pressed = true
	if show_damage_numbers_check != null:
		show_damage_numbers_check.button_pressed = true
	if show_fps_check != null:
		show_fps_check.button_pressed = false
	if language_option != null:
		language_option.select(0)


func _save_settings() -> void:
	var config := ConfigFile.new()

	# Audio
	if master_volume_slider != null:
		config.set_value("audio", "master_volume", master_volume_slider.value)
	if music_volume_slider != null:
		config.set_value("audio", "music_volume", music_volume_slider.value)
	if sfx_volume_slider != null:
		config.set_value("audio", "sfx_volume", sfx_volume_slider.value)

	# Video
	if fullscreen_check != null:
		config.set_value("video", "fullscreen", fullscreen_check.button_pressed)
	if vsync_check != null:
		config.set_value("video", "vsync", vsync_check.button_pressed)
	if fps_limit_input != null:
		config.set_value("video", "fps_limit", int(fps_limit_input.value))

	# Gameplay
	if screen_shake_check != null:
		config.set_value("gameplay", "screen_shake", screen_shake_check.button_pressed)
	if show_damage_numbers_check != null:
		config.set_value("gameplay", "show_damage_numbers", show_damage_numbers_check.button_pressed)

	# HUD
	if show_fps_check != null:
		config.set_value("hud", "show_fps", show_fps_check.button_pressed)
	if language_option != null:
		config.set_value("hud", "language", language_option.selected)

	config.save(SETTINGS_PATH)


func _apply_video_settings() -> void:
	if fullscreen_check != null:
		if fullscreen_check.button_pressed:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	if vsync_check != null:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_check.button_pressed else DisplayServer.VSYNC_DISABLED)

	if fps_limit_input != null:
		Engine.max_fps = int(fps_limit_input.value)


func _on_back_pressed() -> void:
	_save_settings()
	if not main_menu_scene_path.is_empty():
		get_tree().change_scene_to_file(main_menu_scene_path)
	else:
		settings_closed.emit()


func _on_master_volume_changed(value: float) -> void:
	# Apply to audio bus
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))


func _on_music_volume_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))


func _on_sfx_volume_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_vsync_toggled(toggled_on: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if toggled_on else DisplayServer.VSYNC_DISABLED)


func _on_fps_limit_changed(value: float) -> void:
	Engine.max_fps = int(value)


func _on_screen_shake_toggled(_toggled_on: bool) -> void:
	pass  # Handled by gameplay systems


func _on_show_damage_numbers_toggled(_toggled_on: bool) -> void:
	pass  # Handled by gameplay systems


func _on_show_fps_toggled(_toggled_on: bool) -> void:
	pass  # Handled by HUD systems


func _on_language_selected(_index: int) -> void:
	pass  # Handled by localization system


# ---- Keybind Remapping ----

func _create_keybind_ui() -> void:
	# Find or create a container for keybinds in the settings scene
	var keybind_container := get_node_or_null("VBox/Keybinds")
	if keybind_container == null:
		# Try to find the main VBoxContainer to add our section
		var main_vbox := get_node_or_null("VBox")
		if main_vbox == null:
			# Search for any VBoxContainer
			for child in get_children():
				if child is VBoxContainer:
					main_vbox = child
					break
			if main_vbox == null:
					return
		keybind_container = VBoxContainer.new()
		keybind_container.name = "Keybinds"
		main_vbox.add_child(keybind_container)

	var section_label := Label.new()
	section_label.text = "Keybinds"
	section_label.add_theme_font_size_override("font_size", 18)
	section_label.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	keybind_container.add_child(section_label)

	var sep := HSeparator.new()
	keybind_container.add_child(sep)

	for action_name in REMAPPABLE_ACTIONS:
		var row := KeybindRowScene.instantiate()
		row.get_node("NameLabel").text = REMAPPABLE_ACTIONS[action_name]
		var bind_btn: Button = row.get_node("BindButton")
		bind_btn.pressed.connect(_on_keybind_button_pressed.bind(action_name))
		row.get_node("ResetButton").pressed.connect(_on_keybind_reset_pressed.bind(action_name))
		keybind_container.add_child(row)
		_keybind_buttons[action_name] = bind_btn

	_update_keybind_labels()


func _update_keybind_labels() -> void:
	for action_name in _keybind_buttons:
		var btn: Button = _keybind_buttons[action_name]
		if btn == null:
			continue
		var events := InputMap.action_get_events(action_name)
		if events.is_empty():
			btn.text = "(none)"
		else:
			btn.text = _event_to_string(events[0])
		btn.remove_theme_color_override("font_color")


func _event_to_string(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_str: String = event.as_text_physical_keycode()
		if key_str.is_empty():
			key_str = event.as_text()
		return key_str
	elif event is InputEventMouseButton:
		match event.button_index:
			1: return "Left Click"
			2: return "Right Click"
			3: return "Middle Click"
			_: return "Mouse %d" % event.button_index
	return event.as_text()


func _on_keybind_button_pressed(action_name: String) -> void:
	if _listening_for_action == action_name:
		# Cancel listening
		_cancel_keybind_listen()
		return
	# Start listening
	_listening_for_action = action_name
	_listening_button = _keybind_buttons.get(action_name) as Button
	if _listening_button != null:
		_listening_button.text = "Press a key..."
		_listening_button.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))


func _on_keybind_reset_pressed(action_name: String) -> void:
	# Reset to project defaults by clearing and re-adding from InputMap defaults
	InputMap.action_erase_events(action_name)
	# Load default from project.godot - we store defaults at first launch
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK and config.has_section_key(KEYBIND_SECTION, action_name + "_default"):
		var default_str: String = config.get_value(KEYBIND_SECTION, action_name + "_default", "")
		if not default_str.is_empty():
			var ev := _string_to_event(default_str)
			if ev != null:
				InputMap.action_add_event(action_name, ev)
	else:
		# Fallback: use common defaults
		var default_key: Key = KEY_UNKNOWN
		match action_name:
			"up": default_key = KEY_W
			"down": default_key = KEY_S
			"left": default_key = KEY_A
			"right": default_key = KEY_D
			"dash": default_key = KEY_SPACE
			"pause": default_key = KEY_ESCAPE
		if default_key != KEY_UNKNOWN:
			var ev := InputEventKey.new()
			ev.physical_keycode = default_key
			InputMap.action_add_event(action_name, ev)
	_update_keybind_labels()
	_save_keybinds()


func _input(event: InputEvent) -> void:
	if _listening_for_action.is_empty():
		return

	# Accept keyboard or mouse button events for binding
	if event is InputEventKey and event.pressed and not event.echo:
		# Ignore Escape - use it to cancel
		if event.physical_keycode == KEY_ESCAPE:
			_cancel_keybind_listen()
			get_viewport().set_input_as_handled()
			return
		_apply_keybind(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_keybind_listen()
			get_viewport().set_input_as_handled()
			return
		_apply_keybind(event)
		get_viewport().set_input_as_handled()


func _apply_keybind(event: InputEvent) -> void:
	InputMap.action_erase_events(_listening_for_action)
	InputMap.action_add_event(_listening_for_action, event)
	_update_keybind_labels()
	_save_keybinds()
	_listening_for_action = ""
	_listening_button = null


func _cancel_keybind_listen() -> void:
	_listening_for_action = ""
	if _listening_button != null:
		_listening_button = null
	_update_keybind_labels()


func _save_keybinds() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)  # Load existing settings first

	for action_name in _keybind_buttons:
		var events := InputMap.action_get_events(action_name)
		if not events.is_empty():
			config.set_value(KEYBIND_SECTION, action_name, _event_to_string(events[0]))
			# Save default on first write if not already saved
			if not config.has_section_key(KEYBIND_SECTION, action_name + "_default"):
				config.set_value(KEYBIND_SECTION, action_name + "_default", _event_to_string(events[0]))
		else:
			config.set_value(KEYBIND_SECTION, action_name, "")

	config.save(SETTINGS_PATH)


func _load_keybinds() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	if not config.has_section(KEYBIND_SECTION):
		return

	for action_name in REMAPPABLE_ACTIONS:
		var saved: String = config.get_value(KEYBIND_SECTION, action_name, "")
		if saved.is_empty():
			continue
		var ev := _string_to_event(saved)
		if ev != null:
			InputMap.action_erase_events(action_name)
			InputMap.action_add_event(action_name, ev)

	_update_keybind_labels()


func _string_to_event(text: String) -> InputEvent:
	# Parse saved key string back to InputEvent
	# Handle mouse buttons
	match text:
		"Left Click":
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			return ev
		"Right Click":
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_RIGHT
			return ev
		"Middle Click":
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_MIDDLE
			return ev

	# Handle keyboard keys - try physical keycode lookup
	var key_event := InputEventKey.new()
	# Common key name to physical keycode mapping
	var key_map: Dictionary = {
		"W": KEY_W, "A": KEY_A, "S": KEY_S, "D": KEY_D,
		"Q": KEY_Q, "E": KEY_E, "R": KEY_R, "F": KEY_F,
		"Space": KEY_SPACE, "Shift": KEY_SHIFT, "Ctrl": KEY_CTRL,
		"Tab": KEY_TAB, "Enter": KEY_ENTER, "Escape": KEY_ESCAPE,
		"Up": KEY_UP, "Down": KEY_DOWN, "Left": KEY_LEFT, "Right": KEY_RIGHT,
		"1": KEY_1, "2": KEY_2, "3": KEY_3, "4": KEY_4, "5": KEY_5,
		"C": KEY_C, "V": KEY_V, "X": KEY_X, "Z": KEY_Z,
	}
	# Strip modifier prefixes (Shift+, Ctrl+, etc.)
	var clean_text := text
	var has_shift := false
	var has_ctrl := false
	if clean_text.begins_with("Shift+"):
		has_shift = true
		clean_text = clean_text.substr(7)
	if clean_text.begins_with("Ctrl+"):
		has_ctrl = true
		clean_text = clean_text.substr(6)

	if key_map.has(clean_text):
		key_event.physical_keycode = key_map[clean_text]
		key_event.shift_pressed = has_shift
		key_event.ctrl_pressed = has_ctrl
		return key_event

	# Try Unicode character for single letters
	if clean_text.length() == 1:
		key_event.unicode = clean_text.unicode_at(0)
		key_event.physical_keycode = OS.find_keycode_from_string(clean_text)
		return key_event

	return null
