extends Node2D

@onready var prompt: CanvasLayer = $TutorialPrompt
@onready var dialogue: CanvasLayer = $DialogueBox
@onready var dagger: Area2D = $DaggerPickup
@onready var exit_door: Area2D = $ExitDoor
@onready var complete_label: CanvasLayer = $CompleteLabel

var spiders_remaining := 0
var dagger_collected := false
var mid_dialogue_shown := false

func _ready() -> void:
	GameManager.reset()

	dagger.visible = false
	dagger.monitoring = false
	exit_door.monitoring = false
	exit_door.modulate = Color(0.6, 0.2, 0.2, 1)
	complete_label.visible = false
	prompt.hide_panel()

	for spider in get_tree().get_nodes_in_group("enemy"):
		spiders_remaining += 1
		if spider.has_signal("died"):
			spider.died.connect(_on_spider_died)

	dagger.collected.connect(_on_dagger_collected)
	exit_door.body_entered.connect(_on_exit_entered)

	# kick off the intro plot scrawl, then hand control to the tutorial prompt
	dialogue.finished.connect(_on_intro_done)
	dialogue.play_lines([
		{"speaker": "Narrator", "text": "You are a fly. A common housefly — discarded, ignored, despised."},
		{"speaker": "Narrator", "text": "But high above the kingdom, the [color=#ff8a3a]Flying Pig[/color] has stirred. He has tasted ambition. He has tasted bacon."},
		{"speaker": "Narrator", "text": "Only one creature small enough to slip past his guards. Only one creature stupid enough to try."},
		{"speaker": "Narrator", "text": "Down here in the dirt, you must learn the basics: to strike, to block, to dance away from death."},
		{"speaker": "Narrator", "text": "Three sleepy spiders nap below. Use them. When pigs fly, only the flies can save us."},
	])

func _on_intro_done() -> void:
	prompt.begin()

func _on_spider_died() -> void:
	spiders_remaining -= 1
	if spiders_remaining <= 0:
		prompt.complete_action("kill_all")
		dagger.visible = true
		dagger.monitoring = true
		if not mid_dialogue_shown:
			mid_dialogue_shown = true
			dialogue.finished.disconnect(_on_intro_done)
			dialogue.finished.connect(_on_mid_done)
			dialogue.play_lines([
				{"speaker": "Narrator", "text": "The spiders fall. Something glints in the dust — a [color=#c08aff]Dagger[/color]. Crude, but yours."},
				{"speaker": "Narrator", "text": "Grab it, then head for the door. The Basement waits, and it is not so kind."},
			])

func _on_mid_done() -> void:
	pass

func _on_dagger_collected(_id: String) -> void:
	dagger_collected = true
	exit_door.monitoring = true
	exit_door.modulate = Color(0.3, 0.9, 0.4, 1)

func _on_exit_entered(body: Node) -> void:
	if not dagger_collected:
		return
	if body.is_in_group("player"):
		get_tree().change_scene_to_file("res://levels/level_1_basement.tscn")
