extends EnemyBase

# Egg sac. Sits in place, periodically births baby spiders (capped) and lobs
# garbage pellets at the player. Destroying it stops the spawns.

const BABY := preload("res://scenes/baby_spider.tscn")
const PELLET := preload("res://scenes/garbage_pellet.tscn")

@export var spawn_interval := 5.0
@export var pellet_interval := 3.0
@export var max_alive := 5   # cap on LIVING spawned spiders; a slot frees up when one dies
@export var target_height := 48.0   # on-screen height of the sac in pixels

# The sac art ships as itself (sac_0) and its mirror (sac_1). Each sac randomly
# picks one so a clutch of them isn't all facing the same way.
const SAC_FRAMES := ["res://assets/EggSac/sac_0.png", "res://assets/EggSac/sac_1.png"]

var _player: Node2D
var _spawn_t := 0.0
var _pellet_t := 0.0
var _alive := 0

func _ready() -> void:
	if enemy_name == "":
		enemy_name = "Egg Sac"
	max_hp = 50.0
	contact_damage = 6.0
	xp_value = 40
	health_bar_offset_y = -20.0
	knockback_resist = 0.45
	super._ready()
	add_to_group("sack")
	_setup_sprite()
	_spawn_t = spawn_interval
	_pellet_t = pellet_interval

func _setup_sprite() -> void:
	var spr := get_node_or_null("Sprite") as Sprite2D
	if spr == null:
		return
	var path: String = SAC_FRAMES[randi() % SAC_FRAMES.size()]
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var s := target_height / float(maxi(tex.get_height(), 1))
	spr.scale = Vector2(s, s)

	# fit the colliders to the art (a touch tighter than the full drawing)
	var w := tex.get_width() * s * 0.6
	var h := target_height * 0.62
	var body := RectangleShape2D.new()
	body.size = Vector2(w, h)
	($CollisionShape2D as CollisionShape2D).shape = body
	var hit := RectangleShape2D.new()
	hit.size = Vector2(w + 4.0, h + 4.0)
	($Hitbox/HitboxShape as CollisionShape2D).shape = hit
	set_health_bar_offset(-(target_height * 0.5 + 8.0))

func _physics_process(delta: float) -> void:
	super._physics_process(delta)   # i-frame blink + contact damage
	if knockback_active(delta):
		return
	if not _player:
		_player = get_tree().get_first_node_in_group("player")

	# stay dormant until the player is in this sac's room — no cross-room spitting
	if not player_in_same_room():
		return

	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = spawn_interval
		if _alive < max_alive:
			_spawn_baby()

	if _player:
		_pellet_t -= delta
		if _pellet_t <= 0.0:
			_pellet_t = pellet_interval
			_throw_pellet()

func _spawn_baby() -> void:
	var b := BABY.instantiate()
	get_parent().add_child(b)
	b.global_position = global_position + Vector2(randf_range(-24, 24), randf_range(-24, 24))
	_alive += 1
	# free the slot back up when this spider dies, so the sac refills toward max_alive
	if b.has_signal("died"):
		b.died.connect(_on_spawn_died)

func _on_spawn_died() -> void:
	_alive = max(_alive - 1, 0)

func _throw_pellet() -> void:
	var p := PELLET.instantiate()
	get_parent().add_child(p)
	p.global_position = global_position
	p.dir = (_player.global_position - global_position).normalized()
