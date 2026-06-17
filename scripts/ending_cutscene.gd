extends Node2D

# Ending cutscene. Plays after the Flying Pig is beaten in Level 3. The fly reclaims
# its wings and rises; the Pig looms onto the screen one last time, then detonates in
# a flash of debris; the screen floods red and we land on THE END.
#
# Mostly auto-timed (it's a finale). ESC skips to the end. After THE END:
# SPACE = play again (back to the intro), ESC = quit.

const REPLAY_SCENE := "res://scenes/intro_cutscene.tscn"

const FLY_TEX := "res://assets/fly.png"
const PIG_FMT := "res://assets/BigPig/Idle/pig_%04d.png"

var _W := 1280.0
var _H := 720.0
var _ended := false
var _skipping := false
var _flapping := false

var _cam: Camera2D
var _stage: Node2D
var _flash: ColorRect
var _red: ColorRect
var _white: ColorRect
var _narr: RichTextLabel
var _end_label: Label
var _prompt: Label

var _fly_anchor: Node2D
var _fly: Sprite2D
var _wings: Array[Sprite2D] = []
var _pig_anchor: Node2D
var _pig: AnimatedSprite2D

func _ready() -> void:
	get_tree().paused = false   # we arrive straight off a paused dialogue
	var vp := get_viewport_rect().size
	if vp.x > 0:
		_W = vp.x
		_H = vp.y
	_build()
	_run()

# ---------------- build ----------------

func _build() -> void:
	# hopeful sky gradient behind everything
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.45, 0.68, 0.95))
	grad.set_color(1, Color(0.96, 0.92, 0.82))
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

	_cam = Camera2D.new()
	_cam.position = Vector2(_W * 0.5, _H * 0.5)
	add_child(_cam)
	_cam.make_current()

	_stage = Node2D.new()
	add_child(_stage)

	# ---- the fly + (hidden) wings ----
	_fly_anchor = Node2D.new()
	_fly_anchor.position = Vector2(_W * 0.5, _H * 0.66)
	_stage.add_child(_fly_anchor)

	var wing_tex := _make_wing_tex()
	for side in [-1, 1]:
		var wing := Sprite2D.new()
		wing.texture = wing_tex
		wing.scale = Vector2(1.7, 0.85)
		wing.position = Vector2(8.0 * side, -26.0)
		wing.offset = Vector2(64.0 * side, 0.0)   # pivot at the inner wing root
		wing.flip_h = side > 0
		wing.modulate = Color(0.85, 0.92, 1.0, 0.0)
		wing.z_index = -1
		_fly_anchor.add_child(wing)
		_wings.append(wing)

	_fly = Sprite2D.new()
	_fly.texture = load(FLY_TEX) if ResourceLoader.exists(FLY_TEX) else null
	_fly.hframes = 8
	_fly.frame = 0
	_fly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fly.scale = Vector2.ONE * (130.0 / 75.0)
	_fly.z_index = 1
	_fly_anchor.add_child(_fly)

	# perpetual gentle bob
	var bob := create_tween().set_loops()
	bob.tween_property(_fly, "position:y", -6.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_fly, "position:y", 0.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# ---- the pig (starts off-screen above) ----
	_pig_anchor = Node2D.new()
	_pig_anchor.position = Vector2(_W * 0.5, -_H * 0.4)
	_pig_anchor.modulate = Color(1, 1, 1, 0)
	_stage.add_child(_pig_anchor)
	_pig = _build_pig()
	_pig_anchor.add_child(_pig)

	# ---- overlays ----
	var ui := CanvasLayer.new()
	ui.layer = 2
	add_child(ui)

	_red = ColorRect.new()
	_red.color = Color(0.7, 0.04, 0.04, 0.0)
	_red.set_anchors_preset(Control.PRESET_FULL_RECT)
	_red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_red)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_flash)

	_narr = RichTextLabel.new()
	_narr.bbcode_enabled = true
	_narr.fit_content = true
	_narr.scroll_active = false
	_narr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narr.custom_minimum_size = Vector2(_W * 0.7, 0)
	_narr.size = Vector2(_W * 0.7, 120)
	_narr.position = Vector2(_W * 0.15, _H * 0.18)
	_narr.add_theme_font_size_override("normal_font_size", 28)
	_narr.add_theme_color_override("default_color", Color(0.15, 0.12, 0.1))
	_narr.modulate.a = 0.0
	ui.add_child(_narr)

	_end_label = Label.new()
	_end_label.text = "THE END"
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_end_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_label.add_theme_font_size_override("font_size", 96)
	_end_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_end_label.add_theme_color_override("font_outline_color", Color(0.2, 0, 0))
	_end_label.add_theme_constant_override("outline_size", 8)
	_end_label.modulate.a = 0.0
	ui.add_child(_end_label)

	_prompt = Label.new()
	_prompt.text = "SPACE — play again        ESC — quit"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.position.y = _H - 60
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.add_theme_color_override("font_color", Color(1, 0.85, 0.85))
	_prompt.modulate.a = 0.0
	ui.add_child(_prompt)

	_white = ColorRect.new()
	_white.color = Color(1, 1, 1, 1.0)   # open on a white bloom, then fade out
	_white.set_anchors_preset(Control.PRESET_FULL_RECT)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_white)

