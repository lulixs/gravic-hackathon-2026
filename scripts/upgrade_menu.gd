extends CanvasLayer

const COST_HP := 50
const COST_STAMINA := 50
const COST_DAMAGE := 75
const HP_BONUS := 20.0
const STAMINA_BONUS := 20.0

@onready var panel: Control = $Panel
@onready var hp_btn: Button = $Panel/Center/VBox/HPButton
@onready var stamina_btn: Button = $Panel/Center/VBox/StaminaButton
@onready var damage_btn: Button = $Panel/Center/VBox/DamageButton
@onready var xp_label: Label = $Panel/Center/VBox/XPLabel

var damage_upgrades := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	panel.visible = false
	hp_btn.pressed.connect(_buy_hp)
	stamina_btn.pressed.connect(_buy_stamina)
	damage_btn.pressed.connect(_buy_damage)
	GameManager.xp_changed.connect(_refresh)
	_refresh(GameManager.xp)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("upgrade_menu"):
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	panel.visible = not panel.visible
	get_tree().paused = panel.visible
	if panel.visible:
		_refresh(GameManager.xp)

func _refresh(_xp: int) -> void:
	xp_label.text = "XP: %d" % GameManager.xp
	hp_btn.text = "+%d Max HP (%d XP)" % [int(HP_BONUS), COST_HP]
	stamina_btn.text = "+%d Max Stamina (%d XP)" % [int(STAMINA_BONUS), COST_STAMINA]
	damage_btn.text = "+10%% Damage (%d XP)" % COST_DAMAGE
	hp_btn.disabled = GameManager.xp < COST_HP
	stamina_btn.disabled = GameManager.xp < COST_STAMINA
	damage_btn.disabled = GameManager.xp < COST_DAMAGE

func _buy_hp() -> void:
	if GameManager.spend_xp(COST_HP):
		GameManager.increase_max_hp(HP_BONUS)
		_refresh(GameManager.xp)

func _buy_stamina() -> void:
	if GameManager.spend_xp(COST_STAMINA):
		GameManager.increase_max_stamina(STAMINA_BONUS)
		_refresh(GameManager.xp)

func _buy_damage() -> void:
	if GameManager.spend_xp(COST_DAMAGE):
		damage_upgrades += 1
		# Multiplier hook: a real game would mutate weapon stats — for the hackathon
		# we just stash the count and let sword.gd query it if it wants.
		_refresh(GameManager.xp)
