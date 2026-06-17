extends EnemyBase
## Bullfrog (Level 2 boss). Sits idle, then every 7-10s leaps at the player with a
## jump attack. The leap lasts exactly as long as the JumpAttack animation (tied via
## its animation_finished signal), so movement and art stay in sync. The level
## reveals the Broadsword when it dies (listens for EnemyBase's `died`).

@export var jump_speed := 200.0          # leap velocity during a jump attack
@export var jump_cooldown_min := 7.0     # idle wait before the next jump
@export var jump_cooldown_max := 10.0
@export var engage_radius := 700.0       # only wakes once the player is in the den
@export var arena := Rect2(0, 1100, 2368, 372)  # region the frog wraps within

var _player: Node2D
var _attack_cd := 0.0
var _jumping := false
var _dead := false
var _jump_dir := Vector2.ZERO

@onready var _idle := get_node_or_null("Sprite/Idle") as AnimatedSprite2D
@onready var _jump := get_node_or_null("Sprite/JumpAttack") as AnimatedSprite2D
@onready var _death := get_node_or_null("Sprite/Death") as AnimatedSprite2D

func _ready() -> void:
	if enemy_name == "":
		enemy_name = "Bullfrog"
	max_hp = 260.0
	contact_damage = 12.0
	xp_value = 250
	health_drop_chance = 1.0
	health_bar_width = 72.0
	health_bar_offset_y = -130.0
	super._ready()
	add_to_group("boss")
	_attack_cd = randf_range(jump_cooldown_min, jump_cooldown_max)
	if _jump:
		# the leap ends when the (non-looping) jump animation finishes
		_jump.animation_finished.connect(_on_jump_finished)
	_show_idle()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	if not _player:
		return

	# mid jump-attack: carry the leap until the animation reports it's done
	if _jumping:
		velocity = _jump_dir * jump_speed
		move_and_slide()
		_wrap()
		return

	# idle: only wakes when the player is in the den and close enough
	if not player_in_same_room() or global_position.distance_to(_player.global_position) > engage_radius:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		move_and_slide()
		return

	# sit and tick down to the next jump attack
	velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
	_attack_cd -= delta
	if _attack_cd <= 0.0:
		_start_jump()
	move_and_slide()
	_wrap()

func _start_jump() -> void:
	_jumping = true
	_jump_dir = (_player.global_position - global_position).normalized()
	if _jump_dir == Vector2.ZERO:
		_jump_dir = Vector2.DOWN
	_show_jump()
	if _jump:
		_jump.frame = 0
		_jump.play("default")
	else:
		_on_jump_finished()  # no animation available -> end the leap immediately

func _on_jump_finished() -> void:
	if not _jumping:
		return
	_jumping = false
	_attack_cd = randf_range(jump_cooldown_min, jump_cooldown_max)
	_show_idle()

# On death: drop loot, tell the level (reveals the Broadsword), then play the death
# animation through before freeing. Overrides EnemyBase.die() to delay queue_free.
func die() -> void:
	if _dead:
		return
	_dead = true
	_jumping = false
	_drop_loot()
	died.emit()
	set_physics_process(false)  # stop moving + dealing contact damage
	set_hitbox_enabled(false)
	if _sprite:
		_sprite.modulate = Color.WHITE  # clear any hit-flash tint
	_show_death()
	if _death:
		_death.frame = 0
		_death.play("default")
		await _death.animation_finished
	queue_free()

func _show_death() -> void:
	if _idle:
		_idle.visible = false
	if _jump:
		_jump.visible = false
	if _death:
		_death.visible = true

func _show_idle() -> void:
	if _idle:
		_idle.visible = true
	if _jump:
		_jump.visible = false

func _show_jump() -> void:
	if _idle:
		_idle.visible = false
	if _jump:
		_jump.visible = true

func _wrap() -> void:
	var p := global_position
	var minx := arena.position.x
	var maxx := arena.position.x + arena.size.x
	var miny := arena.position.y
	var maxy := arena.position.y + arena.size.y
	if p.x < minx:
		p.x = maxx
	elif p.x > maxx:
		p.x = minx
	if p.y < miny:
		p.y = maxy
	elif p.y > maxy:
		p.y = miny
	global_position = p
