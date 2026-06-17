extends EnemyBase

# The Flying Pig — final boss. The tyrant who stole your wings. Hovers at range
# firing 3-shot volleys, and every few seconds dive-bombs across the throne room.
# The level listens for `died` to roll the victory screen.

const PELLET := preload("res://scenes/garbage_pellet.tscn")

enum State { HOVER, DIVE, RECOVER }

@export var hover_speed := 70.0
@export var keep_distance := 170.0
@export var dive_speed := 470.0
@export var shoot_interval := 1.7
@export var dive_interval := 5.0
@export var dive_time := 0.55
@export var recover_time := 0.8
@export var engage_radius := 640.0
@export var projectile_damage := 9.0
@export var hover_contact := 12.0
@export var dive_contact := 18.0

var _player: Node2D
var _state := State.HOVER
var _t := 0.0
var _shoot_t := 0.0
var _dive_t := 0.0
var _dive_dir := Vector2.RIGHT

func _ready() -> void:
	if enemy_name == "":
		enemy_name = "The Flying Pig"
	max_hp = 360.0
	contact_damage = hover_contact
	xp_value = 500
	health_drop_chance = 0.0
	health_bar_width = 72.0
	health_bar_offset_y = -44.0
	knockback_resist = 0.9
	contact_range = 46.0
	super._ready()
	add_to_group("boss")
	_shoot_t = shoot_interval
	_dive_t = dive_interval

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	if not _player:
		return

	if not player_in_same_room() or global_position.distance_to(_player.global_position) > engage_radius:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		move_and_slide()
		return

	# fire volleys while hovering/recovering (not mid-dive)
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
