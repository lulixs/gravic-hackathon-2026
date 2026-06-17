extends Node2D

# Animated opening cutscene. The Flying Pig and his three wardens (Broodmother,
# Bullfrog, Boarden) gather and gloat over the world below, then we cut to the fly's
# quiet defiance and drop into the tutorial. Everything (sprites, gradient sky,
# letterbox, spotlights, shake) is built in code so there are no scene dependencies.
#
# SPACE / click / attack / interact = advance.  ESC = skip to the game.

const NEXT_SCENE := "res://levels/level_0_tutorial.tscn"

# boss idle frame sources
const PIG_FMT   := "res://assets/BigPig/Idle/pig_%04d.png"
const MOM_FMT   := "res://assets/MotherSpider/Idle/mother-spider-2_%04d.png"
const FROG_FMT  := "res://assets/Frog/frog_%04d.png"
const BOAR_FMT  := "res://assets/boarden/idle/boarden idle_%04d.png"

# speaker colors
const C_NARR := Color(0.86, 0.86, 0.95)
const C_PIG  := Color(1.0, 0.62, 0.3)
const C_MOM  := Color(0.84, 0.5, 0.95)
const C_FROG := Color(0.6, 0.85, 0.4)
const C_BOAR := Color(0.78, 0.78, 0.85)
const C_FLY  := Color(0.6, 0.85, 1.0)

const DIM := Color(0.32, 0.30, 0.40, 1.0)
const LIT := Color(1.0, 1.0, 1.0, 1.0)
const HIDDEN := Color(1.0, 1.0, 1.0, 0.0)

var _W := 1280.0
var _H := 720.0

var _typing := false
var _waiting := false
var _done := false
signal _advanced

# nodes
var _cam: Camera2D
var _stage: Node2D
var _bars_top: ColorRect
var _bars_bot: ColorRect
var _flash: ColorRect
var _fade: ColorRect
var _narr: RichTextLabel
var _panel: PanelContainer
var _speaker: Label
var _body: RichTextLabel
var _hint: Label

# boss anchors {anchor:Node2D, base:Vector2, sprite:AnimatedSprite2D}
var _pig := {}
var _mom := {}
var _frog := {}
var _boar := {}

func _ready() -> void:
	var vp := get_viewport_rect().size
	if vp.x > 0:
		_W = vp.x
		_H = vp.y
	_build()
	_run()

# ---------------- build ----------------

func _build() -> void:
	# background sky gradient (behind everything)
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.12, 0.05, 0.17))
	grad.set_color(1, Color(0.02, 0.02, 0.04))
	grad.add_point(0.55, Color(0.07, 0.04, 0.12))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 256
	gt.height = 256
	var bg := TextureRect.new()
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(bg)
	# slow drifting glow disc behind the throne
	var glow := _make_glow()
	bg_layer.add_child(glow)

	# camera so stage coords are screen coords
	_cam = Camera2D.new()
	_cam.position = Vector2(_W * 0.5, _H * 0.5)
	add_child(_cam)
	_cam.make_current()

	_stage = Node2D.new()
	add_child(_stage)

	# bosses — kept in the upper ~two thirds so the dialogue panel (top at _H-200)
	# never overlaps them
	_pig  = _spawn_boss(PIG_FMT, 0, 5, 7.0, _H * 0.38, Vector2(_W * 0.5, _H * 0.26), 0)
	_mom  = _spawn_boss(MOM_FMT, 0, 11, 9.0, _H * 0.21, Vector2(_W * 0.20, _H * 0.54), 2)
	_boar = _spawn_boss(BOAR_FMT, 0, 8, 8.0, _H * 0.23, Vector2(_W * 0.50, _H * 0.55), 2)
	_frog = _spawn_boss(FROG_FMT, 1, 8, 8.0, _H * 0.21, Vector2(_W * 0.80, _H * 0.54), 2)

	# UI overlay
	var ui := CanvasLayer.new()
	ui.layer = 2
	add_child(ui)

	_bars_top = ColorRect.new()
	_bars_top.color = Color.BLACK
	_bars_top.position = Vector2(0, 0)
	_bars_top.size = Vector2(_W, 0)
	ui.add_child(_bars_top)
	_bars_bot = ColorRect.new()
	_bars_bot.color = Color.BLACK
	_bars_bot.size = Vector2(_W, 0)
	_bars_bot.position = Vector2(0, _H)
	ui.add_child(_bars_bot)

	# centered narration
	_narr = RichTextLabel.new()
	_narr.bbcode_enabled = true
	_narr.fit_content = true
	_narr.scroll_active = false
	_narr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narr.custom_minimum_size = Vector2(_W * 0.7, 0)
	_narr.size = Vector2(_W * 0.7, 120)
	_narr.position = Vector2(_W * 0.15, _H * 0.40)
	_narr.add_theme_font_size_override("normal_font_size", 30)
	_narr.add_theme_color_override("default_color", C_NARR)
	_narr.modulate.a = 0.0
	ui.add_child(_narr)

	# bottom dialogue panel
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.85, 0.78, 0.45, 1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 14
	sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.position = Vector2(60, _H - 200)
	_panel.size = Vector2(_W - 120, 150)
	_panel.modulate.a = 0.0
	ui.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_panel.add_child(vb)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 22)
	vb.add_child(_speaker)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(0, 86)
	_body.add_theme_font_size_override("normal_font_size", 20)
	vb.add_child(_body)
	_hint = Label.new()
	_hint.text = "▾ SPACE   •   ESC to skip"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vb.add_child(_hint)

	# red flash + black fade (top-most)
	_flash = ColorRect.new()
	_flash.color = Color(0.8, 0.05, 0.05, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_flash)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1.0)   # start black, fade up into the scene
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_fade)

