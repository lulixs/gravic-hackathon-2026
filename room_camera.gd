extends Camera2D

# Per-room camera. The camera is a child of the player, so it follows the player
# automatically; this script just clamps it to the current room and fades when the
# player crosses into a new room.
#
# Each level configures its own rooms by calling `setup([...])` in its _ready(),
# passing an array of { "rect": Rect2, "limits": Rect2 } (world pixels):
#   - rect   = the floor area used to detect which room the player is in
#   - limits = the camera clamp box for that room (usually rect + wall thickness)
# A single-room level just passes one entry. If setup() is never called, the
# DEFAULT_ROOMS below (matching env.tscn) are used so that scene still works.

const DEFAULT_ROOMS := [
	{ # Room A - top-left (start)
		"rect": Rect2(32, 32, 672, 544),
		"limits": Rect2(0, 0, 704, 576),
	},
	{ # Room B - bottom-left
		"rect": Rect2(32, 640, 960, 704),
		"limits": Rect2(0, 608, 992, 736),
	},
	{ # Room C - right
		"rect": Rect2(992, 0, 768, 1056),
		"limits": Rect2(960, -32, 800, 1088),
	},
]

@export var fade_time := 0.35

var rooms: Array = []
var _player: Node2D
var _current := 0
var _transitioning := false
var _fade: ColorRect


func _ready() -> void:
	_player = get_parent()
	position_smoothing_enabled = false
	# Stay inert until a level calls setup(). The basement drives its own camera
	# (level_1.gd) on this same node, so we must not clamp/fade unless configured.
	if rooms.is_empty():
		return
	_make_fade_overlay()
	_current = _room_at(_player.global_position)
	_apply_room(_current, true)


# Levels call this to install their own room layout.
func setup(room_list: Array) -> void:
	rooms = room_list
	if rooms.is_empty():
		return
	if _fade == null:
		_make_fade_overlay()
	_current = _room_at(_player.global_position if _player else global_position)
	_apply_room(_current, true)


func _room_at(p: Vector2) -> int:
	for i in rooms.size():
		if (rooms[i]["rect"] as Rect2).has_point(p):
			return i
	return _current if _current < rooms.size() else 0


func _make_fade_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


func _apply_room(idx: int, instant := false) -> void:
	if idx < 0 or idx >= rooms.size():
		return
	var lim: Rect2 = rooms[idx]["limits"]
	limit_left = int(lim.position.x)
	limit_top = int(lim.position.y)
	limit_right = int(lim.position.x + lim.size.x)
	limit_bottom = int(lim.position.y + lim.size.y)
	if instant:
		reset_smoothing()
		force_update_scroll()


func _physics_process(_delta: float) -> void:
	if _transitioning or rooms.size() <= 1:
		return
	var p := _player.global_position
	if (rooms[_current]["rect"] as Rect2).has_point(p):
		return
	for i in rooms.size():
		if i != _current and (rooms[i]["rect"] as Rect2).has_point(p):
			_transition_to(i)
			return


func _transition_to(idx: int) -> void:
	_transitioning = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, fade_time)
	tw.tween_callback(func() -> void:
		_current = idx
		_apply_room(idx, true))
	tw.tween_property(_fade, "color:a", 0.0, fade_time)
	tw.tween_callback(func() -> void:
		_transitioning = false)
