extends Sprite2D

signal charging_changed(is_charging: bool)

@export var OUTER_RADIUS = 34.0  # max distance the sword can float from the player
@export var INNER_RADIUS = 10.0  # min distance, so the sword never sits on top of the player
@export var BLOCK_RADIUS = 6.0   # distance the sword pulls in to while blocking
@export var FOLLOW_SPEED = 12.0  # how snappily the sword chases the mouse
@export var BLOCK_SPEED = 10.0   # how quickly the sword eases in/out of the block stance
@export var BASE_DAMAGE := 10.0
@export var BASE_STAMINA_COST := 15.0
@export var HITBOX_RADIUS := 18.0
@export var ATTACK_DURATION := 0.15
@export var COOLDOWN_DURATION := 0.3
@export var MAX_CHARGE_MULT := 3.0
@export var FULL_CHARGE_TIME := 1.0
@export var SWING_ARC := PI * 0.9      # how far the blade sweeps through during a swing
@export var WINDUP_SHIFT := -0.35      # negative rotation while charging — sword cocks back

enum SwordState {IDLE, CHARGING, ATTACKING, COOLDOWN}

var block := 0.0
var sword_state: SwordState = SwordState.IDLE
var charge_time := 0.0
var state_timer := 0.0
var pending_damage := 0.0
var swing_dir_sign := 1.0    # +1 (mouse-right of player) or -1 — which way the slash arcs
var swing_start_angle := 0.0 # base angle at moment of release
var hitbox: Area2D
var hitbox_shape: CollisionShape2D
var _hit_bodies: Array = []
var _flash_accum := 0.0

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
	var player := get_parent() as Node2D
	var to_mouse: Vector2 = get_global_mouse_position() - player.global_position

	# block easing (right-click stance)
	var blocking := Input.is_action_pressed("block") if InputMap.has_action("block") else Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var block_target := 1.0 if blocking else 0.0
	block = lerpf(block, block_target, 1.0 - exp(-BLOCK_SPEED * delta))

	var dir := to_mouse.normalized() if to_mouse != Vector2.ZERO else Vector2.UP
	var dist := clampf(to_mouse.length(), INNER_RADIUS, OUTER_RADIUS)
	dist = lerpf(dist, BLOCK_RADIUS, block)
	var target := dir * dist
	position = position.lerp(target, 1.0 - exp(-FOLLOW_SPEED * delta))
	var min_dist := lerpf(INNER_RADIUS, BLOCK_RADIUS, block)
	if position.length() < min_dist:
		position = (position.normalized() if position != Vector2.ZERO else dir) * min_dist

	# base rotation (sword points away from player)
	var base_rotation := position.angle() + PI / 2 + block * PI / 2

	# overlay an angular offset for charge windup + swing
	var swing_offset := 0.0
	match sword_state:
		SwordState.CHARGING:
			var t := clampf(charge_time / FULL_CHARGE_TIME, 0.0, 1.0)
			swing_offset = WINDUP_SHIFT * t   # cock the blade backward as charge builds
		SwordState.ATTACKING:
			var swing_t := 1.0 - clampf(state_timer / ATTACK_DURATION, 0.0, 1.0)
			# accelerate through the arc (ease-out)
			var eased := 1.0 - pow(1.0 - swing_t, 2.0)
			swing_offset = swing_dir_sign * SWING_ARC * (eased - 0.5)
		SwordState.COOLDOWN:
			# decay any residual swing/windup back toward neutral
			pass

	rotation = base_rotation + swing_offset

	_update_charge_visual(delta)
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
			# fire the swing as soon as the button is no longer held. checking "not pressed"
			# (instead of just_released) catches fast clicks where press+release land on the
			# same frame — those used to get stuck in the windup pose and never jab.
			if not Input.is_action_pressed("attack"):
				_launch_attack(dir)
		SwordState.ATTACKING:
			# poll overlaps every frame of the swing. body_entered only fires for bodies
			# that *cross into* the hitbox after monitoring turns on — enemies already
			# inside when the swing starts would otherwise be missed entirely.
			_apply_overlap_hits()
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
				modulate = Color.WHITE
				scale = Vector2.ONE

func _launch_attack(dir: Vector2) -> void:
	var charge_ratio := clampf(charge_time / FULL_CHARGE_TIME, 0.0, 1.0)
	var mult := 1.0 + (MAX_CHARGE_MULT - 1.0) * charge_ratio
	pending_damage = _weapon_damage() * mult
	_hit_bodies.clear()
	hitbox.monitoring = true
	sword_state = SwordState.ATTACKING
	state_timer = ATTACK_DURATION
	# pick which way the slash arcs based on horizontal mouse side
	swing_dir_sign = 1.0 if dir.x >= 0.0 else -1.0
	swing_start_angle = position.angle()
	charging_changed.emit(false)

func _update_charge_visual(delta: float) -> void:
	_flash_accum += delta
	match sword_state:
		SwordState.CHARGING:
			var t := clampf(charge_time / FULL_CHARGE_TIME, 0.0, 1.0)
			if t >= 1.0:
				# pulse bright red-orange at max charge so it's obvious
				var pulse := 0.5 + 0.5 * sin(_flash_accum * 18.0)
				modulate = Color(1.0, 0.4 + 0.4 * pulse, 0.2, 1.0)
				scale = Vector2.ONE * (1.0 + 0.18 * pulse)
			else:
				# linear ramp toward red as charge builds
				modulate = Color.WHITE.lerp(Color(1.0, 0.7, 0.2, 1.0), t)
				scale = Vector2.ONE.lerp(Vector2.ONE * 1.1, t)
		SwordState.ATTACKING:
			modulate = Color(1.0, 0.95, 0.85, 1.0)
		_:
			modulate = modulate.lerp(Color.WHITE, 1.0 - exp(-8.0 * delta))
			scale = scale.lerp(Vector2.ONE, 1.0 - exp(-12.0 * delta))

func _weapon_damage() -> float:
	var dmg := BASE_DAMAGE
	var path := "res://data/" + GameManager.current_weapon + ".tres"
	if ResourceLoader.exists(path):
		var res := ResourceLoader.load(path)
		if res and "damage_multiplier" in res:
			dmg = BASE_DAMAGE * float(res.damage_multiplier)
	return dmg * GameManager.damage_mult

func _on_hitbox_body_entered(body: Node) -> void:
	_try_hit(body)

func _apply_overlap_hits() -> void:
	for body in hitbox.get_overlapping_bodies():
		_try_hit(body)

func _try_hit(body: Node) -> void:
	if body in _hit_bodies:
		return
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		_hit_bodies.append(body)
		body.take_damage(pending_damage)
