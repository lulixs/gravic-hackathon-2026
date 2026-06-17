extends CharacterBody2D
class_name EnemyBase

signal died

@export var max_hp := 30.0
@export var contact_damage := 10.0
@export var xp_value := 25
@export var health_drop_chance := 0.2
@export var i_frame_duration := 0.3
@export var health_bar_width := 30.0
@export var health_bar_offset_y := -22.0
@export var enemy_name := ""

var hp := max_hp
var i_frames := false
var _i_timer := 0.0
var _blink_accum := 0.0
var _hitbox: Area2D
var _sprite: Node  # Node2D or ColorRect — anything with modulate
var _hb_bg: ColorRect
var _hb_fill: ColorRect
var _name_label: Label

const XP_ORB := preload("res://scenes/xp_orb.tscn")
const HEALTH_ORB := preload("res://scenes/health_orb.tscn")
const DAMAGE_NUMBER := preload("res://scenes/damage_number.tscn")

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
	_create_health_bar()

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
	_apply_contact_damage()

func take_damage(amount: float) -> void:
	if i_frames:
		return
	hp -= amount
	_spawn_damage_number(amount)
	_update_health_bar()
	if hp <= 0.0:
		die()
		return
	i_frames = true
	_i_timer = i_frame_duration
	_blink_accum = 0.0

# ---------------- health bar ----------------

func _create_health_bar() -> void:
	var pos := Vector2(-health_bar_width * 0.5, health_bar_offset_y)
	_hb_bg = ColorRect.new()
	_hb_bg.color = Color(0, 0, 0, 0.6)
	_hb_bg.size = Vector2(health_bar_width, 4.0)
	_hb_bg.position = pos
	_hb_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hb_bg.z_index = 50
	add_child(_hb_bg)
	_hb_fill = ColorRect.new()
	_hb_fill.color = Color(0.3, 0.9, 0.3)
	_hb_fill.size = Vector2(health_bar_width, 4.0)
	_hb_fill.position = pos
	_hb_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hb_fill.z_index = 51
	add_child(_hb_fill)
	if enemy_name != "":
		_name_label = Label.new()
		_name_label.text = enemy_name
		_name_label.size = Vector2(120, 12)
		_name_label.position = Vector2(-60.0, health_bar_offset_y - 14.0)
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_label.add_theme_font_size_override("font_size", 9)
		_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_name_label.add_theme_constant_override("outline_size", 4)
		_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_name_label.z_index = 51
		add_child(_name_label)

func _update_health_bar() -> void:
	if _hb_fill == null:
		return
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	_hb_fill.size.x = health_bar_width * ratio
	_hb_fill.color = Color(0.9, 0.25, 0.25).lerp(Color(0.3, 0.9, 0.3), ratio)

func set_health_bar_offset(y: float) -> void:
	health_bar_offset_y = y
	if _hb_bg:
		_hb_bg.position.y = y
	if _hb_fill:
		_hb_fill.position.y = y
	if _name_label:
		_name_label.position.y = y - 14.0

# ---------------- damage popup ----------------

func _spawn_damage_number(amount: float) -> void:
	if DAMAGE_NUMBER == null:
		return
	var dn := DAMAGE_NUMBER.instantiate()
	dn.amount = amount
	var host := get_parent()
	if host == null:
		return
	host.add_child(dn)
	dn.global_position = global_position + Vector2(0, health_bar_offset_y - 6.0)

func die() -> void:
	_drop_loot()
	died.emit()
	queue_free()

# split out so subclasses (e.g. a boss with a death animation) can drop loot,
# emit died, then free themselves only after the animation finishes.
func _drop_loot() -> void:
	if XP_ORB:
		var orb = XP_ORB.instantiate()
		orb.global_position = global_position
		get_parent().add_child(orb)
	if randf() < health_drop_chance and HEALTH_ORB:
		var heart = HEALTH_ORB.instantiate()
		heart.global_position = global_position
		get_parent().add_child(heart)

# Continuous contact damage: while the player overlaps our hitbox we keep calling
# take_damage. The player's own i-frames rate-limit it, so brushing a spider chips
# HP every i-frame window instead of only on the single frame the player enters.
func _apply_contact_damage() -> void:
	if contact_damage <= 0.0 or _hitbox == null or not _hitbox.monitoring:
		return
	for body in _hitbox.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(contact_damage, global_position)  # pass our pos for knockback
			return

func set_hitbox_enabled(enabled: bool) -> void:
	if _hitbox:
		_hitbox.monitoring = enabled

# ---------------- room awareness ----------------
# Enemies only act when the player shares their room. Rooms come from the player's
# room camera (room_camera.gd `rooms`), so this matches the on-screen room exactly.

func _player_node() -> Node2D:
	return get_tree().get_first_node_in_group("player")

func _level_rooms() -> Array:
	var p := _player_node()
	if p and p.has_node("Camera2D"):
		var cam := p.get_node("Camera2D")
		if "rooms" in cam:
			return cam.rooms
	return []

func _room_index(rooms: Array, pos: Vector2) -> int:
	for i in rooms.size():
		if (rooms[i]["rect"] as Rect2).has_point(pos):
			return i
	return -1

func player_in_same_room() -> bool:
	var p := _player_node()
	if p == null:
		return false
	var rooms := _level_rooms()
	if rooms.is_empty():
		return true  # no room info (e.g. single-room level) -> always active
	var mine := _room_index(rooms, global_position)
	if mine == -1:
		return true  # we're outside every defined room -> stay active
	return mine == _room_index(rooms, p.global_position)
