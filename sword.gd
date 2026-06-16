extends Sprite2D

signal charging_changed(is_charging: bool)

@export var OUTER_RADIUS = 30.0  # max distance the sword can float from the player
@export var INNER_RADIUS = 10.0  # min distance, so the sword never sits on top of the player
@export var BLOCK_RADIUS = 6.0   # distance the sword pulls in to while blocking
@export var FOLLOW_SPEED = 12.0  # how snappily the sword chases the mouse
@export var BLOCK_SPEED = 10.0   # how quickly the sword eases in/out of the block stance
@export var BASE_DAMAGE := 10.0
@export var BASE_STAMINA_COST := 15.0
@export var HITBOX_RADIUS := 14.0
@export var ATTACK_DURATION := 0.15
@export var COOLDOWN_DURATION := 0.3
@export var MAX_CHARGE_MULT := 3.0
@export var FULL_CHARGE_TIME := 1.0  # seconds to reach max charge

enum SwordState {IDLE, CHARGING, ATTACKING, COOLDOWN}

var block := 0.0  # 0 = normal, 1 = fully in the sideways block stance
var sword_state: SwordState = SwordState.IDLE
var charge_time := 0.0
var state_timer := 0.0
var pending_damage := 0.0
var hitbox: Area2D
var hitbox_shape: CollisionShape2D
var _hit_bodies: Array = []  # bodies already hit by current swing

func _ready() -> void:
	_create_hitbox()

func _create_hitbox() -> void:
	hitbox = Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 4
	hitbox.collision_mask = 2
	hitbox.monitoring = false
	hitbox.monitorable = false
	hitbox_shape = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = HITBOX_RADIUS
	hitbox_shape.shape = shape
	hitbox.add_child(hitbox_shape)
	add_child(hitbox)
	hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta: float) -> void:
	# offset from the player (our parent) to the mouse, in the player's local space.
	# the player isn't rotated/scaled, so this global offset == our local position.
	var player := get_parent() as Node2D
	var to_mouse: Vector2 = get_global_mouse_position() - player.global_position

	# ease the block amount toward held/released (frame-rate independent).
	var blocking := Input.is_action_pressed("block") if InputMap.has_action("block") else Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var block_target := 1.0 if blocking else 0.0
	block = lerpf(block, block_target, 1.0 - exp(-BLOCK_SPEED * delta))

	# clamp the target into a ring (between INNER_RADIUS and OUTER_RADIUS) around the
	# player, while keeping the direction toward the mouse. while blocking, pull in
	# toward BLOCK_RADIUS.
	var dir := to_mouse.normalized() if to_mouse != Vector2.ZERO else Vector2.UP
	var dist := clampf(to_mouse.length(), INNER_RADIUS, OUTER_RADIUS)
	dist = lerpf(dist, BLOCK_RADIUS, block)
	var target := dir * dist
	# ease toward the target (frame-rate independent smoothing).
	position = position.lerp(target, 1.0 - exp(-FOLLOW_SPEED * delta))
	# hard wall: the eased position can lerp straight across the center when the mouse
	# flips sides, so push it back out to the minimum radius. it never crosses over the
	# player; instead it slides around the rim.
	var min_dist := lerpf(INNER_RADIUS, BLOCK_RADIUS, block)
	if position.length() < min_dist:
		position = (position.normalized() if position != Vector2.ZERO else dir) * min_dist
	# point the blade (the sprite's "up") away from the player, rotating an extra
	# 90° toward sideways as the block stance eases in.
	rotation = position.angle() + PI / 2 + block * PI / 2

	# hitbox is a child of the sword sprite, so it already moves with the blade —
	# keeping it centered on the sprite's pivot covers the strike arc fine.
	_process_attack(delta, dir)

func _process_attack(delta: float, dir: Vector2) -> void:
	match sword_state:
		SwordState.IDLE:
			if Input.is_action_just_pressed("attack") and block < 0.5:
				if GameManager.drain_stamina(BASE_STAMINA_COST):
					sword_state = SwordState.CHARGING
					charge_time = 0.0
					charging_changed.emit(true)
		SwordState.CHARGING:
			charge_time += delta
			if Input.is_action_just_released("attack"):
				_launch_attack(dir)
		SwordState.ATTACKING:
			state_timer -= delta
			if state_timer <= 0.0:
				hitbox.monitoring = false
				sword_state = SwordState.COOLDOWN
				state_timer = COOLDOWN_DURATION
		SwordState.COOLDOWN:
			state_timer -= delta
			if state_timer <= 0.0:
				sword_state = SwordState.IDLE
				charge_time = 0.0
				charging_changed.emit(false)

func _launch_attack(_dir: Vector2) -> void:
	var charge_ratio := clampf(charge_time / FULL_CHARGE_TIME, 0.0, 1.0)
	var mult := 1.0 + (MAX_CHARGE_MULT - 1.0) * charge_ratio
	pending_damage = _weapon_damage() * mult
	_hit_bodies.clear()
	hitbox.monitoring = true
	sword_state = SwordState.ATTACKING
	state_timer = ATTACK_DURATION
	# emit non-charging once the swing fires, even before the cooldown ends — player
	# can move at full speed during the swing itself.
	charging_changed.emit(false)

func _weapon_damage() -> float:
	var path := "res://data/" + GameManager.current_weapon + ".tres"
	if ResourceLoader.exists(path):
		var res := ResourceLoader.load(path)
		if res and "damage_multiplier" in res:
			return BASE_DAMAGE * float(res.damage_multiplier)
	return BASE_DAMAGE

func _on_hitbox_body_entered(body: Node) -> void:
	if body in _hit_bodies:
		return
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		_hit_bodies.append(body)
		body.take_damage(pending_damage)
