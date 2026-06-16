extends CharacterBody2D

enum {IDLE, WALK, DODGE, HURT, DEAD}

const MAX_SPEED = 350.0
const ACCELERATION = 2000.0
const FRICTION = 2100.0

const DODGE_SPEED := 600.0
const DODGE_DURATION := 0.25
const DODGE_STAMINA := 25.0
const HURT_DURATION := 0.5
const STAMINA_REGEN := 20.0  # per second
const BLINK_INTERVAL := 0.06

var state = IDLE
var dir := Vector2.DOWN
var last_dir := Vector2.DOWN

# status flags
var i_frames := false
var cobwebbed := false
var charging := false

# state timers
var state_timer := 0.0
var blink_accum := 0.0
var dodge_dir := Vector2.ZERO

@onready var animationTree = $AnimationTree
@onready var animation = animationTree.get("parameters/playback")
@onready var frames := $frames as Sprite2D
@onready var sword := $Sword

func _ready() -> void:
	add_to_group("player")
	GameManager.player_died.connect(_on_player_died)
	if sword and sword.has_signal("charging_changed"):
		sword.charging_changed.connect(_on_sword_charging_changed)

func _physics_process(delta: float) -> void:
	# read input
	dir = Input.get_vector("left", "right", "up", "down").normalized()
	if dir != Vector2.ZERO:
		last_dir = dir

	# stamina regen (always tick unless dead)
	if state != DEAD:
		GameManager.restore_stamina(STAMINA_REGEN * delta)

	# global dodge trigger (only valid from IDLE/WALK)
	if (state == IDLE or state == WALK) and Input.is_action_just_pressed("dodge"):
		_try_dodge()

	match state:
		IDLE:
			idle(delta)
			if dir != Vector2.ZERO:
				state = WALK
		WALK:
			walk(delta)
			if dir == Vector2.ZERO:
				state = IDLE
		DODGE:
			_process_dodge(delta)
		HURT:
			_process_hurt(delta)
		DEAD:
			velocity = Vector2.ZERO

	move_and_slide()

func idle(_delta: float) -> void:
	animation.travel("idle")
	velocity = velocity.move_toward(Vector2.ZERO, FRICTION * _delta)

func walk(delta: float) -> void:
	animation.travel("walk")
	if dir.x != 0:
		updateDir()
	var mult := 1.0
	if cobwebbed:
		mult = 0.1
	elif charging:
		mult = 0.5
	velocity = velocity.move_toward(dir * MAX_SPEED * mult, ACCELERATION * delta)

func updateDir() -> void:
	animationTree.set("parameters/idle/blend_position", dir.x)
	animationTree.set("parameters/walk/blend_position", dir.x)

# ---------------- DODGE ----------------

func _try_dodge() -> void:
	if i_frames:
		return
	if not GameManager.drain_stamina(DODGE_STAMINA):
		return
	dodge_dir = dir if dir != Vector2.ZERO else last_dir
	if dodge_dir == Vector2.ZERO:
		dodge_dir = Vector2.DOWN
	i_frames = true
	state = DODGE
	state_timer = DODGE_DURATION
	velocity = dodge_dir * DODGE_SPEED
	frames.modulate.a = 0.5

func _process_dodge(delta: float) -> void:
	state_timer -= delta
	# decay velocity slightly during dodge so we don't slide forever after move_and_slide
	velocity = velocity.move_toward(dodge_dir * DODGE_SPEED * 0.7, ACCELERATION * delta)
	if state_timer <= 0.0:
		i_frames = false
		frames.modulate.a = 1.0
		state = IDLE

# ---------------- HURT ----------------

func take_damage(amount: float) -> void:
	if i_frames or state == DEAD:
		return
	GameManager.take_damage(amount)
	if GameManager.hp <= 0.0:
		_enter_dead()
		return
	state = HURT
	i_frames = true
	state_timer = HURT_DURATION
	blink_accum = 0.0

func _process_hurt(delta: float) -> void:
	state_timer -= delta
	blink_accum += delta
	if blink_accum >= BLINK_INTERVAL:
		blink_accum = 0.0
		frames.modulate = Color.WHITE if frames.modulate == Color(1, 0.4, 0.4, 1) else Color(1, 0.4, 0.4, 1)
	velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	if state_timer <= 0.0:
		i_frames = false
		frames.modulate = Color.WHITE
		state = IDLE

# ---------------- DEAD ----------------

func _enter_dead() -> void:
	state = DEAD
	velocity = Vector2.ZERO
	frames.modulate.a = 0.3

func _on_player_died() -> void:
	if state != DEAD:
		_enter_dead()

# ---------------- sword signal ----------------

func _on_sword_charging_changed(is_charging: bool) -> void:
	charging = is_charging