func _make_glow() -> Control:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.5, 0.2, 0.5, 0.5))
	grad.set_color(1, Color(0.5, 0.2, 0.5, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	var tr := TextureRect.new()
	tr.texture = gt
	tr.size = Vector2(_W * 0.9, _H * 0.9)
	tr.position = Vector2(_W * 0.5 - tr.size.x * 0.5, _H * 0.18)
	tr.modulate.a = 0.0
	tr.name = "Glow"
	return tr

func _spawn_boss(fmt: String, start: int, end: int, fps: float, target_h: float, base: Vector2, z: int) -> Dictionary:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("idle")
	sf.set_animation_speed("idle", fps)
	sf.set_animation_loop("idle", true)
	var first: Texture2D = null
	for i in range(start, end + 1):
		var p := fmt % i
		if ResourceLoader.exists(p):
			var t: Texture2D = load(p)
			sf.add_frame("idle", t)
			if first == null:
				first = t
	if first == null:
		var img := Image.create(80, 80, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.3, 0.3, 0.35))
		first = ImageTexture.create_from_image(img)
		sf.add_frame("idle", first)

	var anchor := Node2D.new()
	anchor.position = base
	anchor.modulate = HIDDEN
	anchor.z_index = z
	_stage.add_child(anchor)

	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sf
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var s := target_h / float(maxi(first.get_height(), 1))
	spr.scale = Vector2(s, s)
	spr.play("idle")
	anchor.add_child(spr)

	# perpetual subtle bob
	var bob := create_tween().set_loops()
	bob.tween_property(spr, "position:y", -7.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(spr, "position:y", 0.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	return {"anchor": anchor, "sprite": spr, "base": base, "scale": s}

# ---------------- sequence ----------------

func _run() -> void:
	# fade up from black
	await _tween_to(_fade, "color:a", 0.0, 1.0)

	# cinematic letterbox bars in
	var bar_h := _H * 0.10
	var tb := create_tween().set_parallel(true)
	tb.tween_property(_bars_top, "size:y", bar_h, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tb.tween_property(_bars_bot, "position:y", _H - bar_h, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tb.tween_property(_bars_bot, "size:y", bar_h, 0.7)

	# slow glow bloom behind the throne
	var glow := get_node_or_null("CanvasLayer/Glow")
	if glow == null:
		# glow lives under the bg layer (first CanvasLayer child)
		for c in get_children():
			if c is CanvasLayer:
				glow = c.get_node_or_null("Glow")
				if glow:
					break
	if glow:
		create_tween().tween_property(glow, "modulate:a", 1.0, 4.0)

	# ---- cosmic narration over the empty sky ----
	await narrate("We were never meant to walk.")
	await narrate("We were meant to drift — to belong to the air without asking permission.")
	await narrate("But far below, something began to look [color=#ff8a3a]upward[/color]…")

	# ---- the Pig descends ----
	var pig_base: Vector2 = _pig["base"]
	_pig["anchor"].position = pig_base + Vector2(0, -_H * 0.7)
	_pig["anchor"].modulate = LIT
	var drop := create_tween().set_parallel(true)
	drop.tween_property(_pig["anchor"], "position", pig_base, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await drop.finished
	_shake(10.0, 0.35)
	await _wait(0.25)

	await say("The Flying Pig", "The sky belongs to me now. Every cloud. Every current. They rise only when I [color=#ff8a3a]permit[/color] it.", C_PIG)
	await say("The Flying Pig", "But a throne needs jaws beneath it. Rise, my wardens — show the crawling world what waits for it.", C_PIG)

	# ---- the wardens answer, one spotlight at a time ----
	await _enter(_mom)
	_spotlight(_mom)
	await say("The Broodmother", "Let them wander into my silk and call it shelter. I bind them slowly… so they feel every thread.", C_MOM)

	await _enter(_frog)
	_spotlight(_frog)
	await say("The Bullfrog", "Everything falls, in the end. And everything that falls into my pond… I keep.", C_FROG)

	await _enter(_boar)
	_spotlight(_boar)
	_shake(8.0, 0.4)
	await say("The Boarden", "Give me a gate and a thing to crush. There is no door I cannot close forever.", C_BOAR)

	# ---- the Pig's climax: dim the wardens, the Pig swells and looms ----
	_dim_others(_pig)
	var ps: float = _pig["scale"]
	create_tween().tween_property(_pig["sprite"], "scale", Vector2(ps, ps) * 1.2, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await say("The Flying Pig", "Three jaws below. The heavens above. Who could ever climb through all of that?", C_PIG)
	_flash_red()
	_shake(14.0, 0.5)
	await say("The Flying Pig", "Let them try. Let them break on every floor. HAHAHA—", C_PIG)

	# ---- hard cut to near-black + the fly's defiance ----
	await _tween_to(_fade, "color:a", 0.92, 0.5)
	_panel.modulate.a = 0.0
	await _wait(0.4)
	# reveal panel over the darkness for the quiet line
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.4)
	await say("You", "[i]…He forgot one thing.[/i]", C_FLY)
	await say("You", "[i]The smallest wings still remember the sky.[/i]", C_FLY)

	await _finish()

# ---------------- helpers ----------------

func narrate(text: String) -> void:
	if _done:
		return
	_narr.text = "[center]%s[/center]" % text
	await _tween_to(_narr, "modulate:a", 1.0, 0.7)
	_waiting = true
	await _advanced
	_waiting = false
	await _tween_to(_narr, "modulate:a", 0.0, 0.5)

func say(speaker: String, text: String, col: Color) -> void:
	if _done:
		return
	if _panel.modulate.a < 1.0:
		create_tween().tween_property(_panel, "modulate:a", 1.0, 0.3)
	_speaker.text = speaker
	_speaker.add_theme_color_override("font_color", col)
	_body.text = text
	_body.visible_characters = 0
	_typing = true
	var n := _body.get_total_character_count()
	var i := 0
	while i < n and _typing:
		i += 1
		_body.visible_characters = i
		await get_tree().create_timer(0.018).timeout
	_body.visible_characters = -1
	_typing = false
	_waiting = true
	await _advanced
	_waiting = false

func _enter(boss: Dictionary) -> void:
	if _done:
		return
	var anchor: Node2D = boss["anchor"]
	var base: Vector2 = boss["base"]
	anchor.position = base + Vector2(0, 70)
	anchor.modulate = HIDDEN
	var t := create_tween().set_parallel(true)
	t.tween_property(anchor, "modulate", DIM, 0.55)
	t.tween_property(anchor, "position", base, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await t.finished

func _spotlight(active: Dictionary) -> void:
	_dim_others(active)
	var spr: AnimatedSprite2D = active["sprite"]
	var sc: float = active["scale"]
	var p := create_tween()
	p.tween_property(spr, "scale", Vector2(sc, sc) * 1.08, 0.18).set_trans(Tween.TRANS_SINE)
	p.tween_property(spr, "scale", Vector2(sc, sc), 0.18).set_trans(Tween.TRANS_SINE)

func _dim_others(active: Dictionary) -> void:
	for boss in [_pig, _mom, _frog, _boar]:
		if boss.is_empty():
			continue
		var is_active: bool = boss["anchor"] == active["anchor"]
		# leave wardens that haven't entered yet untouched (still hidden)
		if not is_active and boss["anchor"].modulate.a < 0.05:
			continue
		var target: Color = LIT if is_active else DIM
		create_tween().tween_property(boss["anchor"], "modulate", target, 0.4)

func _flash_red() -> void:
	_flash.color.a = 0.0
	var t := create_tween()
	t.tween_property(_flash, "color:a", 0.55, 0.06)
	t.tween_property(_flash, "color:a", 0.0, 0.45)

func _shake(amount: float, dur: float) -> void:
	var steps := 9
	var t := create_tween()
	for i in steps:
		var off := Vector2(randf_range(-amount, amount), randf_range(-amount, amount)) * (1.0 - float(i) / steps)
		t.tween_property(_cam, "offset", off, dur / steps)
	t.tween_property(_cam, "offset", Vector2.ZERO, dur / steps)

func _tween_to(node: Object, prop: String, val, dur: float) -> void:
	var t := create_tween()
	t.tween_property(node, prop, val, dur)
	await t.finished

func _wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout

func _finish() -> void:
	if _done:
		return
	_done = true
	await _tween_to(_fade, "color:a", 1.0, 0.8)
	get_tree().change_scene_to_file(NEXT_SCENE)

func _skip() -> void:
	if _done:
		return
	_done = true
	get_tree().change_scene_to_file(NEXT_SCENE)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_skip()
		return
	var adv := event.is_action_pressed("ui_accept") \
		or event.is_action_pressed("advance_dialogue") \
		or event.is_action_pressed("attack") \
		or event.is_action_pressed("interact")
	if not adv:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_typing = false
	elif _waiting:
		_advanced.emit()
