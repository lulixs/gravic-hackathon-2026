extends EnemyBase

# Pig Guard — the castle mob. Wanders its post until the player enters its room,
# then hunts them down. Tougher than a basement spider but no special tricks.

@export var chase_speed := 95.0
@export var wander_speed := 32.0

var _player: Node2D
var _wander_dir := Vector2.ZERO
var _wander_t := 0.0

func _ready() -> void:
	if enemy_name == "":
		enemy_name = "Pig Guard"
	max_hp = 45.0
	contact_damage = 8.0
	xp_value = 35
	super._ready()
	add_to_group("guard")
	_pick_wander()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)   # i-frame blink + contact damage
	if knockback_active(delta):
		return
	if not _player:
		_player = get_tree().get_first_node_in_group("player")

	var target := Vector2.ZERO
	if _player and player_in_same_room():
		target = chase_velocity_to(_player.global_position, chase_speed)
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_pick_wander()
		target = _wander_dir * wander_speed

	velocity = velocity.move_toward(target, 700.0 * delta)
	move_and_slide()

func _pick_wander() -> void:
	_wander_t = 2.0
	var a := randf() * TAU
	_wander_dir = Vector2(cos(a), sin(a))
