extends Node2D

## Room-based camera controller for the basement.
##
## Each room is an Area2D child of this node whose CollisionPolygon2D describes
## the room's extent. The player's Camera2D follows the player but is clamped to
## the bounds of whichever room the player is currently in. Walking into a new
## room fades the screen to black, snaps the camera limits to the new room, then
## fades back in.

## Duration (seconds) of each half of the fade (out, then in).
const FADE_TIME := 0.25

## How far (px) the player must enter the pits room before its spiders wake.
const PITS_ACTIVATION_INSET := 64.0

@onready var player: CharacterBody2D = $CharacterBody2D
@onready var camera: Camera2D = $CharacterBody2D/Camera2D

# Gameplay nodes (the merged tutorial: dialogue, control hints, spiders, rewards, door).
@onready var dialogue: CanvasLayer = $DialogueBox
@onready var prompt: CanvasLayer = $TutorialPrompt
@onready var dagger: Area2D = $DaggerPickup
@onready var key_pickup: Area2D = $KeyPickup
@onready var door: StaticBody2D = $Door

# room1 docile-spider reward (tracked by explicit node refs, NOT the global
# "enemy" group — the level now holds many enemies across rooms).
@onready var _room1_spiders: Array = [$Spider1, $Spider2, $Spider3]

# room4 key encounter: the egg sacs + their hand-placed guards. Sac-spawned
# babies are deliberately excluded so the key isn't blocked by infinite spawns.
@onready var _room4_guards: Array = [$EggSac1, $EggSac2, $Guard1, $Guard2]
@onready var key2: Area2D = $Key2Pickup
@onready var door2: StaticBody2D = $Door2

# Final boss + its flatsword reward.
@onready var broodmother = $Broodmother
@onready var flatsword: Area2D = $FlatswordPickup
@onready var boss_gate: StaticBody2D = $BossGate

var _fade_rect: ColorRect
var _current_room: Area2D
var _tween: Tween

# Flow state.
var spiders_remaining := 0
var _spiders_cleared := false
var room4_remaining := 0
var _room4_cleared := false
var _door_open := false
var _door2_open := false
var _boss_locked := false
var _flatsword_taken := false
var _room1_intro_shown := false
var _room2_intro_shown := false
var _room4_intro_shown := false
var _boss_intro_shown := false


func _ready() -> void:
	_build_fade_overlay()

	for room in _get_rooms():
		room.body_entered.connect(_on_room_body_entered.bind(room))

	_connect_ramp()

	# Snap straight to whichever room the player starts in (no fade).
	var start := _room_containing(player.global_position)
	if start == null and not _get_rooms().is_empty():
		start = _get_rooms()[0]
	if start:
		_current_room = start
		_apply_room_limits(start)

	_publish_rooms_to_camera()
	_setup_gameplay()


## Enemies (enemy_base.gd `player_in_same_room()`) read room rects off the player's
## Camera2D. Publish ours so enemies stay dormant until the player shares their room.
func _publish_rooms_to_camera() -> void:
	var rooms: Array = []
	for room in _get_rooms():
		var r := _room_bounds(room)
		if room.name == "room2":
			# Pits room: hold the spiders until the player steps ~2 tiles (64px) past
			# the entrance, so they don't lunge the instant the room comes on screen.
			r.position.x += PITS_ACTIVATION_INSET
			r.size.x -= PITS_ACTIVATION_INSET
		rooms.append({"rect": r})
	camera.set_meta("rooms", rooms)


# ---------------- Tutorial / gameplay flow ----------------

