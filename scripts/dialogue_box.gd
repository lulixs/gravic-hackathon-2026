extends CanvasLayer

signal finished

const CHAR_INTERVAL := 0.025

@onready var panel: Control = $Panel
@onready var speaker_label: Label = $Panel/VBox/Speaker
@onready var body_label: RichTextLabel = $Panel/VBox/Body
@onready var hint_label: Label = $Panel/VBox/Hint

var _lines: Array = []
var _index := 0
var _typing := false
var _typed_chars := 0.0
var _full_text := ""
var _active := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	panel.visible = false

func play_lines(lines: Array) -> void:
	_lines = lines
	_index = 0
	_active = true
	panel.visible = true
	get_tree().paused = true
	_show_line()

func _show_line() -> void:
	if _index >= _lines.size():
		_end()
		return
	var entry = _lines[_index]
	var speaker := ""
	var body := ""
	if entry is String:
		body = entry
	elif entry is Dictionary:
		speaker = entry.get("speaker", "")
		body = entry.get("text", "")
	speaker_label.text = speaker
	speaker_label.visible = speaker != ""
	_full_text = body
	body_label.text = ""
	_typed_chars = 0.0
	_typing = true
	hint_label.text = "▾ skip"

func _process(delta: float) -> void:
	if not _typing:
		return
	_typed_chars += delta / CHAR_INTERVAL
	var n := int(_typed_chars)
	if n >= _full_text.length():
		body_label.text = _full_text
		_typing = false
		hint_label.text = "▾ SPACE / click"
	else:
		body_label.text = _full_text.substr(0, n)

func _input(event: InputEvent) -> void:
	if not _active:
		return
	var pressed := event.is_action_pressed("advance_dialogue") \
		or event.is_action_pressed("attack") \
		or event.is_action_pressed("interact")
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		# first press finishes the type-on
		body_label.text = _full_text
		_typing = false
		hint_label.text = "▾ SPACE / click"
	else:
		_index += 1
		_show_line()

func _end() -> void:
	_active = false
	panel.visible = false
	get_tree().paused = false
	finished.emit()
