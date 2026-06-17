extends Area2D

signal collected(weapon_id: String)

@export var weapon_id: String = "dagger"
@export var display_name: String = "Dagger"

@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	if label:
		label.text = display_name
	_load_icon()
	body_entered.connect(_on_body_entered)

# show the weapon's actual sprite (from its .tres) instead of a plain box
func _load_icon() -> void:
	if sprite == null:
		return
	var path := "res://data/%s.tres" % weapon_id
	if not ResourceLoader.exists(path):
		return
	var w = load(path)
	if w == null or not ("texture_path" in w):
		return
	if w.texture_path == "" or not ResourceLoader.exists(w.texture_path):
		return
	var tex: Texture2D = load(w.texture_path)
	if tex:
		sprite.texture = tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var longest := float(maxi(tex.get_width(), tex.get_height()))
		sprite.scale = Vector2.ONE * (40.0 / maxf(longest, 1.0))  # ~40px pickup icon

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		GameManager.set_weapon(weapon_id)
		collected.emit(weapon_id)
		queue_free()