func _setup_gameplay() -> void:
	# The basement is now the game's opening level — start fresh with the stick.
	GameManager.reset()

	# Rewards stay hidden until their encounter is cleared.
	_hide_pickup(dagger)
	_hide_pickup(key_pickup)
	_hide_pickup(key2)
	_hide_pickup(flatsword)
	_set_boss_gate_closed(false)  # open until the player enters the arena
	prompt.hide_panel()

	# room1: the three docile tutorial spiders → dagger + key #1.
	for spider in _room1_spiders:
		spiders_remaining += 1
		spider.died.connect(_on_spider_died)
	key_pickup.collected.connect(_on_key_collected)

	# room4: the egg sacs + guards → key #2.
	for guard in _room4_guards:
		room4_remaining += 1
		guard.died.connect(_on_room4_guard_died)
	key2.collected.connect(_on_key2_collected)

	# Final boss → flatsword → level 2.
	broodmother.died.connect(_on_boss_died)
	flatsword.collected.connect(_on_flatsword_collected)

	# Intro plot crawl, then hand control to the action-hint tutorial (once).
	dialogue.finished.connect(_on_intro_done, CONNECT_ONE_SHOT)
	dialogue.play_lines([
		{"speaker": "Narrator", "text": "You are a fly. A common housefly — discarded, ignored, despised."},
		{"speaker": "Narrator", "text": "But far above, the [color=#ff8a3a]Flying Pig[/color] has stirred. He has tasted ambition. He has tasted bacon."},
		{"speaker": "Narrator", "text": "Only one creature is small enough to slip past his guards. Only one is foolish enough to try."},
		{"speaker": "Narrator", "text": "First, the basics — to strike, to block, to dance away from death. Learn them here in the dark."},
	])


func _hide_pickup(p: Area2D) -> void:
	p.visible = false
	p.monitoring = false


## Boss arena gate: closed = visible barrier + solid collision, open = hidden + passable.
func _set_boss_gate_closed(closed: bool) -> void:
	boss_gate.visible = closed
	for c in boss_gate.get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", not closed)


func _on_intro_done() -> void:
	prompt.begin()


func _on_spider_died() -> void:
	spiders_remaining -= 1
	if spiders_remaining > 0 or _spiders_cleared:
		return
	_spiders_cleared = true
	prompt.complete_action("kill_all")
	# Drop the rewards where the player can grab them.
	dagger.visible = true
	dagger.monitoring = true
	key_pickup.visible = true
	key_pickup.monitoring = true
	dialogue.play_lines([
		{"speaker": "Narrator", "text": "The spiders fall. Something glints in the dust — a [color=#c08aff]Dagger[/color], crude but yours."},
		{"speaker": "Narrator", "text": "And a heavy iron [color=#ffd24a]Key[/color] clatters loose. The door to the east has been waiting for it."},
	])


func _on_key_collected() -> void:
	if _door_open:
		return
	_door_open = true
	door.visible = false
	for c in door.get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	dialogue.play_lines([
		{"speaker": "Narrator", "text": "The key bites into the lock and turns. The door grinds open — deeper into the basement."},
	])


func _on_room4_guard_died() -> void:
	room4_remaining -= 1
	if room4_remaining > 0 or _room4_cleared:
		return
	_room4_cleared = true
	key2.visible = true
	key2.monitoring = true
	dialogue.play_lines([
		{"speaker": "Narrator", "text": "The sacs burst and go still. Among the ruin lies a second [color=#ffd24a]Key[/color] — the way onward."},
	])


func _on_key2_collected() -> void:
	if _door2_open:
		return
	_door2_open = true
	door2.visible = false
	for c in door2.get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	dialogue.play_lines([
		{"speaker": "Narrator", "text": "The far door yields. Beyond it, a long hall — and something vast breathing at its end."},
	])


func _on_boss_died() -> void:
	flatsword.visible = true
	flatsword.monitoring = true
	dialogue.play_lines([
		{"speaker": "Narrator", "text": "The Broodmother shrieks and falls. A [color=#9ad0ff]Flatsword[/color] gleams in the gore — take it."},
	])


func _on_flatsword_collected(_id: String) -> void:
	if _flatsword_taken:
		return
	_flatsword_taken = true
	# Flatsword in hand — leave the basement for the Garden.
	await get_tree().create_timer(0.6).timeout
	get_tree().change_scene_to_file("res://levels/level_2_garden.tscn")


