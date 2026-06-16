extends Node

signal hp_changed(val: float, max_val: float)
signal stamina_changed(val: float, max_val: float)
signal xp_changed(val: int)
signal weapon_changed(id: String)
signal player_died

@export var max_hp := 100.0
@export var max_stamina := 100.0

var hp := max_hp
var stamina := max_stamina
var xp := 0
var current_weapon := "stick"
var damage_mult := 1.0  # global damage scaling from XP upgrades

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep listening for fullscreen toggle even when paused
	reset()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		var win := DisplayServer.window_get_mode()
		if win == DisplayServer.WINDOW_MODE_FULLSCREEN or win == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event.is_action_pressed("quit_game"):
		get_tree().quit()

func reset() -> void:
	hp = max_hp
	stamina = max_stamina
	xp = 0
	current_weapon = "stick"
	damage_mult = 1.0
	hp_changed.emit(hp, max_hp)
	stamina_changed.emit(stamina, max_stamina)
	xp_changed.emit(xp)
	weapon_changed.emit(current_weapon)

func take_damage(n: float) -> void:
	hp = clampf(hp - n, 0.0, max_hp)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		player_died.emit()

func heal(n: float) -> void:
	hp = clampf(hp + n, 0.0, max_hp)
	hp_changed.emit(hp, max_hp)

func drain_stamina(n: float) -> bool:
	if stamina < n:
		return false
	stamina -= n
	stamina_changed.emit(stamina, max_stamina)
	return true

func restore_stamina(n: float) -> void:
	stamina = clampf(stamina + n, 0.0, max_stamina)
	stamina_changed.emit(stamina, max_stamina)

func add_xp(n: int) -> void:
	xp += n
	xp_changed.emit(xp)

func spend_xp(n: int) -> bool:
	if xp < n:
		return false
	xp -= n
	xp_changed.emit(xp)
	return true

func set_weapon(id: String) -> void:
	current_weapon = id
	weapon_changed.emit(id)

func increase_max_hp(n: float) -> void:
	max_hp += n
	hp = clampf(hp + n, 0.0, max_hp)
	hp_changed.emit(hp, max_hp)

func increase_max_stamina(n: float) -> void:
	max_stamina += n
	stamina = clampf(stamina + n, 0.0, max_stamina)
	stamina_changed.emit(stamina, max_stamina)

func add_damage_mult(frac: float) -> void:
	damage_mult += frac
