extends Area2D

# Sticky cobweb patch. While the player stands in it, lil_dude.gd reads `cobwebbed`
# and crawls at 10% speed. Layer 0 / mask 1 so it only senses the player body.

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and "cobwebbed" in body:
		body.cobwebbed = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and "cobwebbed" in body:
		body.cobwebbed = false
