extends Area2D

# A blob of basement filth lobbed by an egg sac. Flies in a straight line,
# damages the player on contact, despawns after a while.

@export var speed := 120.0
@export var damage := 8.0
@export var life := 4.0

var dir := Vector2.RIGHT
var _t := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += dir * speed * delta
	_t += delta
	if _t >= life:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
