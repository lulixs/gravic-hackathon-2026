extends EnemyBase
## Thornhopper — settles in place, then pounces at the player in a fast burst when
## they come within range, with a cooldown between leaps. Animated with two poses
## per facing ("left"/"right" anims), switched to match its movement direction.

@export var detect_radius := 240.0
@export var pounce_speed := 380.0
@export var pounce_duration := 0.28
@export var pounce_cooldown := 1.5

var _player: Node2D
var _cooldown := 0.0
var _pounce_t := 0.0
var _pounce_dir := Vector2.ZERO
var _facing := "right"
@onready var _anim := get_node_or_null("Sprite") as AnimatedSprite2D

func _ready() -> void:
	if enemy_name == "":
		enemy_name = "Thornhopper"
	max_hp = 26.0
	contact_damage = 7.0
	xp_value = 30
	super._ready()
	if _anim:
		_anim.play(_facing)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if knockback_active(delta):
		return
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	if _cooldown > 0.0:
		_cooldown -= delta

	# mid-leap: hold the pounce velocity
	if _pounce_t > 0.0:
		_pounce_t -= delta
		velocity = _pounce_dir * pounce_speed
		move_and_slide()
		_face(velocity)
		return

	# grounded: settle, then leap if the player is close and we're off cooldown
	velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
	if _player and player_in_same_room() and _cooldown <= 0.0:
		var to_player: Vector2 = _player.global_position - global_position
		if to_player.length() <= detect_radius:
			_pounce_dir = to_player.normalized()
			_pounce_t = pounce_duration
			_cooldown = pounce_cooldown
			_face(_pounce_dir)
	move_and_slide()

func _face(v: Vector2) -> void:
	if _anim == null or absf(v.x) < 1.0:
		return
	var f := "right" if v.x > 0.0 else "left"
	if f != _facing:
		_facing = f
		_anim.play(f)
