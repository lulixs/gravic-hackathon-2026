extends Area2D
## A floor plate. Stepping on it latches it active and emits `activated` once. The
## level opens the garden gate when all plates are active.

signal activated

var active := false

@onready var _sprite: ColorRect = $Sprite

func _ready() -> void:
	add_to_group("plate")
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if active:
		return
	if body.is_in_group("player"):
		active = true
		if _sprite:
			_sprite.color = Color(0.3, 0.9, 0.4, 0.9)
		activated.emit()
