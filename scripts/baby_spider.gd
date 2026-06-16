extends EnemyBase

@export var docile := false
@export var move_speed := 50.0
@export var chase_radius := 150.0
@export var wander_change_interval := 2.0
@export var target_height := 44.0   # on-screen height of the mob in pixels

# Facing art. Drop the pasted sprites in at these paths and they load automatically:
#   Image #2 (facing left)  -> res://assets/mob_left.png
#   Image #3 (facing right) -> res://assets/mob_right.png
const TEX_LEFT_PATH := "res://assets/mob_left.png"
const TEX_RIGHT_PATH := "res://assets/mob_right.png"

var _wander_dir := Vector2.ZERO
var _wander_timer := 0.0
var _player: Node2D
var _tex_left: Texture2D
var _tex_right: Texture2D
var _facing_right := true
@onready var _spr := $Sprite as Sprite2D

func _ready() -> void:
	if enemy_name == "":
		enemy_name = "Grub" if docile else "Creepling"
	super._ready()
	_setup_sprite()
	_pick_wander_dir()
	if docile:
		set_hitbox_enabled(false)
		contact_damage = 0.0

func _setup_sprite() -> void:
	if ResourceLoader.exists(TEX_LEFT_PATH):
		_tex_left = load(TEX_LEFT_PATH)
	if ResourceLoader.exists(TEX_RIGHT_PATH):
		_tex_right = load(TEX_RIGHT_PATH)

	var tex: Texture2D = _tex_right if _tex_right else _tex_left
	if tex == null:
		# no art yet — fall back to a small gray box so the mob is still visible/testable
		var img := Image.create(16, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.25, 0.25, 0.25))
		_spr.texture = ImageTexture.create_from_image(img)
		return

	# scale the source art down to the desired on-screen height
	var s := target_height / float(maxi(tex.get_height(), 1))
	_spr.scale = Vector2(s, s)
	_spr.texture = tex

	# size the hurtbox (the body collider the sword reads) + contact hitbox to the art.
	# kept a touch tighter than the full sprite so hits feel fair, not generous.
	var w := tex.get_width() * s * 0.75
	var h := target_height * 0.6
	var body_shape := RectangleShape2D.new()
	body_shape.size = Vector2(w, h)
	($CollisionShape2D as CollisionShape2D).shape = body_shape
	var hit_shape := RectangleShape2D.new()
	hit_shape.size = Vector2(w, h)
	($Hitbox/HitboxShape as CollisionShape2D).shape = hit_shape

	# float the health bar just above the (now correctly sized) sprite
	set_health_bar_offset(-(target_height * 0.5 + 10.0))

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _player:
		_player = get_tree().get_first_node_in_group("player")

	var target_vel := Vector2.ZERO
	if docile or not _player:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_pick_wander_dir()
		target_vel = _wander_dir * move_speed * 0.6
	else:
		var to_player: Vector2 = _player.global_position - global_position
		if to_player.length() <= chase_radius:
			target_vel = to_player.normalized() * move_speed
		else:
			_wander_timer -= delta
			if _wander_timer <= 0.0:
				_pick_wander_dir()
			target_vel = _wander_dir * move_speed * 0.6

	velocity = velocity.move_toward(target_vel, 600.0 * delta)
	move_and_slide()
	_update_facing()

func _update_facing() -> void:
	if absf(velocity.x) < 1.0:
		return
	var face_right := velocity.x > 0.0
	if face_right == _facing_right:
		return
	_facing_right = face_right
	if _tex_left and _tex_right:
		_spr.texture = _tex_right if face_right else _tex_left
		_spr.flip_h = false
	elif _spr.texture:
		# only one sprite available — mirror it. base art assumed to face right.
		_spr.flip_h = not face_right

func _pick_wander_dir() -> void:
	_wander_timer = wander_change_interval
	var angle := randf() * TAU
	_wander_dir = Vector2(cos(angle), sin(angle))
