extends EnemyBase

@export var docile := false
@export var move_speed := 50.0     # idle wander speed
@export var chase_speed := 140.0   # speed when hunting the player (was tied to move_speed)
@export var chase_radius := 150.0
@export var wander_change_interval := 2.0
@export var target_height := 56.0   # on-screen height of the spider in pixels

# Single hand-drawn sprite (the drawing faces LEFT). We mirror it horizontally
# when the spider moves right, so one image covers both directions.
const TEX_PATH := "res://assets/baby_spider.png"
const ART_FACES_RIGHT := false

var _wander_dir := Vector2.ZERO
var _wander_timer := 0.0
var _player: Node2D
var _tex: Texture2D
var _facing_right := false
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
	else:
		contact_damage = 5.0  # light touch damage while chasing in its own room

func _setup_sprite() -> void:
	if ResourceLoader.exists(TEX_PATH):
		_tex = load(TEX_PATH)
	if _tex == null:
		# art not imported yet — fall back to a small gray box so the mob is still visible
		var img := Image.create(16, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.25, 0.25, 0.25))
		_spr.texture = ImageTexture.create_from_image(img)
		return

	# scale the drawing down to the desired on-screen height, and use linear filtering
	# so the hand-drawn art stays smooth instead of pixelated when shrunk.
	var s := target_height / float(maxi(_tex.get_height(), 1))
	_spr.texture = _tex
	_spr.scale = Vector2(s, s)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_apply_facing()

	# size the hurtbox (body collider the sword reads) + the contact hitbox to the art,
	# kept tighter than the full sprite since the legs are mostly empty space.
	var w := _tex.get_width() * s * 0.6
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
	if knockback_active(delta):
		_update_facing()
		return
	if not _player:
		_player = get_tree().get_first_node_in_group("player")

	var target_vel := Vector2.ZERO
	if docile or not _player:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_pick_wander_dir()
		target_vel = _wander_dir * move_speed * 0.6 * cobweb_factor()
	else:
		# room-based aggro: if you're in this spider's room, it hunts you anywhere in it.
		# Outside its room it stays put (no wandering) so it doesn't look "awake" before
		# the player arrives.
		if player_in_same_room():
			target_vel = chase_velocity_to(_player.global_position, chase_speed)
		else:
			target_vel = Vector2.ZERO

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
	_apply_facing()

func _apply_facing() -> void:
	if _spr.texture == null:
		return
	# flip only when the desired facing differs from the art's native (left) facing
	_spr.flip_h = (_facing_right != ART_FACES_RIGHT)

func _pick_wander_dir() -> void:
	_wander_timer = wander_change_interval
	var angle := randf() * TAU
	_wander_dir = Vector2(cos(angle), sin(angle))
