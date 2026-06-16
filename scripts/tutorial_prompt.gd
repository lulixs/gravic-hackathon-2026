extends CanvasLayer

signal all_steps_complete

@onready var label: Label = $Panel/Label

var _steps: Array = []
var _index := 0

func _ready() -> void:
	_steps = [
		{"action": "move",          "message": "Use WASD to move"},
		{"action": "attack",        "message": "Left-click to attack — hold for a charged strike"},
		{"action": "block",         "message": "Right-click to block"},
		{"action": "dodge",         "message": "Shift to dodge — costs stamina"},
		{"action": "upgrade_menu",  "message": "Press C to open the upgrade menu"},
		{"action": "kill_all",      "message": "Defeat the spiders to find your first weapon"},
	]
	_show_current()

func _show_current() -> void:
	if _index >= _steps.size():
		label.text = ""
		$Panel.visible = false
		all_steps_complete.emit()
		return
	$Panel.visible = true
	label.text = _steps[_index]["message"]

func _input(_event: InputEvent) -> void:
	# Use _input (not _unhandled_input) so we still catch C even when the upgrade
	# menu also handles it and marks the event as handled.
	if _index >= _steps.size():
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
	if _index >= _steps.size():
		return
	if _steps[_index]["action"] == action:
		_advance()

func _advance() -> void:
	_index += 1
	_show_current()
