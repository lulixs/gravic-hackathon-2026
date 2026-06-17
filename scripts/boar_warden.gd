extends EnemyBase

# The Boarden — boar-warden mini-boss. Stalks the player, winds up with a snort,
# then charges in a straight line until it slams a wall. After a charge it is
# STUNNED for a beat (plays the stun animation, deals no contact damage, wide open
# to punishment). Idle/stun art is animated from assets/boarden/{idle,stun}.

enum State { STALK, TELEGRAPH, CHARGE, STUN }

@export var stalk_speed := 55.0
@export var charge_speed := 540.0
@export var stalk_time := 1.4
@export var telegraph_time := 0.7
@export var charge_time := 0.85
@export var stun_duration := 1.6     # dazed + vulnerable after a charge
@export var engage_radius := 470.0
@export var base_contact := 9.0
@export var charge_contact := 20.0
@export var target_height := 80.0    # on-screen height of the boar in px
@export var art_faces_right := true  # flip if the source art actually faces left

const IDLE_FMT := "res://assets/boarden/idle/boarden idle_%04d.png"
const IDLE_COUNT := 9
const STUN_FMT := "res://assets/boarden/stun/boarden stun_%04d.png"
const STUN_COUNT := 12

var _player: Node2D
var _state := State.STALK
var _t := 0.0
var _charge_dir := Vector2.RIGHT
var _anim: AnimatedSprite2D

func _ready() -> void:
	if enemy_name == "":
		enemy_name = "The Boarden"
	max_hp = 170.0
	contact_damage = base_contact
	xp_value = 150
	health_drop_chance = 1.0
	health_bar_width = 64.0
	health_bar_offset_y = -(target_height * 0.5 + 12.0)
	knockback_resist = 0.9
	chase_standoff = 30.0
	contact_range = 48.0
	super._ready()
	add_to_group("boss")
	_setup_visuals()
	_t = stalk_time

# ---------------- visuals ----------------

func _setup_visuals() -> void:
	_anim = $Sprite as AnimatedSprite2D
	_anim.sprite_frames = _build_frames()
	var s := target_height / 540.0
	_anim.scale = Vector2(s, s)
	_anim.play("idle")
	# size the hurtbox (the body collider the sword reads) + contact hitbox to the art
	var w := 720.0 * s
	var body := RectangleShape2D.new()
	body.size = Vector2(w * 0.45, target_height * 0.5)
	($CollisionShape2D as CollisionShape2D).shape = body
	var hit := RectangleShape2D.new()
	hit.size = Vector2(w * 0.5, target_height * 0.56)
	($Hitbox/HitboxShape as CollisionShape2D).shape = hit

func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	_load_anim(sf, "idle", IDLE_FMT, IDLE_COUNT, 9.0, true)
	# stretch/squish the stun animation to last exactly stun_duration, played once
	_load_anim(sf, "stun", STUN_FMT, STUN_COUNT, float(STUN_COUNT) / stun_duration, false)
	return sf

func _load_anim(sf: SpriteFrames, anim_name: String, fmt: String, count: int, fps: float, loop: bool) -> void:
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, loop)
	for i in count:
		var path: String = fmt % i
		if ResourceLoader.exists(path):
			sf.add_frame(anim_name, load(path))

func _face(dir: Vector2) -> void:
	if _anim == null or absf(dir.x) < 0.1:
		return
	_anim.flip_h = (dir.x < 0.0) if art_faces_right else (dir.x > 0.0)

# ---------------- AI ----------------

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	if not _player:
		return

	# dormant until the player enters the warden's hall and gets close
	if not player_in_same_room() or global_position.distance_to(_player.global_position) > engage_radius:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		return

	match _state:
		State.STALK:
			_face(_player.global_position - global_position)
			velocity = velocity.move_toward(chase_velocity_to(_player.global_position, stalk_speed), 500.0 * delta)
			move_and_slide()
			_t -= delta
			if _t <= 0.0:
				_state = State.TELEGRAPH
				_t = telegraph_time
				if _sprite:
					_sprite.modulate = Color(1.0, 0.7, 0.3)  # snort windup tell
		State.TELEGRAPH:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			move_and_slide()
			_charge_dir = (_player.global_position - global_position).normalized()
			_face(_charge_dir)
			_t -= delta
			if _t <= 0.0:
				_state = State.CHARGE
				_t = charge_time
				contact_damage = charge_contact
				velocity = _charge_dir * charge_speed
				if _sprite:
					_sprite.modulate = Color.WHITE
		State.CHARGE:
			velocity = _charge_dir * charge_speed
			move_and_slide()
			_t -= delta
			if _t <= 0.0 or get_slide_collision_count() > 0:
				_enter_stun()
		State.STUN:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			move_and_slide()
			_t -= delta
			if _t <= 0.0:
				_state = State.STALK
				_t = stalk_time
				contact_damage = base_contact
				_anim.play("idle")

func _enter_stun() -> void:
	_state = State.STUN
	_t = stun_duration
	contact_damage = 0.0    # helpless while stunned
	velocity = Vector2.ZERO
	if _sprite:
		_sprite.modulate = Color.WHITE
	_anim.play("stun")
