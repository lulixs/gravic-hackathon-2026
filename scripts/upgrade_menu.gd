extends CanvasLayer

const COST_HP := 50
const COST_STAMINA := 50
const COST_DAMAGE := 75
const HP_BONUS := 20.0
const STAMINA_BONUS := 20.0
const DAMAGE_BONUS := 0.10  # +10% global damage

@onready var panel: Control = $Panel
@onready var hp_btn: Button = $Panel/Center/VBox/HPButton
@onready var stamina_btn: Button = $Panel/Center/VBox/StaminaButton
@onready var damage_btn: Button = $Panel/Center/VBox/DamageButton
@onready var xp_label: Label = $Panel/Center/VBox/XPLabel
@onready var hp_stat: Label = $Panel/Center/VBox/HPStat
@onready var stamina_stat: Label = $Panel/Center/VBox/StaminaStat
@onready var weapon_stat: Label = $Panel/Center/VBox/WeaponStat
@onready var damage_stat: Label = $Panel/Center/VBox/DamageStat

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	panel.visible = false
	hp_btn.pressed.connect(_buy_hp)
	stamina_btn.pressed.connect(_buy_stamina)
	damage_btn.pressed.connect(_buy_damage)
	GameManager.xp_changed.connect(func(_v): _refresh())
	GameManager.hp_changed.connect(func(_v, _m): _refresh())
	GameManager.stamina_changed.connect(func(_v, _m): _refresh())
	GameManager.weapon_changed.connect(func(_id): _refresh())
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
	hp_stat.text = "HP: %d / %d" % [roundi(GameManager.hp), roundi(GameManager.max_hp)]
	stamina_stat.text = "Stamina: %d / %d" % [roundi(GameManager.stamina), roundi(GameManager.max_stamina)]
	weapon_stat.text = "Weapon: %s" % GameManager.current_weapon.capitalize()
	damage_stat.text = "Damage: %d%%" % roundi(GameManager.damage_mult * 100.0)
	xp_label.text = "XP: %d  —  spend it below" % GameManager.xp
	hp_btn.text = "+%d Max HP (%d XP)" % [int(HP_BONUS), COST_HP]
	stamina_btn.text = "+%d Max Stamina (%d XP)" % [int(STAMINA_BONUS), COST_STAMINA]
	damage_btn.text = "+%d%% Damage (%d XP)" % [int(DAMAGE_BONUS * 100.0), COST_DAMAGE]
	hp_btn.disabled = GameManager.xp < COST_HP
	stamina_btn.disabled = GameManager.xp < COST_STAMINA
	damage_btn.disabled = GameManager.xp < COST_DAMAGE

func _buy_hp() -> void:
	if GameManager.spend_xp(COST_HP):
		GameManager.increase_max_hp(HP_BONUS)
		_refresh()

func _buy_stamina() -> void:
	if GameManager.spend_xp(COST_STAMINA):
		GameManager.increase_max_stamina(STAMINA_BONUS)
		_refresh()

func _buy_damage() -> void:
	if GameManager.spend_xp(COST_DAMAGE):
		GameManager.add_damage_mult(DAMAGE_BONUS)
		_refresh()
