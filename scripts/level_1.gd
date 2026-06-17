extends Node2D

## Room-based camera controller for the basement.
##
## Each room is an Area2D child of this node whose CollisionPolygon2D describes
## the room's extent. The player's Camera2D follows the player but is clamped to
## the bounds of whichever room the player is currently in. Walking into a new
## room fades the screen to black, snaps the camera limits to the new room, then
## fades back in.

## Duration (seconds) of each half of the fade (out, then in).
const FADE_TIME := 0.25

@onready var player: CharacterBody2D = $CharacterBody2D
@onready var camera: Camera2D = $CharacterBody2D/Camera2D

var _fade_rect: ColorRect
var _current_room: Area2D
var _tween: Tween


func _ready() -> void:
	_build_fade_overlay()

	for room in _get_rooms():
		room.body_entered.connect(_on_room_body_entered.bind(room))

	_connect_ramp()

	# Snap straight to whichever room the player starts in (no fade).
	var start := _room_containing(player.global_position)
	if start == null and not _get_rooms().is_empty():
		start = _get_rooms()[0]
	if start:
		_current_room = start
		_apply_room_limits(start)


## Every Area2D child is treated as a room, except the ramp (handled separately).
func _get_rooms() -> Array:
	var rooms: Array = []
	for child in get_children():
		if child is Area2D and child.name != "ramp" and child.has_node("CollisionPolygon2D"):
			rooms.append(child)
	return rooms


## The ramp is not a room: it just toggles the player's on_ramp flag so the
## player script can apply the slope drift while standing on it.
func _connect_ramp() -> void:
	var ramp := get_node_or_null("ramp")
	if ramp == null:
		return
	ramp.body_entered.connect(func(body): if body == player: player.on_ramp = true)
	ramp.body_exited.connect(func(body): if body == player: player.on_ramp = false)


func _build_fade_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.anchor_right = 1.0
	_fade_rect.anchor_bottom = 1.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.modulate.a = 0.0
	layer.add_child(_fade_rect)


## World-space bounding box of a room's collision polygon.
func _room_bounds(room: Area2D) -> Rect2:
	var poly := room.get_node("CollisionPolygon2D") as CollisionPolygon2D
	var points := poly.polygon
	var xform := poly.global_transform
	var rect := Rect2(xform * points[0], Vector2.ZERO)
	for i in range(1, points.size()):
		rect = rect.expand(xform * points[i])
	return rect


func _room_containing(point: Vector2) -> Area2D:
	for room in _get_rooms():
		if _room_bounds(room).has_point(point):
			return room
	return null


func _apply_room_limits(room: Area2D) -> void:
	var b := _room_bounds(room)
	camera.limit_left = int(b.position.x)
	camera.limit_top = int(b.position.y)
	camera.limit_right = int(b.position.x + b.size.x)
	camera.limit_bottom = int(b.position.y + b.size.y)
	# Jump the camera to its clamped target instead of sliding there.
	camera.reset_smoothing()


func _on_room_body_entered(body: Node, room: Area2D) -> void:
	if body != player:
		return
	if room == _current_room:
		return
	_start_transition(room)


func _start_transition(room: Area2D) -> void:
	# Claim the target room immediately so repeated/overlapping entry signals
	# from the same room are ignored while the fade plays.
	_current_room = room

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(_fade_rect, "modulate:a", 1.0, FADE_TIME)
	_tween.tween_callback(_apply_room_limits.bind(room))
	_tween.tween_property(_fade_rect, "modulate:a", 0.0, FADE_TIME)
