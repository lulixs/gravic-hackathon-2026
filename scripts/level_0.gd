extends Node2D

@onready var prompt: CanvasLayer = $TutorialPrompt
@onready var dagger: Area2D = $DaggerPickup
@onready var exit_door: Area2D = $ExitDoor
@onready var complete_label: CanvasLayer = $CompleteLabel

var spiders_remaining := 0
var dagger_collected := false

func _ready() -> void:
	# Reset run on tutorial entry (idempotent — fresh stats)
	GameManager.reset()

	dagger.visible = false
	dagger.monitoring = false
	exit_door.monitoring = false
	exit_door.modulate = Color(0.6, 0.2, 0.2, 1)
	complete_label.visible = false

	for spider in get_tree().get_nodes_in_group("enemy"):
		spiders_remaining += 1
		if spider.has_signal("died"):
			spider.died.connect(_on_spider_died)

	dagger.collected.connect(_on_dagger_collected)
	exit_door.body_entered.connect(_on_exit_entered)

func _on_spider_died() -> void:
	spiders_remaining -= 1
	if spiders_remaining <= 0:
		prompt.complete_action("kill_all")
		dagger.visible = true
		dagger.monitoring = true

func _on_dagger_collected(_id: String) -> void:
	dagger_collected = true
	exit_door.monitoring = true
	exit_door.modulate = Color(0.3, 0.9, 0.4, 1)

func _on_exit_entered(body: Node) -> void:
	if not dagger_collected:
		return
	if body.is_in_group("player"):
		# Level 1 not built yet — show a completion banner.
		complete_label.visible = true
		get_tree().paused = true