func _make_wing_tex() -> Texture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.95))
	grad.set_color(1, Color(0.7, 0.85, 1.0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	return gt

func _build_pig() -> AnimatedSprite2D:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 7.0)
	sf.set_animation_loop("idle", true)
	var first: Texture2D = null
	for i in range(0, 6):
		var p := PIG_FMT % i
		if ResourceLoader.exists(p):
			var t: Texture2D = load(p)
			sf.add_frame("idle", t)
			if first == null:
				first = t
	if first == null:
		var img := Image.create(120, 100, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.9, 0.6, 0.65))
		first = ImageTexture.create_from_image(img)
		sf.add_frame("idle", first)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sf
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var s := (_H * 0.5) / float(maxi(first.get_height(), 1))
	spr.scale = Vector2(s, s)
	spr.play("idle")
	return spr

# ---------------- sequence ----------------

func _run() -> void:
	# open on a white bloom that settles into the sky
	await _tween_to(_white, "color:a", 0.0, 1.2)
	if _skipping: return
	await _wait(0.4)

	# the fly remembers
	await _narrate("Your wings… you remember them now.", 2.4)
	if _skipping: return

	# WINGS RETURN — sparkle flash, wings fade in, flapping begins, the fly rises
	_flash_white(0.45, 0.5)
	for w in _wings:
		create_tween().tween_property(w, "modulate:a", 0.8, 0.6)
	_start_flapping()
	# triumphant rise + grow
	var base: Vector2 = _fly_anchor.position
	var rise := create_tween().set_parallel(true)
	rise.tween_property(_fly_anchor, "position:y", base.y - _H * 0.06, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rise.tween_property(_fly, "scale", _fly.scale * 1.12, 1.0).set_trans(Tween.TRANS_SINE)
	await rise.finished
	if _skipping: return
	await _wait(1.0)

	# THE PIG COMES ON SCREEN — descends and looms
	var pig_base := Vector2(_W * 0.5, _H * 0.40)
	_pig_anchor.modulate = Color(1, 1, 1, 1)
	var enter := create_tween()
	enter.tween_property(_pig_anchor, "position", pig_base, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await enter.finished
	if _skipping: return
	_shake(8.0, 0.3)
	# a last menacing swell
	var ps := _pig.scale
	var swell := create_tween()
	swell.tween_property(_pig, "scale", ps * 1.1, 0.5).set_trans(Tween.TRANS_SINE)
	await swell.finished
	if _skipping: return
	await _wait(0.5)

	# THE PIG EXPLODES
	await _explode_pig()

	# SCREEN GOES RED
	await _go_red()
	_show_the_end()

func _explode_pig() -> void:
	var pos := _pig_anchor.position
	# debris burst
	var ex := CPUParticles2D.new()
	ex.position = pos
	ex.z_index = 5
	ex.one_shot = true
	ex.explosiveness = 1.0
	ex.amount = 90
	ex.lifetime = 1.1
	ex.spread = 180.0
	ex.direction = Vector2(0, -1)
	ex.initial_velocity_min = 220.0
	ex.initial_velocity_max = 620.0
	ex.gravity = Vector2(0, 520.0)
	ex.scale_amount_min = 4.0
	ex.scale_amount_max = 12.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 0.8))
	ramp.set_color(1, Color(0.8, 0.1, 0.1, 0.0))
	ramp.add_point(0.4, Color(1.0, 0.55, 0.2))
	ex.color_ramp = ramp
	_stage.add_child(ex)
	ex.emitting = true

	# white blast + shake, pig vanishes
	_flash_white(0.85, 0.7)
	_shake(22.0, 0.6)
	var vanish := create_tween().set_parallel(true)
	vanish.tween_property(_pig, "scale", _pig.scale * 1.4, 0.12)
	vanish.tween_property(_pig_anchor, "modulate:a", 0.0, 0.14)
	await vanish.finished
	if _skipping: return
	await _wait(0.5)

func _go_red() -> void:
	var t := create_tween()
	t.tween_property(_red, "color:a", 1.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await t.finished

func _show_the_end() -> void:
	_ended = true
	create_tween().tween_property(_end_label, "modulate:a", 1.0, 1.0)
	await _wait(1.2)
	create_tween().tween_property(_prompt, "modulate:a", 1.0, 0.8)

# ---------------- helpers ----------------

func _narrate(text: String, hold: float) -> void:
	_narr.text = "[center]%s[/center]" % text
	await _tween_to(_narr, "modulate:a", 1.0, 0.7)
	if _skipping: return
	await _wait(hold)
	if _skipping: return
	await _tween_to(_narr, "modulate:a", 0.0, 0.5)

func _start_flapping() -> void:
	if _flapping:
		return
	_flapping = true
	var i := 0
	for w in _wings:
		var side := -1.0 if i == 0 else 1.0
		var base := 0.5 * side
		w.rotation = base
		var flap := create_tween().set_loops()
		flap.tween_property(w, "rotation", base - 0.32 * side, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		flap.tween_property(w, "rotation", base, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		i += 1

func _flash_white(peak: float, fade: float) -> void:
	_flash.color.a = 0.0
	var t := create_tween()
	t.tween_property(_flash, "color:a", peak, 0.06)
	t.tween_property(_flash, "color:a", 0.0, fade)

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

# ---------------- input ----------------

func _input(event: InputEvent) -> void:
	if _ended:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			get_tree().quit()
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("advance_dialogue") \
				or event.is_action_pressed("attack") or event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			get_tree().change_scene_to_file(REPLAY_SCENE)
		return
	# before the finale lands, ESC fast-forwards straight to THE END
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_skip_to_end()

func _skip_to_end() -> void:
	if _skipping or _ended:
		return
	_skipping = true
	# snap to the final state
	for w in _wings:
		w.modulate.a = 0.8
	_start_flapping()
	_pig_anchor.modulate.a = 0.0
	_flash.color.a = 0.0
	_white.color.a = 0.0
	_narr.modulate.a = 0.0
	_red.color.a = 1.0
	_show_the_end()