## Every Area2D child is treated as a room, except the ramp (handled separately).
func _get_rooms() -> Array:
	var rooms: Array = []
	for child in get_children():
		if child is Area2D and child.name != "ramp" and child.has_node("CollisionPolygon2D"):
			rooms.append(child)
	return rooms


## The ramp is not a room: it just toggles the player's on_ramp flag so the
## player script can apply the slope drift while standing on it.
func _connect_ramp() -> void:
	var ramp := get_node_or_null("ramp")
	if ramp == null:
		return
	ramp.body_entered.connect(func(body): if body == player: player.on_ramp = true)
	ramp.body_exited.connect(func(body): if body == player: player.on_ramp = false)


func _build_fade_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.anchor_right = 1.0
	_fade_rect.anchor_bottom = 1.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.modulate.a = 0.0
	layer.add_child(_fade_rect)


## World-space bounding box of a room's collision polygon.
func _room_bounds(room: Area2D) -> Rect2:
	var poly := room.get_node("CollisionPolygon2D") as CollisionPolygon2D
	var points := poly.polygon
	var xform := poly.global_transform
	var rect := Rect2(xform * points[0], Vector2.ZERO)
	for i in range(1, points.size()):
		rect = rect.expand(xform * points[i])
	return rect


func _room_containing(point: Vector2) -> Area2D:
	for room in _get_rooms():
		if _room_bounds(room).has_point(point):
			return room
	return null


func _apply_room_limits(room: Area2D) -> void:
	var b := _room_bounds(room)
	camera.limit_left = int(b.position.x)
	camera.limit_top = int(b.position.y)
	camera.limit_right = int(b.position.x + b.size.x)
	camera.limit_bottom = int(b.position.y + b.size.y)
	# Jump the camera to its clamped target instead of sliding there.
	camera.reset_smoothing()


func _on_room_body_entered(body: Node, room: Area2D) -> void:
	if body != player:
		return
	if room == _current_room:
		return
	_start_transition(room)


func _start_transition(room: Area2D) -> void:
	# Claim the target room immediately so repeated/overlapping entry signals
	# from the same room are ignored while the fade plays.
	_current_room = room

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(_fade_rect, "modulate:a", 1.0, FADE_TIME)
	_tween.tween_callback(_apply_room_limits.bind(room))
	_tween.tween_property(_fade_rect, "modulate:a", 0.0, FADE_TIME)
	# After the fade settles, run any one-time dialogue for the room just entered.
	_tween.tween_callback(_after_transition.bind(room))


## Room-specific narration that should play once the fade-in finishes (so the
## dialogue's tree-pause doesn't freeze the transition mid-fade).
func _after_transition(room: Area2D) -> void:
	if room.name == "room1" and not _room1_intro_shown:
		_room1_intro_shown = true
		dialogue.play_lines([
			{"speaker": "Narrator", "text": "Through here — the brood nest. Three sleepy spiders nap in the gloom."},
			{"speaker": "Narrator", "text": "They won't fight back. Practice on them: strike, charge, and cut them down to claim what they guard."},
		])
	elif room.name == "room2":
		# Reaching the pits ends the tutorial — clear any lingering control hints.
		prompt.dismiss()
		if not _room2_intro_shown:
			_room2_intro_shown = true
			dialogue.play_lines([
				{"speaker": "Narrator", "text": "These ones are awake — and hungry. Mind the ledges, and don't let them swarm you."},
			])
	elif room.name == "room4" and not _room4_intro_shown:
		_room4_intro_shown = true
		dialogue.play_lines([
			{"speaker": "Narrator", "text": "Egg sacs, fat and twitching — they'll spill broodlings without end. Burst the sacs to stop the tide."},
		])
	elif room.name == "Area2D3":
		# Seal the arena behind the player — no retreat until the Broodmother falls.
		if not _boss_locked:
			_boss_locked = true
			_set_boss_gate_closed(true)
		if not _boss_intro_shown:
			_boss_intro_shown = true
			dialogue.play_lines([
				{"speaker": "Narrator", "text": "The hall opens into her lair. The [color=#ff6a6a]Broodmother[/color] rises. End her, and the way out is yours."},
			])
