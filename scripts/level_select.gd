extends CanvasLayer

# DEBUG level-select overlay. Press L to toggle, click a level to jump straight to
# it. Registered as an autoload so it exists in every scene. TEMPORARY — to remove
# later, delete the LevelSelect autoload line in project.godot (and this script).

const LEVELS := [
	{"name": "0 · Tutorial", "path": "res://levels/level_0_tutorial.tscn"},
	{"name": "1 · Basement", "path": "res://levels/level_1_basement.tscn"},
	{"name": "2 · Garden", "path": "res://levels/level_2_garden.tscn"},
	{"name": "3 · Castle", "path": "res://levels/level_3_castle.tscn"},
]

var _panel: PanelContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # works even while a level is paused
	layer = 128
	_build_ui()
	_panel.visible = false

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.offset_left = 8.0
	_panel.offset_top = 8.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	sb.set_content_margin_all(8.0)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_panel.add_child(vb)

	var title := Label.new()
	title.text = "LEVEL SELECT (debug · L)"
	title.add_theme_font_size_override("font_size", 11)
	vb.add_child(title)

	for lvl in LEVELS:
		var b := Button.new()
		b.text = lvl["name"]
		b.custom_minimum_size = Vector2(150, 22)
		b.add_theme_font_size_override("font_size", 11)
		var path: String = lvl["path"]
		b.pressed.connect(func() -> void: _go(path))
		vb.add_child(b)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()

func _go(path: String) -> void:
	_panel.visible = false
	get_tree().paused = false  # in case a dialogue/menu had paused the tree
	get_tree().change_scene_to_file(path)
