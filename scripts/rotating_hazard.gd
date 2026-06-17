extends Node2D

# Spinning blade trap — a heavy iron bar that sweeps around a fixed hub in the
# castle. Can't be destroyed; touching the blade flings the player back and hurts.
# Damage is rate-limited by the player's own i-frames, so a brush costs one hit.

@export var spin_speed := 95.0   # degrees per second (negative = counter-clockwise)
@export var damage := 14.0

@onready var _blades: Node2D = $Blades

func _physics_process(delta: float) -> void:
	_blades.rotation_degrees += spin_speed * delta
	for child in _blades.get_children():
		if child is Area2D:
			for body in (child as Area2D).get_overlapping_bodies():
				if body.is_in_group("player") and body.has_method("take_damage"):
					body.take_damage(damage, global_position)
					return
