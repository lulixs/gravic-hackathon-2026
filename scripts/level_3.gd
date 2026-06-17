extends Node2D

# Level 3 — Castle (the finale), built on env.tscn's 3-room tilemap + room camera.
# Flow: Room A pig guards + blade trap -> portcullis to Room B -> The Boarden
# (drops Broadsword) -> gate to Room C -> The Flying Pig -> reclaim your wings.

@onready var gate_b: StaticBody2D = $GateB
@onready var gate_c: StaticBody2D = $GateC
@onready var broadsword: Area2D = $BroadswordPickup
@onready var victory_label: CanvasLayer = $VictoryLabel
@onready var dialogue = $DialogueBox

var guards_total := 0
var guards_dead := 0
var boarden_dead := false
var pig_dead := false

func _ready() -> void:
	# Blockout convenience: when booting straight into Level 3 (skipping 0/1), arrive
	# with the gear you'd canonically have from the basement instead of the starter
	# stick, plus some XP to exercise the upgrade menu. Harmless once levels chain.
	if GameManager.current_weapon == "stick":
		GameManager.set_weapon("flatsword")
		GameManager.add_xp(150)

	broadsword.visible = false
	broadsword.monitoring = false
	victory_label.visible = false

	for g in get_tree().get_nodes_in_group("guard"):
		guards_total += 1
		g.died.connect(_on_guard_died)
	if has_node("Boarden"):
		$Boarden.died.connect(_on_boarden_died)
	if has_node("FlyingPig"):
		$FlyingPig.died.connect(_on_pig_died)

	dialogue.play_lines([
		{"speaker": "Narrator", "text": "The castle of the [color=#ff8a3a]Flying Pig[/color]. Your stolen wings hang somewhere within these walls."},
		{"speaker": "Narrator", "text": "His guards hold the hall. Mind the old blade-trap — it does not care whose side you're on."},
		{"speaker": "Narrator", "text": "Cut through them, break the warden, and climb to the throne."},
	])

func _on_guard_died() -> void:
	guards_dead += 1
	if guards_dead >= guards_total:
		_open_gate(gate_b)
		dialogue.play_lines([
			{"speaker": "Narrator", "text": "The hall falls silent. The portcullis to the [color=#cfcfe6]warden's keep[/color] grinds open."},
		])

func _on_boarden_died() -> void:
	if boarden_dead:
		return
	boarden_dead = true
	broadsword.visible = true
	broadsword.monitoring = true
	_open_gate(gate_c)
	dialogue.play_lines([
		{"speaker": "Narrator", "text": "The Boarden crashes down. His [color=#9ad0ff]Battle-axe[/color] clatters free — take it."},
		{"speaker": "Narrator", "text": "The throne room gate is open. The Pig is all that stands between you and the sky."},
	])

func _on_pig_died() -> void:
	if pig_dead:
		return
	pig_dead = true
	victory_label.visible = true
	get_tree().paused = true

func _open_gate(gate: StaticBody2D) -> void:
	gate.visible = false
	for c in gate.get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
