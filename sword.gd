extends Sprite2D

@export var OUTER_RADIUS = 30.0  # max distance the sword can float from the player
@export var INNER_RADIUS = 10.0  # min distance, so the sword never sits on top of the player
@export var BLOCK_RADIUS = 6.0   # distance the sword pulls in to while blocking
@export var FOLLOW_SPEED = 12.0  # how snappily the sword chases the mouse
@export var BLOCK_SPEED = 10.0   # how quickly the sword eases in/out of the block stance

var block := 0.0  # 0 = normal, 1 = fully in the sideways block stance

func _physics_process(delta: float) -> void:
	# offset from the player (our parent) to the mouse, in the player's local space.
	# the player isn't rotated/scaled, so this global offset == our local position.
	var player := get_parent() as Node2D
	var to_mouse: Vector2 = get_global_mouse_position() - player.global_position
	# ease the block amount toward held/released (frame-rate independent).
	var block_target := 1.0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else 0.0
	block = lerpf(block, block_target, 1.0 - exp(-BLOCK_SPEED * delta))
	# clamp the target into a ring (between INNER_RADIUS and OUTER_RADIUS) around the
	# player, while keeping the direction toward the mouse. while blocking, pull in
	# toward BLOCK_RADIUS.
	var dir := to_mouse.normalized() if to_mouse != Vector2.ZERO else Vector2.UP
	var dist := clampf(to_mouse.length(), INNER_RADIUS, OUTER_RADIUS)
	dist = lerpf(dist, BLOCK_RADIUS, block)
	var target := dir * dist
	# ease toward the target (frame-rate independent smoothing).
	position = position.lerp(target, 1.0 - exp(-FOLLOW_SPEED * delta))
	# hard wall: the eased position can lerp straight across the center when the mouse
	# flips sides, so push it back out to the minimum radius. it never crosses over the
	# player; instead it slides around the rim.
	var min_dist := lerpf(INNER_RADIUS, BLOCK_RADIUS, block)
	if position.length() < min_dist:
		position = (position.normalized() if position != Vector2.ZERO else dir) * min_dist
	# point the blade (the sprite's "up") away from the player, rotating an extra
	# 90° toward sideways as the block stance eases in.
	rotation = position.angle() + PI / 2 + block * PI / 2
