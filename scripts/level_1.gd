extends Node2D

# Level 1 — Basement. A real combat room: clear the swarm of (non-docile) bugs, the
# Flatsword drops, grab it, then the exit opens. No GameManager.reset() here — XP,
# upgrades, and the Dagger all carry over from the tutorial.

@onready var flatsword: Area2D = $FlatswordPickup
@onready var exit_door: Area2D = $ExitDoor
@onready var complete_label: CanvasLayer = $CompleteLabel
@onready var dialogue: CanvasLayer = $DialogueBox

var enemies_remaining := 0
var weapon_collected := false
var cleared_dialogue_shown := false

func _ready() -> void:
	flatsword.visible = false
	flatsword.monitoring = false
	exit_door.monitoring = false
	exit_door.modulate = Color(0.6, 0.2, 0.2, 1)
	complete_label.visible = false

	for e in get_tree().get_nodes_in_group("enemy"):
		enemies_remaining += 1
		if e.has_signal("died"):
			e.died.connect(_on_enemy_died)

	flatsword.collected.connect(_on_weapon_collected)
	exit_door.body_entered.connect(_on_exit_entered)

	dialogue.play_lines([
		{"speaker": "Narrator", "text": "The Basement. Damp, dark, and crawling with things that bite."},
		{"speaker": "Narrator", "text": "Clear them out. Mind the [color=#cfcfe6]cobwebs[/color] — they'll bog your wings down to a crawl."},
		{"speaker": "Narrator", "text": "Survive, and a real blade awaits."},
	])

func _on_enemy_died() -> void:
	enemies_remaining -= 1
	if enemies_remaining <= 0:
		flatsword.visible = true
		flatsword.monitoring = true
		if not cleared_dialogue_shown:
			cleared_dialogue_shown = true
			dialogue.play_lines([
				{"speaker": "Narrator", "text": "Silence at last. A [color=#9ad0ff]Flatsword[/color] lies in the muck — twice the bite of that dagger."},
				{"speaker": "Narrator", "text": "Take it and find the way out."},
			])

func _on_weapon_collected(_id: String) -> void:
	weapon_collected = true
	exit_door.monitoring = true
	exit_door.modulate = Color(0.3, 0.9, 0.4, 1)

func _on_exit_entered(body: Node) -> void:
	if not weapon_collected:
		return
	if body.is_in_group("player"):
		complete_label.visible = true
		get_tree().paused = true
