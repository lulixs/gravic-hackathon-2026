extends EnemyBase
## Garden Snake — hunts the player through its room, slithering after them and
## dealing contact damage (handled by EnemyBase). 50% faster than before. The
## slither animation mirrors to face whichever way the snake is moving.

@export var move_speed := 105.0   # 50% faster (70 -> 105)

var _player: Node2D
@onready var _anim := get_node_or_null("Sprite") as AnimatedSprite2D

func _ready() -> void:
	if enemy_name == "":
		enemy_name = "Snake"
	max_hp = 90.0
	contact_damage = 6.0
	xp_value = 35
	super._ready()
	if _anim:
		_anim.play("default")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if knockback_active(delta):
		return
	if not _player:
		_player = get_tree().get_first_node_in_group("player")

	# attack: chase the player anywhere in this snake's room
	var target := Vector2.ZERO
	if _player and player_in_same_room():
		target = chase_velocity_to(_player.global_position, move_speed)

	velocity = velocity.move_toward(target, 500.0 * delta)
	move_and_slide()
	_face(velocity)

func _face(v: Vector2) -> void:
	if _anim and absf(v.x) > 1.0:
		_anim.flip_h = v.x > 0.0  # art faces right by default, so flip when moving right
