extends Area2D
## Mud patch. While the player stands in it, lil_dude reads `muddy` and moves at a
## reduced speed (less harsh than cobwebs). Layer 0 / mask 1 — senses the player only.

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and "muddy" in body:
		body.muddy = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and "muddy" in body:
		body.muddy = false
