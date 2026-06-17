extends Area2D

## A collectable key item. Mirrors weapon_pickup.gd but carries no weapon —
## it just announces it was picked up so the level can unlock a door.

signal collected

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		collected.emit()
		queue_free()
