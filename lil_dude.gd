extends CharacterBody2D

enum {IDLE, WALK}

const MAX_SPEED = 350
const ACCELERATION = 2000
const FRICTION = 2100

var state = IDLE # default state
var dir = Vector2.DOWN 

@onready var animationTree = $AnimationTree
@onready var animation = animationTree.get("parameters/playback")

func _ready():
	pass

func _physics_process(delta: float):
	dir = Input.get_vector("left", "right", "up", "down")
	dir = dir.normalized() # dir = normalized vector of key presses
	if dir != Vector2.ZERO: # state = walk if vector is not 0
		state = WALK
	else: # otherwise idle
		state = IDLE
	match state:
		IDLE:
			idle(delta)
		WALK:
			walk(delta)
			
	move_and_slide()
	
func idle(delta: float):
	animation.travel("idle") # play idle animation
	velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta) # slow down to stop
	
func walk(delta: float):
	animation.travel("walk")
	if dir.x != 0: # only update visible facing if x dir is not 0. fixes visual continuity
		updateDir()
	velocity = velocity.move_toward(dir * MAX_SPEED, ACCELERATION * delta) # speed up in dir vector
	
func updateDir(): # update visual direction of sprite 
	animationTree.set("parameters/idle/blend_position", dir.x)
	animationTree.set("parameters/walk/blend_position", dir.x)
