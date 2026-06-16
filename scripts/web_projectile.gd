extends Area2D

# The Broodmother's web spit. Flies toward the player; on hit it damages and
# leaves a cobweb. On timeout it also drops a cobweb where it lands.

const COBWEB := preload("res://scenes/cobweb.tscn")

@export var speed := 110.0
@export var damage := 10.0
@export var life := 2.2

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
		_drop_web()
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		_drop_web()
		queue_free()

func _drop_web() -> void:
	var c := COBWEB.instantiate()
	get_parent().add_child(c)
	c.global_position = global_position
