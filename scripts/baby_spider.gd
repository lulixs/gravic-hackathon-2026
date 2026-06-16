extends EnemyBase

@export var docile := false
@export var move_speed := 50.0
@export var chase_radius := 150.0
@export var wander_change_interval := 2.0

var _wander_dir := Vector2.ZERO
var _wander_timer := 0.0
var _player: Node2D

func _ready() -> void:
	super._ready()
	_pick_wander_dir()
	if docile:
		set_hitbox_enabled(false)
		contact_damage = 0.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _player:
		_player = get_tree().get_first_node_in_group("player")

	var target_vel := Vector2.ZERO
	if docile or not _player:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_pick_wander_dir()
		target_vel = _wander_dir * move_speed * 0.6
	else:
		var to_player: Vector2 = _player.global_position - global_position
		if to_player.length() <= chase_radius:
			target_vel = to_player.normalized() * move_speed
		else:
			_wander_timer -= delta
			if _wander_timer <= 0.0:
				_pick_wander_dir()
			target_vel = _wander_dir * move_speed * 0.6

	velocity = velocity.move_toward(target_vel, 600.0 * delta)
	move_and_slide()

func _pick_wander_dir() -> void:
	_wander_timer = wander_change_interval
	var angle := randf() * TAU
	_wander_dir = Vector2(cos(angle), sin(angle))
