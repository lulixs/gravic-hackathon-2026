extends EnemyBase
## Garden Serpent (Level 2 boss). Glides toward the player and periodically lunges
## in a fast burst, wrapping around the edges of its arena. The level reveals the
## Broadsword when it dies (listens for EnemyBase's `died`, like the Broodmother).

@export var glide_speed := 70.0
@export var lunge_speed := 460.0
@export var lunge_interval := 3.0
@export var lunge_duration := 0.45
@export var engage_radius := 700.0      # only wakes once the player is in the den
@export var arena := Rect2(0, 1100, 2368, 372)  # region the serpent wraps within

var _player: Node2D
var _lunge_cd := 0.0
var _lunge_t := 0.0
var _lunge_dir := Vector2.ZERO

func _ready() -> void:
	if enemy_name == "":
		enemy_name = "Garden Serpent"
	max_hp = 260.0
	contact_damage = 12.0
	xp_value = 250
	health_drop_chance = 1.0
	health_bar_width = 72.0
	health_bar_offset_y = -26.0
	super._ready()
	add_to_group("boss")
	_lunge_cd = lunge_interval

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	if not _player:
		return

	# stay coiled until the player is in the den and close
	if not player_in_same_room() or global_position.distance_to(_player.global_position) > engage_radius:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		move_and_slide()
		_wrap()
		return

	if _lunge_t > 0.0:
		_lunge_t -= delta
		velocity = _lunge_dir * lunge_speed
	else:
		var to_player: Vector2 = _player.global_position - global_position
		velocity = velocity.move_toward(to_player.normalized() * glide_speed, 300.0 * delta)
		_lunge_cd -= delta
		if _lunge_cd <= 0.0:
			_lunge_cd = lunge_interval
			_lunge_dir = to_player.normalized()
			_lunge_t = lunge_duration

	move_and_slide()
	_wrap()

func _wrap() -> void:
	var p := global_position
	var minx := arena.position.x
	var maxx := arena.position.x + arena.size.x
	var miny := arena.position.y
	var maxy := arena.position.y + arena.size.y
	if p.x < minx:
		p.x = maxx
	elif p.x > maxx:
		p.x = minx
	if p.y < miny:
		p.y = maxy
	elif p.y > maxy:
		p.y = miny
	global_position = p
