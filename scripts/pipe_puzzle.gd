extends Node2D

# Pipe-rotation gate. Each child of $Pipes starts rotated wrong; the player walks
# up and presses E to rotate the nearest pipe 90°. When every pipe points up
# (index 0) the puzzle emits `solved`, which the level uses to open the gate.

signal solved

@export var interact_radius := 56.0

var _is_solved := false

func _ready() -> void:
	for pipe in $Pipes.get_children():
		pipe.set_meta("idx", randi() % 3 + 1)  # 1..3 -> guaranteed not already solved
		_apply_rot(pipe)

func _apply_rot(pipe: Node) -> void:
	(pipe as Node2D).rotation_degrees = 90.0 * int(pipe.get_meta("idx"))

func _unhandled_input(event: InputEvent) -> void:
	if _is_solved:
		return
	if not event.is_action_pressed("interact"):
		return
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	var nearest: Node = null
	var best := interact_radius
	for pipe in $Pipes.get_children():
		var d: float = (pipe as Node2D).global_position.distance_to(player.global_position)
		if d <= best:
			best = d
			nearest = pipe
	if nearest:
		nearest.set_meta("idx", (int(nearest.get_meta("idx")) + 1) % 4)
		_apply_rot(nearest)
		_check_solution()

func _check_solution() -> void:
	for pipe in $Pipes.get_children():
		if int(pipe.get_meta("idx")) != 0:
			return
	_is_solved = true
	solved.emit()
