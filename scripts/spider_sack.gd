extends EnemyBase

# Egg sac. Sits in place, periodically births baby spiders (capped) and lobs
# garbage pellets at the player. Destroying it stops the spawns.

const BABY := preload("res://scenes/baby_spider.tscn")
const PELLET := preload("res://scenes/garbage_pellet.tscn")

@export var spawn_interval := 5.0
@export var pellet_interval := 3.0
@export var max_alive := 5   # cap on LIVING spawned spiders; a slot frees up when one dies

var _player: Node2D
var _spawn_t := 0.0
var _pellet_t := 0.0
var _alive := 0

func _ready() -> void:
	if enemy_name == "":
		enemy_name = "Egg Sac"
	max_hp = 50.0
	contact_damage = 6.0
	xp_value = 40
	health_bar_offset_y = -20.0
	knockback_resist = 0.45
	super._ready()
	add_to_group("sack")
	_spawn_t = spawn_interval
	_pellet_t = pellet_interval

func _physics_process(delta: float) -> void:
	super._physics_process(delta)   # i-frame blink + contact damage
	if knockback_active(delta):
		return
	if not _player:
		_player = get_tree().get_first_node_in_group("player")

	# stay dormant until the player is in this sac's room — no cross-room spitting
	if not player_in_same_room():
		return

	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = spawn_interval
		if _alive < max_alive:
			_spawn_baby()

	if _player:
		_pellet_t -= delta
		if _pellet_t <= 0.0:
			_pellet_t = pellet_interval
			_throw_pellet()

func _spawn_baby() -> void:
	var b := BABY.instantiate()
	get_parent().add_child(b)
	b.global_position = global_position + Vector2(randf_range(-24, 24), randf_range(-24, 24))
	_alive += 1
	# free the slot back up when this spider dies, so the sac refills toward max_alive
	if b.has_signal("died"):
		b.died.connect(_on_spawn_died)

func _on_spawn_died() -> void:
	_alive = max(_alive - 1, 0)

func _throw_pellet() -> void:
	var p := PELLET.instantiate()
	get_parent().add_child(p)
	p.global_position = global_position
	p.dir = (_player.global_position - global_position).normalized()
