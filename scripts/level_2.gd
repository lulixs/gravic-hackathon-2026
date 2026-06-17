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
		if b.has_signal("half_health"):
			b.half_health.connect(_on_boss_half)
	broadsword.collected.connect(_on_weapon_collected)

	dialogue.play_lines([
		{"speaker": "You", "text": "[i]Outside isn't freedom. It's just distance from safety.[/i]"},
		{"speaker": "You", "text": "[i]The air feels wider here. But so do the dangers.[/i]"},
		{"speaker": "Snake", "text": "[i]…hungry…[/i]"},
		{"speaker": "Narrator", "text": "Snakes and hoppers prowl the weeds; mud drags at your wings. Stand on the three [color=#ffe08a]stone plates[/color] to raise the gate to the frog's pond."},
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
			{"speaker": "Narrator", "text": "Stone grinds on stone — the gate yawns open. The [color=#9ad06a]Bullfrog[/color] squats in the hollow below."},
			{"speaker": "Bullfrog", "text": "Things fall into my pond. And I keep what falls."},
			{"speaker": "Bullfrog", "text": "You are small enough to forget."},
		])

func _on_boss_half() -> void:
	dialogue.play_lines([
		{"speaker": "Bullfrog", "text": "You struggle like everything else. That is why you are delicious."},
	])

func _on_boss_died() -> void:
	broadsword.visible = true
	broadsword.monitoring = true
	dialogue.play_lines([
		{"speaker": "Bullfrog", "text": "[i]Even the sky… sends leftovers…[/i]"},
		{"speaker": "You", "text": "[i]The ground isn't empty. It just hides more carefully out here.[/i]"},
		{"speaker": "You", "text": "[i]I move faster than I used to… but I still feel behind everything.[/i]"},
		{"speaker": "Narrator", "text": "A [color=#9ad0ff]Broadsword[/color] lies half-buried in the loam — claim it."},
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
