extends StaticBody2D

## A wall the player can only pass through by dashing (dodge). While the player
## is mid-dash we open a collision exception so they phase through; we re-solidify
## only once the dash has ended AND the player has cleared the wall, so they can
## never be left stuck inside it.

var _player: CharacterBody2D
var _open := false

func _physics_process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return

	var dashing: bool = _player.has_method("is_dashing") and _player.is_dashing()
	if dashing and not _open:
		_open = true
		add_collision_exception_with(_player)
	elif _open and not dashing and not _player_inside():
		_open = false
		remove_collision_exception_with(_player)


## Is the player still overlapping the wall's rectangle (plus a small margin)?
func _player_inside() -> bool:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null or _player == null or not (cs.shape is RectangleShape2D):
		return false
	var half: Vector2 = (cs.shape as RectangleShape2D).size * 0.5
	var local := cs.to_local(_player.global_position)
	return absf(local.x) <= half.x + 12.0 and absf(local.y) <= half.y + 12.0
