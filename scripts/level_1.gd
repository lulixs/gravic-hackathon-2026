extends Node2D

# Level 1 — Basement (built on env.tscn's 3-room tilemap + room camera).
# Flow: Room A spiders -> Room B egg sacs -> Room C pipe puzzle gate -> Broodmother
# boss in the lower arena -> Flatsword drop -> done. No GameManager.reset(): the
# Dagger, XP and upgrades all carry over from the tutorial.

@onready var puzzle = $PipePuzzle
@onready var gate: StaticBody2D = $Gate
@onready var flatsword: Area2D = $FlatswordPickup
@onready var complete_label: CanvasLayer = $CompleteLabel
@onready var dialogue = $DialogueBox

var sacks_total := 0
var sacks_dead := 0
var sacks_cleared := false
var puzzle_solved := false
var gate_open := false
var weapon_collected := false

func _ready() -> void:
	flatsword.visible = false
	flatsword.monitoring = false
	complete_label.visible = false

	for s in get_tree().get_nodes_in_group("sack"):
		sacks_total += 1
		s.died.connect(_on_sack_died)
	for b in get_tree().get_nodes_in_group("boss"):
		b.died.connect(_on_boss_died)
		if b.has_signal("half_health"):
			b.half_health.connect(_on_boss_half)
	puzzle.solved.connect(_on_puzzle_solved)
	flatsword.collected.connect(_on_weapon_collected)

	dialogue.play_lines([
		{"speaker": "You", "text": "[i]This place forgets things quickly. Especially things with wings.[/i]"},
		{"speaker": "You", "text": "[i]These webs didn't grow here. They were placed.[/i]"},
		{"speaker": "Spider Sac", "text": "[i]More will come… More will always come…[/i]"},
		{"speaker": "You", "text": "[i]Everything here feels… stuck. Like it's waiting to be eaten.[/i]"},
		{"speaker": "Narrator", "text": "Burst the [color=#cfcfe6]egg sacs[/color] in the lower chamber, then turn the rusted pipes upright to open the brood gate."},
	])

func _on_sack_died() -> void:
	sacks_dead += 1
	if sacks_dead >= sacks_total and not sacks_cleared:
		sacks_cleared = true
		dialogue.play_lines([
			{"speaker": "Narrator", "text": "The sacs are burst. Now the [color=#ffe08a]pipes[/color] in the east chamber — turn them all upright."},
		])
		_try_open_gate()

func _on_puzzle_solved() -> void:
	puzzle_solved = true
	_try_open_gate()

func _try_open_gate() -> void:
	if gate_open or not (sacks_cleared and puzzle_solved):
		return
	gate_open = true
	gate.visible = false
	for c in gate.get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	dialogue.play_lines([
		{"speaker": "Narrator", "text": "The brood gate grinds open. The [color=#ff6a6a]Broodmother[/color] stirs in the dark below."},
		{"speaker": "Broodmother", "text": "Little crawler… You don't belong in my silk."},
		{"speaker": "Broodmother", "text": "I remember what you used to be. Before you fell."},
	])

func _on_boss_half() -> void:
	dialogue.play_lines([
		{"speaker": "Broodmother", "text": "All things return to thread. Even you."},
	])

func _on_boss_died() -> void:
	flatsword.visible = true
	flatsword.monitoring = true
	dialogue.play_lines([
		{"speaker": "Broodmother", "text": "[i]The sky… was never yours… It was borrowed…[/i]"},
		{"speaker": "You", "text": "[i]The basement is quieter now. That isn't the same as safe.[/i]"},
		{"speaker": "You", "text": "[i]Something above is brighter… but not warmer.[/i]"},
		{"speaker": "Narrator", "text": "A [color=#9ad0ff]Flatsword[/color] gleams in the gore — take it."},
	])

func _on_weapon_collected(_id: String) -> void:
	if weapon_collected:
		return
	weapon_collected = true
	# Flatsword in hand — descend out of the basement into the Garden
	await get_tree().create_timer(0.6).timeout
	get_tree().change_scene_to_file("res://levels/level_2_garden.tscn")
