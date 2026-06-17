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
		if $Boarden.has_signal("half_health"):
			$Boarden.half_health.connect(_on_boarden_half)
	if has_node("FlyingPig"):
		$FlyingPig.died.connect(_on_pig_died)
		if $FlyingPig.has_signal("half_health"):
			$FlyingPig.half_health.connect(_on_pig_half)

	dialogue.play_lines([
		{"speaker": "Old Fly", "text": "This is where they stopped pretending."},
		{"speaker": "You", "text": "[i]The air here feels… controlled. Like something is watching the corridors themselves.[/i]"},
		{"speaker": "Pig Guard", "text": "Stay where you belong."},
		{"speaker": "Pig Guard", "text": "The sky already has an owner."},
		{"speaker": "Narrator", "text": "Cut through the guards, break the warden, and climb to the throne. Mind the old blade-trap — it does not care whose side you're on."},
	])

func _on_guard_died() -> void:
	guards_dead += 1
	if guards_dead >= guards_total:
		_open_gate(gate_b)
		dialogue.play_lines([
			{"speaker": "Narrator", "text": "The hall falls silent. The portcullis to the [color=#cfcfe6]warden's keep[/color] grinds open."},
			{"speaker": "Boarden", "text": "Crush anything that enters. That is what I was made for."},
			{"speaker": "Boarden", "text": "There is no escape path here. Only clearance."},
		])

func _on_boarden_half() -> void:
	dialogue.play_lines([
		{"speaker": "Boarden", "text": "You are still trying to move forward. That is your mistake."},
	])

func _on_boarden_died() -> void:
	if boarden_dead:
		return
	boarden_dead = true
	broadsword.visible = true
	broadsword.monitoring = true
	_open_gate(gate_c)
	dialogue.play_lines([
		{"speaker": "Boarden", "text": "[i]He… will not be pleased…[/i]"},
		{"speaker": "Narrator", "text": "The Boarden crashes down. His [color=#9ad0ff]Battle-axe[/color] clatters free — take it."},
		{"speaker": "Old Fly", "text": "The castle opens now. That is not the same as freedom."},
		{"speaker": "You", "text": "[i]I am getting closer to something I shouldn't be able to reach.[/i]"},
		{"speaker": "Old Fly", "text": "If you see him… don't mistake height for power."},
		{"speaker": "You", "text": "[i]So this is what stole the sky.[/i]"},
		{"speaker": "Flying Pig", "text": "You made it all the way here. That alone is impressive."},
		{"speaker": "Flying Pig", "text": "Most never make it past what I built."},
		{"speaker": "Flying Pig", "text": "I didn't steal wings. I perfected them."},
	])

func _on_pig_half() -> void:
	dialogue.play_lines([
		{"speaker": "Flying Pig", "text": "Do you feel it? The sky obeys me now."},
		{"speaker": "Flying Pig", "text": "You are not flying. You are being allowed to rise."},
	])

func _on_pig_died() -> void:
	if pig_dead:
		return
	pig_dead = true
	# final break -> ending cutscene -> victory screen
	dialogue.finished.connect(_on_ending_done)
	dialogue.play_lines([
		{"speaker": "Flying Pig", "text": "[i]I only wanted… to stop falling…[/i]"},
		{"speaker": "Flying Pig", "text": "[i]Why won't it hold together…[/i]"},
		{"speaker": "Flying Pig", "text": "[i]I almost had it… just once…[/i]"},
		{"speaker": "Narrator", "text": "What was taken did not return as it was. It returned as something new."},
		{"speaker": "Old Fly", "text": "We don't belong to the ground anymore. Not again."},
		{"speaker": "You", "text": "[i]The sky was never stolen. It was just waiting to be remembered.[/i]"},
		{"speaker": "Narrator", "text": "And so… they flew."},
	])

func _on_ending_done() -> void:
	victory_label.visible = true
	get_tree().paused = true

func _open_gate(gate: StaticBody2D) -> void:
	gate.visible = false
	for c in gate.get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
