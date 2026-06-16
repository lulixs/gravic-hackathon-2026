extends CharacterBody2D
class_name EnemyBase

signal died

@export var max_hp := 30.0
@export var contact_damage := 10.0
@export var xp_value := 25
@export var health_drop_chance := 0.2
@export var i_frame_duration := 0.3

var hp := max_hp
var i_frames := false
var _i_timer := 0.0
var _blink_accum := 0.0
var _hitbox: Area2D
var _sprite: Node  # Node2D or ColorRect — anything with modulate

const XP_ORB := preload("res://scenes/xp_orb.tscn")
const HEALTH_ORB := preload("res://scenes/health_orb.tscn")

func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	collision_layer = 2
	collision_mask = 1
	_sprite = get_node_or_null("Sprite")
	_hitbox = get_node_or_null("Hitbox") as Area2D
	if _hitbox:
		_hitbox.collision_layer = 0
		_hitbox.collision_mask = 1
		_hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta: float) -> void:
	if i_frames:
		_i_timer -= delta
		_blink_accum += delta
		if _sprite and _blink_accum >= 0.06:
			_blink_accum = 0.0
			_sprite.modulate = Color(1, 1, 1, 1) if _sprite.modulate != Color(1, 0.4, 0.4, 1) else Color(1, 0.4, 0.4, 1)
		if _i_timer <= 0.0:
			i_frames = false
			if _sprite:
				_sprite.modulate = Color(1, 1, 1, 1)

func take_damage(amount: float) -> void:
	if i_frames:
		return
	hp -= amount
	if hp <= 0.0:
		die()
		return
	i_frames = true
	_i_timer = i_frame_duration
	_blink_accum = 0.0

func die() -> void:
	if XP_ORB:
		var orb = XP_ORB.instantiate()
		orb.global_position = global_position
		get_parent().add_child(orb)
	if randf() < health_drop_chance and HEALTH_ORB:
		var heart = HEALTH_ORB.instantiate()
		heart.global_position = global_position
		get_parent().add_child(heart)
	died.emit()
	queue_free()

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(contact_damage)

func set_hitbox_enabled(enabled: bool) -> void:
	if _hitbox:
		_hitbox.monitoring = enabled
