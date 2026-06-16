extends Camera2D

# Per-room camera control.
# Each room defines a `rect` (the walkable floor area, used to detect which
# room the player is in) and `limits` (the camera clamp box, incl. walls).
# Coordinates are world pixels; tiles are 32px. See env.tscn tilemap.
const ROOMS := [
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

var _player: Node2D
var _current := 0
var _transitioning := false
var _fade: ColorRect


func _ready() -> void:
	_player = get_parent()
	position_smoothing_enabled = false
	_make_fade_overlay()
	_apply_room(_current, true)


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
	var lim: Rect2 = ROOMS[idx]["limits"]
	limit_left = int(lim.position.x)
	limit_top = int(lim.position.y)
	limit_right = int(lim.position.x + lim.size.x)
	limit_bottom = int(lim.position.y + lim.size.y)
	if instant:
		reset_smoothing()
		force_update_scroll()


func _physics_process(_delta: float) -> void:
	if _transitioning:
		return
	var p := _player.global_position
	# Still inside the current room -> nothing to do.
	if (ROOMS[_current]["rect"] as Rect2).has_point(p):
		return
	# Entered a different room's floor area -> transition.
	for i in ROOMS.size():
		if i != _current and (ROOMS[i]["rect"] as Rect2).has_point(p):
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
