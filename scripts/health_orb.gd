extends Area2D

@export var heal_amount := 20.0
@export var magnet_radius := 50.0
@export var speed := 220.0

var _player: Node2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	if _player:
		var to_p: Vector2 = _player.global_position - global_position
		if to_p.length() <= magnet_radius:
			global_position += to_p.normalized() * speed * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		GameManager.heal(heal_amount)
		queue_free()
