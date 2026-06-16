extends CanvasLayer

@onready var hp_bar: ProgressBar = $Margin/VBox/HPBar
@onready var stamina_bar: ProgressBar = $Margin/VBox/StaminaBar
@onready var xp_label: Label = $Margin/VBox/XPLabel
@onready var weapon_label: Label = $Margin/VBox/WeaponLabel

func _ready() -> void:
	GameManager.hp_changed.connect(_on_hp_changed)
	GameManager.stamina_changed.connect(_on_stamina_changed)
	GameManager.xp_changed.connect(_on_xp_changed)
	GameManager.weapon_changed.connect(_on_weapon_changed)
	_on_hp_changed(GameManager.hp, GameManager.max_hp)
	_on_stamina_changed(GameManager.stamina, GameManager.max_stamina)
	_on_xp_changed(GameManager.xp)
	_on_weapon_changed(GameManager.current_weapon)

func _on_hp_changed(val: float, max_val: float) -> void:
	hp_bar.max_value = max_val
	hp_bar.value = val

func _on_stamina_changed(val: float, max_val: float) -> void:
	stamina_bar.max_value = max_val
	stamina_bar.value = val

func _on_xp_changed(val: int) -> void:
	xp_label.text = "XP: %d" % val

func _on_weapon_changed(id: String) -> void:
	weapon_label.text = "Weapon: %s" % id.capitalize()
