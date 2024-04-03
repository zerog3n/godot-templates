extends CharacterBody3D

@onready var world = get_node("/root/World")
@onready var nav_agent = $NavigationAgent3D
@onready var selection = $Selection

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# constants
const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# parameters
var selected = false
var move_target = null
var move_distance = 0.0

func _ready():
	deselect()
	add_to_group("units")

func _physics_process(delta):
	var direction = Vector3.ZERO
	
	# add the gravity
	if not is_on_floor(): velocity.y -= gravity * delta
	
	# movement + navigation
	move_distance = nav_agent.distance_to_target()
	var dest_reached = nav_agent.is_navigation_finished()
	
	if move_target and !dest_reached:
		#print("move_target:", move_target, " dest_reached:", dest_reached)
		var next_pos = to_local(nav_agent.get_next_path_position())
		direction = next_pos.normalized()
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		move_target = null
		velocity.x = 0
		velocity.z = 0
	
	# apply movement
	move_and_slide()
 
func select():
	selection.visible = true
	selected = true
 
func deselect():
	selection.visible = false
	selected = false

func move_to(target_pos):
	move_target = target_pos
	nav_agent.target_position = target_pos
