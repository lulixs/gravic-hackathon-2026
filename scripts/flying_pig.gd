extends EnemyBase

# The Flying Pig — final boss. Hovers at range firing 3-shot spit volleys, and every
# few seconds dive-bombs (charge) across the throne room. Plays idle / spit / charge
# / death animations from assets/BigPig. The level listens for `died` (emitted only
# once the death animation finishes) to roll the victory screen.

const PELLET := preload("res://scenes/garbage_pellet.tscn")

enum State { HOVER, DIVE, RECOVER }

@export var hover_speed := 70.0
@export var keep_distance := 170.0
@export var dive_speed := 470.0
@export var shoot_interval := 5.1
@export var dive_interval := 5.0
@export var dive_time := 0.55
@export var recover_time := 0.8
@export var engage_radius := 640.0
@export var projectile_damage := 9.0
@export var hover_contact := 12.0
@export var dive_contact := 18.0
@export var target_height := 150.0   # on-screen height of the pig in px
@export var art_faces_right := true

var _player: Node2D
var _state := State.HOVER
var _t := 0.0
var _shoot_t := 0.0
var _dive_t := 0.0
var _dive_dir := Vector2.RIGHT
var _anim: AnimatedSprite2D
var _oneshot := false   # a one-shot anim (spit) is playing; don't override it
var _dead := false

func _ready() -> void:
	if enemy_name == "":
		enemy_name = "The Flying Pig"
	max_hp = 540.0       # +50% health (was 360)
	contact_damage = hover_contact
	xp_value = 500
	health_drop_chance = 0.0
	health_bar_width = 80.0
	health_bar_offset_y = -(target_height * 0.5 + 14.0)
	knockback_resist = 0.95
	contact_range = 60.0
	super._ready()
	add_to_group("boss")
	_shoot_t = shoot_interval
	_dive_t = dive_interval
	_setup_visuals()

# ---------------- visuals ----------------

func _setup_visuals() -> void:
	_anim = $Sprite as AnimatedSprite2D
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_anim.sprite_frames = _build_frames()
	var s := target_height / 540.0
	_anim.scale = Vector2(s, s)
	_anim.play("idle")
	var w := 720.0 * s
	var body := RectangleShape2D.new()
	body.size = Vector2(w * 0.42, target_height * 0.62)
	($CollisionShape2D as CollisionShape2D).shape = body
	var hit := RectangleShape2D.new()
	hit.size = Vector2(w * 0.48, target_height * 0.7)
	($Hitbox/HitboxShape as CollisionShape2D).shape = hit
	if not _anim.animation_finished.is_connected(_on_anim_finished):
		_anim.animation_finished.connect(_on_anim_finished)

func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	_load_range(sf, "idle", "res://assets/BigPig/Idle/pig_%04d.png", 0, 5, 6.0, true)
	_load_range(sf, "spit", "res://assets/BigPig/Spit/pig_%04d.png", 6, 13, 12.0, false)
	_load_range(sf, "charge", "res://assets/BigPig/Charge/pig_%04d.png", 14, 19, 10.0, true)
	_load_range(sf, "death", "res://assets/BigPig/Death/pig_%04d.png", 20, 27, 5.0, false)
	return sf

func _load_range(sf: SpriteFrames, anim_name: String, fmt: String, start: int, end: int, fps: float, loop: bool) -> void:
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, loop)
	for i in range(start, end + 1):
		var path: String = fmt % i
		if ResourceLoader.exists(path):
			sf.add_frame(anim_name, load(path))

func _face() -> void:
	if _anim == null or _player == null:
		return
	var player_right := _player.global_position.x >= global_position.x
	_anim.flip_h = (not player_right) if art_faces_right else player_right

func _update_anim() -> void:
	if _oneshot or _dead:
		return
	var want := "charge" if _state == State.DIVE else "idle"
	if _anim and _anim.animation != want:
		_anim.play(want)

# ---------------- AI ----------------

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _dead:
		return
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	if not _player:
		return

	if not player_in_same_room() or global_position.distance_to(_player.global_position) > engage_radius:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		move_and_slide()
		_update_anim()
		return

	# spit volleys while hovering/recovering (not mid-dive)
	if _state != State.DIVE:
		_shoot_t -= delta
		if _shoot_t <= 0.0:
			_shoot_t = shoot_interval
			_shoot_volley()

	match _state:
		State.HOVER:
			var to_player := _player.global_position - global_position
			var dist := to_player.length()
			var dir := to_player.normalized() if to_player != Vector2.ZERO else Vector2.RIGHT
			var desired: Vector2
			if dist > keep_distance + 40.0:
				desired = dir * hover_speed
			elif dist < keep_distance - 40.0:
				desired = -dir * hover_speed
			else:
				desired = Vector2(-dir.y, dir.x) * hover_speed   # strafe in a circle
			velocity = velocity.move_toward(desired, 500.0 * delta)
			move_and_slide()
			_dive_t -= delta
			if _dive_t <= 0.0:
				_dive_t = dive_interval
				_dive_dir = dir
				_state = State.DIVE
				_t = dive_time
				contact_damage = dive_contact
				velocity = _dive_dir * dive_speed
		State.DIVE:
			velocity = _dive_dir * dive_speed
			move_and_slide()
			_t -= delta
			if _t <= 0.0 or get_slide_collision_count() > 0:
				_state = State.RECOVER
				_t = recover_time
				contact_damage = hover_contact
		State.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
			move_and_slide()
			_t -= delta
			if _t <= 0.0:
				_state = State.HOVER

	_face()
	_update_anim()

func _shoot_volley() -> void:
	var base := (_player.global_position - global_position).normalized()
	if base == Vector2.ZERO:
		base = Vector2.RIGHT
	for ang in [-0.26, 0.0, 0.26]:
		var p := PELLET.instantiate()
		get_parent().add_child(p)
		p.global_position = global_position
		p.dir = base.rotated(ang)
		p.damage = projectile_damage
		p.speed = 155.0
	# play the spit animation as a one-shot over the idle hover
	if _anim:
		_oneshot = true
		_anim.play("spit")

# ---------------- death ----------------

func die() -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	set_hitbox_enabled(false)
	contact_damage = 0.0
	velocity = Vector2.ZERO
	if _sprite:
		_sprite.modulate = Color.WHITE
	# play the death animation; victory fires when it finishes (see _on_anim_finished)
	if _anim:
		_anim.play("death")
	else:
		_finish_death()

func _on_anim_finished() -> void:
	if _dead:
		_finish_death()
		return
	if _anim and _anim.animation == "spit":
		_oneshot = false

func _finish_death() -> void:
	_drop_loot()
	died.emit()
	queue_free()
