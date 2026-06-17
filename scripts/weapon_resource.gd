extends Resource
class_name WeaponResource

@export var id: String = "stick"
@export var display_name: String = "Stick"
@export var damage_multiplier: float = 1.0
@export var stamina_jab: float = 15.0
@export var stamina_slash: float = 25.0

# --- visuals (read by sword.gd when the weapon changes) ---
@export var texture_path: String = ""       # weapon sprite, drawn blade-up
@export var display_length: float = 46.0    # on-screen length of the weapon in px
@export var hitbox_radius: float = 18.0     # sword hit reach (bigger weapon = bigger)
