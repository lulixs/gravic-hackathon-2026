extends CanvasLayer
## Upgrade screen. Press C to open (pauses the game); spend XP to raise Health,
## Stamina or Strength up to 3 levels each (costs 150 / 200 / 250). Upgrade state
## lives in GameManager so it persists across levels.

@onready var panel: Control = $Panel
@onready var hp_btn: Button = $Panel/Center/VBox/HPButton
@onready var stamina_btn: Button = $Panel/Center/VBox/StaminaButton
@onready var strength_btn: Button = $Panel/Center/VBox/DamageButton
@onready var xp_label: Label = $Panel/Center/VBox/XPLabel
@onready var hp_stat: Label = $Panel/Center/VBox/HPStat
@onready var stamina_stat: Label = $Panel/Center/VBox/StaminaStat
@onready var weapon_stat: Label = $Panel/Center/VBox/WeaponStat
@onready var damage_stat: Label = $Panel/Center/VBox/DamageStat

func _ready() -> void:
	# ALWAYS (not WHEN_PAUSED) so C still toggles while the game is running, and the
	# buttons keep working once it pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	hp_btn.pressed.connect(func() -> void: _buy("hp"))
	stamina_btn.pressed.connect(func() -> void: _buy("stamina"))
	strength_btn.pressed.connect(func() -> void: _buy("strength"))
	GameManager.xp_changed.connect(func(_v): _refresh())
	GameManager.hp_changed.connect(func(_v, _m): _refresh())
	GameManager.stamina_changed.connect(func(_v, _m): _refresh())
	GameManager.weapon_changed.connect(func(_id): _refresh())
	GameManager.upgrades_changed.connect(_refresh)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("upgrade_menu"):
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	panel.visible = not panel.visible
	get_tree().paused = panel.visible
	if panel.visible:
		_refresh()

func _refresh() -> void:
	hp_stat.text = "Health: %d / %d" % [roundi(GameManager.hp), roundi(GameManager.max_hp)]
	stamina_stat.text = "Stamina: %d / %d" % [roundi(GameManager.stamina), roundi(GameManager.max_stamina)]
	weapon_stat.text = "Weapon: %s" % GameManager.current_weapon.capitalize()
	damage_stat.text = "Strength: %d%%" % roundi(GameManager.damage_mult * 100.0)
	xp_label.text = "XP available: %d" % GameManager.xp
	_set_btn(hp_btn, "Health", "hp")
	_set_btn(stamina_btn, "Stamina", "stamina")
	_set_btn(strength_btn, "Strength", "strength")

func _set_btn(btn: Button, label: String, stat: String) -> void:
	var lvl: int = GameManager.upgrade_levels.get(stat, 0)
	var max_lvl: int = GameManager.UPGRADE_MAX_LEVEL
	if lvl >= max_lvl:
		btn.text = "%s  [Lv %d/%d]  —  MAXED" % [label, lvl, max_lvl]
		btn.disabled = true
		return
	var cost: int = GameManager.upgrade_cost(stat)
	btn.text = "%s  [Lv %d/%d]  —  %d XP" % [label, lvl, max_lvl, cost]
	btn.disabled = GameManager.xp < cost

func _buy(stat: String) -> void:
	GameManager.try_upgrade(stat)
	_refresh()
