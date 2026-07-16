extends Node

var _signal_markers: Array[String] = []

@onready var _probe: Node = $M0InteropProbe
@onready var _gdscript_echo: Node = $GdScriptEcho


func _ready() -> void:
	_probe.connect(&"ProbeCompleted", _on_probe_completed)
	_probe.emit_probe("signal-from-csharp")

	var checks := {
		"export": _probe.get("ProbeLabel") == "scene-export-preserved",
		"gdscript_to_csharp": _probe.echo_from_csharp("gdscript") == "csharp:gdscript",
		"csharp_to_gdscript": _probe.call_gdscript(_gdscript_echo, "csharp") == "gdscript:csharp",
		"gdscript_resource": _probe.read_skill_id() == "tank_paladin_holy_strike_ability",
		"csharp_signal": _signal_markers.has("signal-from-csharp"),
	}

	for _frame in range(4):
		await get_tree().process_frame
	checks["limbo_to_csharp"] = _probe.get_limbo_call_count() > 0 and _signal_markers.has("limbo-to-csharp")

	var failures: Array[String] = []
	for check_name: String in checks:
		if not checks[check_name]:
			failures.append(check_name)

	if failures.is_empty():
		print("[M0InteropTest] PASS checks=%s" % [checks.keys()])
		get_tree().quit(0)
	else:
		push_error("[M0InteropTest] FAIL checks=%s" % failures)
		get_tree().quit(1)


func _on_probe_completed(marker: String) -> void:
	_signal_markers.append(marker)
