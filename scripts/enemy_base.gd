extends CharacterBody2D
class_name EnemyBase

signal died
signal half_health   # fires once when hp first drops to/below 50% (mid-fight dialogue cue)

@export var max_hp := 30.0
@export var contact_damage := 10.0
@export var xp_value := 25
@export var health_drop_chance := 0.5
@export var i_frame_duration := 0.3
@export var health_bar_width := 30.0
@export var health_bar_offset_y := -22.0
@export var enemy_name := ""
@export var chase_standoff := 22.0   # stop this far from the player so we don't crowd onto them
@export var contact_range := 36.0    # deal contact damage when this close to the player
@export var knockback_resist := 0.0  # 0 = full knockback from sword hits, 1 = immune (bosses)

const KNOCKBACK_TIME := 0.16

var hp := max_hp
var i_frames := false
var _i_timer := 0.0
var _blink_accum := 0.0
var _kb_timer := 0.0
var _player_excepted := false
var _cobweb_count := 0   # how many cobwebs we're currently standing in
var _half_announced := false   # guard so half_health only fires once
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
	# Pass through the player's body so we never grind/stick to them. Walls (and the
	# player passing through us) are unaffected; contact damage is handled separately.
	if not _player_excepted:
		var p := _player_node()
		if p:
			add_collision_exception_with(p)
			_player_excepted = true
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

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if i_frames:
		return
	hp -= amount
	_spawn_damage_number(amount)
	_update_health_bar()
	if hp <= 0.0:
		die()
		return
	if not _half_announced and hp <= max_hp * 0.5:
		_half_announced = true
		half_health.emit()
	i_frames = true
	_i_timer = i_frame_duration
	_blink_accum = 0.0
	if knockback != Vector2.ZERO and knockback_resist < 1.0:
		velocity = knockback * (1.0 - knockback_resist)
		_kb_timer = KNOCKBACK_TIME

# While knocked back, ride out the shove instead of running normal AI movement.
# Movement subclasses call this right after super._physics_process and return if true.
func knockback_active(delta: float) -> bool:
	if _kb_timer <= 0.0:
		return false
	_kb_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	return true

# Chase velocity that homes in on a ring `chase_standoff` away from the player and
# holds there — easing to a stop as it arrives and gently backing off if it ends up
# too close. Keeps enemies at arm's length (still inside contact_range) instead of
# drifting onto / sticking to the player's body.
func chase_velocity_to(player_pos: Vector2, speed: float) -> Vector2:
	var to := player_pos - global_position
	var d := to.length()
	if d <= 0.01:
		return Vector2.ZERO
	var dir := to / d
	var err := d - chase_standoff   # >0 too far (approach), <0 too close (back off)
	return dir * clampf(err * 6.0, -speed * 0.6, speed) * cobweb_factor()

# Cobwebs (cobweb.gd) call enter/exit as enemies walk in and out. While webbed,
# movement is crushed to ~12% — the same massive drag the player feels.
func cobweb_factor() -> float:
	return 0.12 if _cobweb_count > 0 else 1.0

func enter_cobweb() -> void:
	_cobweb_count += 1

func exit_cobweb() -> void:
	_cobweb_count = max(_cobweb_count - 1, 0)

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

# Distance-based contact damage. We no longer physically touch the player (collision
# exception), and the player's collision capsule sits low at its feet, so an Area
# overlap check was unreliable — proximity to the player is what matters. The player's
# own i-frames rate-limit this, so staying close chips HP once per i-frame window.
func _apply_contact_damage() -> void:
	if contact_damage <= 0.0:
		return
	var p := _player_node()
	if p == null or not p.has_method("take_damage"):
		return
	if global_position.distance_to(p.global_position) <= contact_range:
		p.take_damage(contact_damage, global_position)  # pass our pos for knockback

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
		# Basement publishes its Area2D room rects here (room_camera-free levels).
		if cam.has_meta("rooms"):
			return cam.get_meta("rooms")
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
