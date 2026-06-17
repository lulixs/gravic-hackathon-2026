extends Node2D

@onready var prompt: CanvasLayer = $TutorialPrompt
@onready var dialogue: CanvasLayer = $DialogueBox
@onready var dagger: Area2D = $DaggerPickup
@onready var complete_label: CanvasLayer = $CompleteLabel

const NEXT_LEVEL := "res://levels/level_1_basement.tscn"
const ROOM := Rect2(0, 0, 1280, 720)  # the whole tutorial room

var spiders_remaining := 0
var dagger_collected := false
var mid_dialogue_shown := false

func _ready() -> void:
	GameManager.reset()

	# one single room — lock the camera to the whole thing (no sub-rooms, no fades)
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_node("Camera2D"):
		player.get_node("Camera2D").setup([
			{"rect": ROOM, "limits": ROOM},
		])

	dagger.visible = false
	dagger.monitoring = false
	complete_label.visible = false
	prompt.hide_panel()

	for spider in get_tree().get_nodes_in_group("enemy"):
		spiders_remaining += 1
		if spider.has_signal("died"):
			spider.died.connect(_on_spider_died)

	dagger.collected.connect(_on_dagger_collected)

	# kick off the intro plot scrawl, then hand control to the tutorial prompt
	dialogue.finished.connect(_on_intro_done)
	dialogue.play_lines([
		{"speaker": "Narrator", "text": "We were never meant to walk."},
		{"speaker": "Narrator", "text": "We were meant to drift. To belong to the air without asking permission."},
		{"speaker": "Narrator", "text": "But something below us began to look upward."},
		{"speaker": "Pig King", "text": "[i]If I had wings… I would never fall again.[/i]"},
		{"speaker": "Narrator", "text": "And envy learned how to build."},
		{"speaker": "Narrator", "text": "And how to take."},
		{"speaker": "Old Fly", "text": "Don't stay still for too long. Stillness is how they find you."},
		{"speaker": "Old Fly", "text": "Down here in the dirt, learn the basics: to strike, to dance away from death. Three sleepy spiders nap nearby — use them."},
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
			dialogue.play_lines([
				{"speaker": "Old Fly", "text": "The spiders fall. Something glints in the dust — a [color=#c08aff]Dagger[/color]. Crude, but yours."},
				{"speaker": "Old Fly", "text": "Grab it. The instant it's in your grip, the floor gives way — down into the Basement."},
			])

func _on_dagger_collected(_id: String) -> void:
	if dagger_collected:
		return
	dagger_collected = true
	# picking up the dagger drops you straight into the next level
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file(NEXT_LEVEL)
