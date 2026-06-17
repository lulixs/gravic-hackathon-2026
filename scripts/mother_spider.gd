extends EnemyBase

# Broodmother boss. Slowly closes on the player, plants egg sacs, and spits webs.
# Plays an idle animation, and a death animation on death (the level reveals the
# Flatsword via `died`, emitted once the death animation finishes). Art: assets/MotherSpider.

const SACK := preload("res://scenes/spider_sack.tscn")
const WEB := preload("res://scenes/web_projectile.tscn")

@export var move_speed := 34.0
@export var sack_interval := 7.0
@export var web_interval := 4.0
@export var max_sacks := 1   # never more than one of her egg sacs alive at a time
@export var engage_radius := 420.0
@export var target_height := 130.0   # on-screen height in px

var _player: Node2D
var _sack_t := 0.0
var _web_t := 0.0
var _sacks := 0
var _anim: AnimatedSprite2D
var _dead := false

func _ready() -> void:
	if enemy_name == "":
		enemy_name = "Broodmother"
	max_hp = 220.0
	contact_damage = 10.0
	xp_value = 200
	health_drop_chance = 1.0
	health_bar_width = 70.0
	health_bar_offset_y = -(target_height * 0.5 + 14.0)
	knockback_resist = 0.82
	chase_standoff = 34.0
	contact_range = 56.0
	super._ready()
	add_to_group("boss")
	_sack_t = sack_interval
	_web_t = web_interval
	_setup_visuals()

func _setup_visuals() -> void:
	_anim = $Sprite as AnimatedSprite2D
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_anim.sprite_frames = _build_frames()
	var s := target_height / 540.0
	_anim.scale = Vector2(s, s)
	_anim.play("idle")
	var w := 720.0 * s
	var body := RectangleShape2D.new()
	body.size = Vector2(w * 0.42, target_height * 0.55)
	($CollisionShape2D as CollisionShape2D).shape = body
	var hit := RectangleShape2D.new()
	hit.size = Vector2(w * 0.48, target_height * 0.62)
	($Hitbox/HitboxShape as CollisionShape2D).shape = hit
	if not _anim.animation_finished.is_connected(_on_anim_finished):
		_anim.animation_finished.connect(_on_anim_finished)

func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	_load_range(sf, "idle", "res://assets/MotherSpider/Idle/mother-spider-2_%04d.png", 0, 11, 9.0, true)
	_load_range(sf, "death", "res://assets/MotherSpider/Death/mother-spider-2_%04d.png", 12, 20, 7.0, false)
	return sf

func _load_range(sf: SpriteFrames, anim_name: String, fmt: String, start: int, end: int, fps: float, loop: bool) -> void:
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, loop)
	for i in range(start, end + 1):
		var path: String = fmt % i
		if ResourceLoader.exists(path):
			sf.add_frame(anim_name, load(path))

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _dead:
		return
	if knockback_active(delta):
		return
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	if not _player:
		return

	# dormant until the player is in her room and close
	if not player_in_same_room() or global_position.distance_to(_player.global_position) > engage_radius:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		move_and_slide()
		return

	velocity = velocity.move_toward(chase_velocity_to(_player.global_position, move_speed), 400.0 * delta)
	move_and_slide()

	_sack_t -= delta
	if _sack_t <= 0.0:
		_sack_t = sack_interval
		if _sacks < max_sacks:
			_plant_sack()

	_web_t -= delta
	if _web_t <= 0.0:
		_web_t = web_interval
		_spit_web()

func _plant_sack() -> void:
	var s := SACK.instantiate()
	s.max_alive = 2
	get_parent().add_child(s)
	s.global_position = global_position + Vector2(randf_range(-70, 70), randf_range(-50, 50))
	_sacks += 1
	s.died.connect(func() -> void: _sacks = max(_sacks - 1, 0))

func _spit_web() -> void:
	var w := WEB.instantiate()
	get_parent().add_child(w)
	w.global_position = global_position
	w.dir = (_player.global_position - global_position).normalized()

func die() -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	set_hitbox_enabled(false)
	contact_damage = 0.0
	velocity = Vector2.ZERO
	if _sprite:
		_sprite.modulate = Color.WHITE
	if _anim:
		_anim.play("death")
	else:
		_finish_death()

func _on_anim_finished() -> void:
	if _dead:
		_finish_death()

func _finish_death() -> void:
	_drop_loot()
	died.emit()
	queue_free()
