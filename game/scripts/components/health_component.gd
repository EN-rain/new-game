extends Node
class_name HealthComponent

signal health_changed(current_health: int, max_health: int)
signal damage_taken(amount: int)
signal died()

@export var max_health: int = 100
@export var health_bar_hide_time: float = 5.0

var current_health: int
var health_bar: ProgressBar
var hp_regen: float = 0.0 ## HP/s out of combat
var hp_regen_bonus: float = 0.0 ## Additional HP/s from stats/skills
var _combat_timer: float = 0.0
var _is_in_combat: bool = false
@onready var hide_timer: Timer = get_node_or_null("HideTimer")
var is_dead := false

func initialize(healthbar: ProgressBar):
	current_health = max_health
	set_process(true)
	
	# Setup hide timer
	if hide_timer == null:
		hide_timer = Timer.new()
		hide_timer.name = "HideTimer"
		add_child(hide_timer)

	if hide_timer:
		hide_timer.one_shot = true
		hide_timer.wait_time = health_bar_hide_time
		if not hide_timer.timeout.is_connected(_on_hide_timer_timeout):
			hide_timer.timeout.connect(_on_hide_timer_timeout)
	
	# Setup health bar
	health_bar = healthbar
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = false

func take_damage(amount: int) -> bool:
	if is_dead:
		return false
	
	current_health -= amount
	current_health = max(0, current_health)
	
	# Enter combat state - pauses regen
	_is_in_combat = true
	_combat_timer = 2.0
	
	# Update health bar
	if health_bar:
		health_bar.value = current_health
		health_bar.visible = true
		if hide_timer:
			hide_timer.start()
	
	health_changed.emit(current_health, max_health)
	damage_taken.emit(amount)
	
	if current_health <= 0:
		is_dead = true
		died.emit()
		return true  # Indicates death
	
	return false  # Still alive

func heal(amount: int):
	if is_dead:
		return
	
	current_health += amount
	current_health = min(current_health, max_health)
	
	if health_bar:
		health_bar.value = current_health
	
	health_changed.emit(current_health, max_health)


func revive(health_percent: float = 0.5) -> void:
	if not is_dead:
		return
	is_dead = false
	current_health = max(1, int(float(max_health) * clampf(health_percent, 0.01, 1.0)))
	if health_bar:
		health_bar.value = current_health
		health_bar.visible = true
		health_bar.show()
		if hide_timer:
			hide_timer.start()
	health_changed.emit(current_health, max_health)

func _on_hide_timer_timeout():
	if health_bar:
		health_bar.visible = false

func _process(delta: float) -> void:
	if is_dead or max_health <= 0:
		return
	# Track combat state
	if _is_in_combat:
		_combat_timer -= delta
		if _combat_timer <= 0.0:
			_is_in_combat = false
	# Regen HP out of combat
	if not _is_in_combat:
		var regen_rate := hp_regen + hp_regen_bonus
		if regen_rate > 0.0:
			var hp_before := current_health
			current_health = mini(current_health + int(regen_rate * delta), max_health)
			if current_health != hp_before:
				health_changed.emit(current_health, max_health)


func enter_combat() -> void:
	_is_in_combat = true
	_combat_timer = 2.0


func get_health_percent() -> float:
	return float(current_health) / float(max_health)
