extends Node2D
## Level 2 — Garden. One large open garden with a follow camera. Worms and
## grasshoppers roam; mud patches slow you. Step on all three pressure plates to
## open the gate to the Garden Serpent's den; beating her drops the Broadsword.
## Carries the player's weapon / XP / HP over from the basement (no GameManager.reset()).

const ROOM := Rect2(0, 0, 2400, 1500)
const NEXT_LEVEL := "res://levels/level_3_castle.tscn"

@onready var gate: StaticBody2D = $Gate
@onready var broadsword: Area2D = $BroadswordPickup
@onready var complete_label: CanvasLayer = $CompleteLabel
@onready var dialogue = $DialogueBox

var plates_total := 0
var plates_active := 0
var gate_open := false
var weapon_collected := false

func _ready() -> void:
	# one big room — camera follows the player and clamps to the garden bounds
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_node("Camera2D"):
		player.get_node("Camera2D").setup([
			{"rect": ROOM, "limits": ROOM},
		])

	broadsword.visible = false
	broadsword.monitoring = false
	complete_label.visible = false

	for p in get_tree().get_nodes_in_group("plate"):
		plates_total += 1
		p.activated.connect(_on_plate_activated)
	for b in get_tree().get_nodes_in_group("boss"):
		b.died.connect(_on_boss_died)
	broadsword.collected.connect(_on_weapon_collected)

	dialogue.play_lines([
		{"speaker": "Narrator", "text": "The Garden. Sunlight at last — but the soil here bites back."},
		{"speaker": "Narrator", "text": "Worms churn the earth and hoppers strike from the weeds. Mind the mud; it drags at your wings."},
		{"speaker": "Narrator", "text": "Find the three [color=#ffe08a]stone plates[/color] and stand on each to raise the gate to the serpent's den."},
	])

func _on_plate_activated() -> void:
	plates_active += 1
	if plates_active >= plates_total and not gate_open:
		gate_open = true
		gate.visible = false
		for c in gate.get_children():
			if c is CollisionShape2D:
				c.set_deferred("disabled", true)
		dialogue.play_lines([
			{"speaker": "Narrator", "text": "Stone grinds on stone — the gate yawns open. The [color=#9ad06a]Garden Serpent[/color] waits in the hollow below."},
		])

func _on_boss_died() -> void:
	broadsword.visible = true
	broadsword.monitoring = true
	dialogue.play_lines([
		{"speaker": "Narrator", "text": "The serpent coils, then stills. A [color=#9ad0ff]Broadsword[/color] lies half-buried in the loam — claim it."},
	])

func _on_weapon_collected(_id: String) -> void:
	if weapon_collected:
		return
	weapon_collected = true
	if NEXT_LEVEL != "":
		get_tree().change_scene_to_file(NEXT_LEVEL)
	else:
		complete_label.visible = true
		get_tree().paused = true
