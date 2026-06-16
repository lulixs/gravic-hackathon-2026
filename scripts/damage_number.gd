extends Node2D

# A small red number that pops above an enemy when it's hit, drifts up, and fades out.
# Spawn it, set `amount` (and optionally `color`), add it to the scene, then set its
# global_position — _ready reads `amount` so it must be assigned before add_child.

@export var rise_speed := 52.0
@export var lifetime := 0.7

var amount := 0.0
var color := Color(1.0, 0.28, 0.28)

var _t := 0.0
@onready var _label: Label = $Label

func _ready() -> void:
	_label.text = str(roundi(amount))
	_label.modulate = color
	# tiny random horizontal drift so stacked hits don't perfectly overlap
	position.x += randf_range(-6.0, 6.0)

func _process(delta: float) -> void:
	_t += delta
	position.y -= rise_speed * delta
	modulate.a = 1.0 - clampf(_t / lifetime, 0.0, 1.0)
	if _t >= lifetime:
		queue_free()
