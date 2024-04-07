extends CharacterBody3D
class_name Unit

@onready var world = get_node("/root/World")
@onready var selection = $Selection
@onready var body = $Body
@onready var collision_shape = $CollisionShape

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# constants
const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# parameters
var selected = false
var look_target = null
var move_target = null
var move_distance = 0.0
var next_move_time = 0
var last_pos = Vector3()

var nav_enabled = false
var nav_agent: NavigationAgent3D

func _ready():
	deselect()
	add_to_group("units")
	create_nav_agent()

func _process(_delta):
	if move_target and nav_agent:
		nav_agent.target_position = move_target

func _physics_process(delta):
	var now = Time.get_ticks_msec()
	var direction = Vector3.ZERO
	
	# add the gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# movement + navigation
	if nav_agent and nav_enabled:
		move_distance = nav_agent.distance_to_target()
		var dest_reached = nav_agent.is_navigation_finished()
		if move_target and !dest_reached:
			face_target()
			var next_pos = to_local(nav_agent.get_next_path_position())
			direction = next_pos.normalized()

		# check move time
		if now > next_move_time:
			next_move_time = now + ( 1000 * 20 )
			if position == last_pos:
				nav_agent.target_position = position
				move_target = null
			last_pos = position

	# apply movement in sub-thread
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	call_deferred("move_and_slide")
 
var facing = false

func face_target():
	var next_pos = nav_agent.get_next_path_position()
	if next_pos != move_target:
		look_target = next_pos
		facing = false
	if facing: return
	var origin = self.global_transform.origin
	var target = origin - look_target
	var target_angle = atan2(target.x, target.z)
	var q = Quaternion(Vector3.UP, target_angle)
	var tween = create_tween()
	tween.parallel().tween_property(body, "quaternion", q, 0.2)
	tween.parallel().tween_property(collision_shape, "quaternion", q, 0.2)
	facing = true

func select():
	selection.visible = true
	selected = true
 
func deselect():
	selection.visible = false
	selected = false

func move_to(target_pos):
	move_target = target_pos
	look_target = target_pos
	nav_agent.target_position = target_pos
	facing = false

func create_nav_agent():
	if not nav_agent:
		nav_agent = NavigationAgent3D.new()
		nav_agent.max_neighbors = 4
		nav_agent.radius = 2.0
		nav_agent.path_max_distance = 2.0
		#nav_agent.debug_enabled = true
		nav_enabled = true
		add_child(nav_agent)
