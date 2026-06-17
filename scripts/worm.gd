extends EnemyBase
## Mudworm — slow, high-HP straight-line patroller that reverses when it hits a
## wall. Damage to the player is handled by EnemyBase (continuous contact + knockback).

@export var patrol_speed := 35.0

var _dir := Vector2.RIGHT

func _ready() -> void:
	if enemy_name == "":
		enemy_name = "Mudworm"
	max_hp = 90.0
	contact_damage = 6.0
	xp_value = 35
	super._ready()
	_dir = Vector2.RIGHT if randf() < 0.5 else Vector2.LEFT

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if knockback_active(delta):
		return
	velocity = velocity.move_toward(_dir * patrol_speed, 200.0 * delta)
	move_and_slide()
	if is_on_wall():
		_dir = -_dir
