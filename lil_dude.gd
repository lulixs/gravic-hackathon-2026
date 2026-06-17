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
const KNOCKBACK_SPEED := 420.0  # shove distance when hit, so enemies can't glue to you
const KNOCKBACK_TIME := 0.16
const RAMP_DEGREES := 22.5  # basement ramp slope

var state = IDLE
var dir := Vector2.DOWN
var last_dir := Vector2.DOWN

# status flags
var i_frames := false
var cobwebbed := false
var charging := false
var on_ramp := false  # set by the level when the player is standing on the ramp

# constant vertical speed applied while walking the ramp. derived from the ramp
# angle at full speed so it reads as ~22.5°, but it is a fixed value: the same
# up/down speed regardless of how fast the player is moving horizontally.
var _ramp_y_speed := MAX_SPEED * tan(deg_to_rad(RAMP_DEGREES))

# state timers
var state_timer := 0.0
var blink_accum := 0.0
var dodge_dir := Vector2.ZERO
var knockback_timer := 0.0

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

	_apply_ramp()
	move_and_slide()

# On the ramp, horizontal travel sells the illusion of a 22.5° slope: moving
# right pushes the player up, moving left pushes them down. The horizontal
# velocity is left untouched; we just *set* a constant vertical speed based on
# which way they're moving (overriding any vertical input so it can't compound).
# Gated on input direction, not velocity, so releasing the keys lets normal
# friction bring the player to a stop instead of sliding down the slope.
func _apply_ramp() -> void:
	if not on_ramp or is_zero_approx(dir.x):
		return
	velocity.y = -signf(dir.x) * _ramp_y_speed

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
	# hold a constant dodge velocity for the whole duration. overriding it each frame
	# (rather than decaying from whatever speed we entered with) guarantees the lunge
	# covers the same distance whether we were standing still or already running.
	velocity = dodge_dir * DODGE_SPEED
	if state_timer <= 0.0:
		i_frames = false
		frames.modulate.a = 1.0
		state = IDLE

# ---------------- HURT ----------------

func take_damage(amount: float, from_pos: Vector2 = Vector2.INF) -> void:
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
	# shove the player away from whatever hit them so an enemy can't stay glued on
	if from_pos != Vector2.INF:
		var kb := global_position - from_pos
		if kb == Vector2.ZERO:
			kb = -last_dir
		velocity = kb.normalized() * KNOCKBACK_SPEED
		knockback_timer = KNOCKBACK_TIME

func _process_hurt(delta: float) -> void:
	state_timer -= delta
	blink_accum += delta
	if blink_accum >= BLINK_INTERVAL:
		blink_accum = 0.0
		frames.modulate = Color.WHITE if frames.modulate == Color(1, 0.4, 0.4, 1) else Color(1, 0.4, 0.4, 1)
	# keep control while hurt: freezing here let enemies (esp. egg sacs) stun-lock the
	# player in place and grind them to death. i-frames still protect during the window.
	if knockback_timer > 0.0:
		knockback_timer -= delta  # ride the shove out for a moment before regaining control
	elif dir != Vector2.ZERO:
		walk(delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	if state_timer <= 0.0:
		i_frames = false
		frames.modulate = Color.WHITE
		state = IDLE

# ---------------- DEAD ----------------

func _enter_dead() -> void:
	if state == DEAD:
		return
	state = DEAD
	velocity = Vector2.ZERO
	# brief death beat (player stays visible, tinted red) then restart the level
	# from scratch with all stats reset, as if you just walked in.
	frames.modulate = Color(0.7, 0.15, 0.15, 1.0)
	await get_tree().create_timer(1.0).timeout
	get_tree().paused = false  # in case death overlapped a paused menu/dialogue
	GameManager.reset()
	get_tree().reload_current_scene()

func _on_player_died() -> void:
	if state != DEAD:
		_enter_dead()

# ---------------- sword signal ----------------

func _on_sword_charging_changed(is_charging: bool) -> void:
	charging = is_charging
