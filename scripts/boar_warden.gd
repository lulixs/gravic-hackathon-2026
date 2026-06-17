extends EnemyBase

# The Boarden — boar-warden mini-boss. Stalks the player, winds up with a snort,
# then charges in a straight line until it slams a wall. The charge hits hard;
# bait it into the walls and punish the recovery. Drops the Broadsword (handled
# by the level on `died`).

enum State { STALK, TELEGRAPH, CHARGE, RECOVER }

@export var stalk_speed := 55.0
@export var charge_speed := 540.0
@export var stalk_time := 1.4
@export var telegraph_time := 0.7
@export var charge_time := 0.85
@export var recover_time := 0.9
@export var engage_radius := 470.0
@export var base_contact := 9.0
@export var charge_contact := 20.0

var _player: Node2D
var _state := State.STALK
var _t := 0.0
var _charge_dir := Vector2.RIGHT

func _ready() -> void:
	if enemy_name == "":
		enemy_name = "The Boarden"
	max_hp = 170.0
	contact_damage = base_contact
	xp_value = 150
	health_drop_chance = 1.0
	health_bar_width = 64.0
	health_bar_offset_y = -36.0
	super._ready()
	add_to_group("boss")
	_t = stalk_time

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
			var dir := (_player.global_position - global_position).normalized()
			velocity = velocity.move_toward(dir * stalk_speed, 500.0 * delta)
			move_and_slide()
			_t -= delta
			if _t <= 0.0:
				_state = State.TELEGRAPH
				_t = telegraph_time
				if _sprite:
					_sprite.modulate = Color(1.0, 0.7, 0.3)  # snort windup
		State.TELEGRAPH:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			move_and_slide()
			_charge_dir = (_player.global_position - global_position).normalized()
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
				_state = State.RECOVER
				_t = recover_time
				contact_damage = base_contact
		State.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
			move_and_slide()
			_t -= delta
			if _t <= 0.0:
				_state = State.STALK
				_t = stalk_time
