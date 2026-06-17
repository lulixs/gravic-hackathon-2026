extends CanvasLayer

signal all_steps_complete

@onready var panel: Control = $Panel
@onready var label: Label = $Panel/Label

var _steps: Array = []
var _index := 0
var _started := false

func _ready() -> void:
	_steps = [
		{"action": "move",          "message": "Use WASD to move"},
		{"action": "attack",        "message": "Left-click to attack — HOLD until the blade glows red for a max-charge strike"},
		{"action": "block",         "message": "Right-click to block"},
		{"action": "dodge",         "message": "Shift to dodge — costs stamina, grants i-frames"},
		{"action": "upgrade_menu",  "message": "Press C to open the upgrade menu"},
		{"action": "kill_all",      "message": "Defeat the spiders to find your first weapon"},
	]
	panel.visible = false

func hide_panel() -> void:
	panel.visible = false

## Permanently stop the tutorial: hide the panel and prevent it from re-showing.
func dismiss() -> void:
	_started = false
	_index = _steps.size()
	panel.visible = false

func begin() -> void:
	_started = true
	_show_current()

func _show_current() -> void:
	if _index >= _steps.size():
		panel.visible = false
		all_steps_complete.emit()
		return
	panel.visible = true
	label.text = _steps[_index]["message"]

func _input(_event: InputEvent) -> void:
	if not _started or _index >= _steps.size():
		return
	var action: String = _steps[_index]["action"]
	match action:
		"move":
			if Input.is_action_just_pressed("left") or Input.is_action_just_pressed("right") \
				or Input.is_action_just_pressed("up") or Input.is_action_just_pressed("down"):
				_advance()
		"attack", "block", "dodge", "upgrade_menu":
			if Input.is_action_just_pressed(action):
				_advance()
		_:
			pass

func complete_action(action: String) -> void:
	if not _started or _index >= _steps.size():
		return
	if _steps[_index]["action"] == action:
		_advance()

func _advance() -> void:
	_index += 1
	_show_current()
