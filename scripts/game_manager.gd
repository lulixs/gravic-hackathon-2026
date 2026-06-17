extends Node

signal hp_changed(val: float, max_val: float)
signal stamina_changed(val: float, max_val: float)
signal xp_changed(val: int)
signal weapon_changed(id: String)
signal player_died
signal upgrades_changed

@export var max_hp := 100.0
@export var max_stamina := 50.0   # halved stamina pool

var hp := max_hp
var stamina := max_stamina
var xp := 0
var current_weapon := "stick"
var damage_mult := 1.0  # global damage scaling from XP upgrades

# XP upgrades: Health / Stamina / Strength, each up to 3 levels with escalating cost
const UPGRADE_COSTS := [150, 200, 250]   # cost for level 1, 2, 3
const UPGRADE_MAX_LEVEL := 3
const HP_PER_LEVEL := 25.0
const STAMINA_PER_LEVEL := 25.0
const STRENGTH_PER_LEVEL := 0.15  # +15% damage per level
var upgrade_levels := {"hp": 0, "stamina": 0, "strength": 0}

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
	upgrade_levels = {"hp": 0, "stamina": 0, "strength": 0}
	hp_changed.emit(hp, max_hp)
	stamina_changed.emit(stamina, max_stamina)
	xp_changed.emit(xp)
	weapon_changed.emit(current_weapon)
	upgrades_changed.emit()

## Respawn after death: refill HP/stamina but KEEP all progression (weapon, XP,
## upgrade levels, max HP/stamina, damage). Used when reloading the current level
## on death so upgrades persist. (reset() is only for starting a brand-new run.)
func respawn() -> void:
	hp = max_hp
	stamina = max_stamina
	hp_changed.emit(hp, max_hp)
	stamina_changed.emit(stamina, max_stamina)

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

# --- XP upgrades ---

## Cost of the NEXT level for a stat ("hp"/"stamina"/"strength"), or -1 if maxed.
func upgrade_cost(stat: String) -> int:
	var lvl: int = upgrade_levels.get(stat, 0)
	if lvl >= UPGRADE_MAX_LEVEL:
		return -1
	return UPGRADE_COSTS[lvl]

## Buy the next level of a stat. Returns false if maxed or can't afford it.
func try_upgrade(stat: String) -> bool:
	var lvl: int = upgrade_levels.get(stat, 0)
	if lvl >= UPGRADE_MAX_LEVEL:
		return false
	if not spend_xp(UPGRADE_COSTS[lvl]):
		return false
	upgrade_levels[stat] = lvl + 1
	match stat:
		"hp":
			increase_max_hp(HP_PER_LEVEL)
		"stamina":
			increase_max_stamina(STAMINA_PER_LEVEL)
		"strength":
			add_damage_mult(STRENGTH_PER_LEVEL)
	upgrades_changed.emit()
	return true
