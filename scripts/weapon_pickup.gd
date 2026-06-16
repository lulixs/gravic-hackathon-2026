extends Area2D

signal collected(weapon_id: String)

@export var weapon_id: String = "dagger"
@export var display_name: String = "Dagger"

@onready var label: Label = $Label

func _ready() -> void:
	if label:
		label.text = display_name
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		GameManager.set_weapon(weapon_id)
		collected.emit(weapon_id)
		queue_free()
