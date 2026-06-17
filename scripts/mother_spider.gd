extends EnemyBase

# Broodmother boss. Slowly closes on the player, plants egg sacs, and spits webs.
# The level listens for `died` (from EnemyBase) to reveal the Flatsword + finish.

const SACK := preload("res://scenes/spider_sack.tscn")
const WEB := preload("res://scenes/web_projectile.tscn")

@export var move_speed := 34.0
@export var sack_interval := 7.0
@export var web_interval := 4.0
@export var max_sacks := 1   # never more than one of her egg sacs alive at a time
@export var engage_radius := 420.0  # only wakes once the player is in her chamber AND near

var _player: Node2D
var _sack_t := 0.0
var _web_t := 0.0
var _sacks := 0

func _ready() -> void:
	if enemy_name == "":
		enemy_name = "Broodmother"
	max_hp = 220.0
	contact_damage = 10.0
	xp_value = 200
	health_drop_chance = 1.0
	health_bar_width = 64.0
	health_bar_offset_y = -38.0
	knockback_resist = 0.82
	chase_standoff = 34.0
	contact_range = 46.0
	super._ready()
	add_to_group("boss")
	_sack_t = sack_interval
	_web_t = web_interval

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if knockback_active(delta):
		return
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	if not _player:
		return

	# dormant until the player is in her room and close (so she doesn't attack
	# through the gate while you're solving the pipe puzzle)
	if not player_in_same_room() or global_position.distance_to(_player.global_position) > engage_radius:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		move_and_slide()
		return

	velocity = velocity.move_toward(chase_velocity_to(_player.global_position, move_speed), 400.0 * delta)
	move_and_slide()

	_sack_t -= delta
	if _sack_t <= 0.0:
		_sack_t = sack_interval
		if _sacks < max_sacks:
			_plant_sack()

	_web_t -= delta
	if _web_t <= 0.0:
		_web_t = web_interval
		_spit_web()

func _plant_sack() -> void:
	var s := SACK.instantiate()
	s.max_alive = 2
	get_parent().add_child(s)
	s.global_position = global_position + Vector2(randf_range(-70, 70), randf_range(-50, 50))
	_sacks += 1
	# free the slot when this sac is destroyed so she can plant a fresh one (but only one)
	s.died.connect(func() -> void: _sacks = max(_sacks - 1, 0))

func _spit_web() -> void:
	var w := WEB.instantiate()
	get_parent().add_child(w)
	w.global_position = global_position
	w.dir = (_player.global_position - global_position).normalized()
