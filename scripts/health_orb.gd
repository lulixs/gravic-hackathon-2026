extends Area2D

# Health pickup. Distance-based magnet + collection (see xp_orb.gd for why we don't
# rely on body_entered — the player's collision capsule is offset to its feet).

@export var heal_amount := 20.0
@export var magnet_radius := 75.0
@export var pickup_radius := 22.0
@export var speed := 270.0

var _player: Node2D
var _collected := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _collected:
		return
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	if not _player:
		return
	var to_p: Vector2 = _player.global_position - global_position
	var d := to_p.length()
	if d <= pickup_radius:
		_collect()
		return
	if d <= magnet_radius:
		global_position += to_p.normalized() * speed * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_collect()

func _collect() -> void:
	if _collected:
		return
	_collected = true
	GameManager.heal(heal_amount)
	queue_free()
