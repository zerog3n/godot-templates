extends CharacterBody2D

@onready var sprite = $Sprite2D
@onready var head_collision = $CollisionHead
@onready var head_ray1 = $RayCast1
@onready var head_ray2 = $RayCast2

@onready var music_loop = $Music/Loop
@onready var snd_jump = $Sounds/Jump
@onready var snd_land = $Sounds/Land

# Constants
const SPEED = 600.0
const JUMP_VELOCITY = -880.0
const ACCELERATION = 200
const FRICTION = 80

# Get the gravity from the project settings to be synced with RigidBody nodes.
var GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")

var last_dir: Vector2
var last_pos: Vector2
var last_frame: int

var tick_rate: int = 300
var tick_time: int = 0
var ticks = []
var update = ""

var input_wait: int = 0
var input_delay: int = 0
var input_time: int = 0

var physics_wait: int = 90
var physics_delay: int = 10
var physics_time: int = 0

var next_animation: int = 0

var input_queue = []
var physics_queue = []

var is_crouching: bool = false

var fall_time: int = 0
var slow_down: int = 0

# character sprite rect.
#  x: 128  |  y: 160
#  w: 144  |  h: 30

var rect_x: float = 128.0
var rect_y: float = 160.0
var rect_w: float = 144.0
var rect_h: float = 30.0

var character_girl: float = 0.0
var character_boy: float = 32.0
var character_red_knight: float = 64.0
var character_amber_knight: float = 96.0
var character_apprentice: float = 128.0
var character_wizard: float = 160.0
var character_dragon: float = 192.0
var character_lizard: float = 224.0
var character_tony: float = 256.0
var character_bob: float = 288.0

var character_time: int = 0

var ID

func _ready():
	var now: int = Time.get_ticks_msec()
	sprite.frame = 5
	physics_time = now + physics_wait
	music_loop.playing = true
	ID = str(self)
	set_character("dragon")

func _process(_delta):
	var now: int = Time.get_ticks_msec()
	
	if now > character_time:
		set_character(random_character())
		character_time = now + 1000
	
	# input delay
	if now > input_time + input_delay:
		input_time = now + input_wait
	
	# physics delay
	if now > physics_time + physics_delay:
		physics_time = now + physics_wait
		
	if now > tick_time:
		tick_time = now + tick_rate
		tick_updates()

func _physics_process(delta):
	var now: int = Time.get_ticks_msec()
	
	# Get the input direction and handle the movement/deceleration.
	var dir: Vector2 = input()
	if dir != Vector2.ZERO:
		#accelerate(dir)
		delay_input("move", dir)
	else:
		add_friction()
	
	# Check if the player is crouching
	is_crouch_active(dir)
	
	# Apply a boost
	if Input.is_action_just_pressed("ui_up"):
		push_backward(5.0)
	
	# Animate the player sprite
	play_animation()
	
	# Process delayed queues
	delayed_inputs()
	delayed_physics()
	
	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		player_jump()
		#delay_input("jump")
	
	# Add the gravity.
	if not is_on_floor():
		fall_time = now + 20
		velocity.y += GRAVITY * delta
	
	# Check for landing
	if fall_time and now > fall_time and is_on_floor(): 
		snd_land.playing = true
		fall_time = 0

	player_movement()
	last_dir = dir
	last_pos = global_position
	#print(last_pos)

func input() -> Vector2:
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("ui_left", "ui_right")
	input_dir.y = Input.get_axis("ui_up", "ui_down")
	input_dir = input_dir.normalized()
	return input_dir

func strtovector2(s: String):
	var d = str(s)
	d = d.replace("(", "")
	d = d.replace(")", "")
	d = d.replace(" ", "")
	var v = d.split(",")
	var vec: Vector2 = Vector2(float(v[0]), float(v[1]))
	return vec

func apply_force(direction: Vector2, force: Vector2):
	velocity.x = velocity.move_toward(SPEED * direction, ACCELERATION * force.x).x
	velocity.y = velocity.move_toward(SPEED * direction, ACCELERATION * force.y).y
	add_tick({ "a": "force", "pos": global_position, "vel": velocity })
	
func accelerate(direction):
	var dir: Vector2 = strtovector2(direction)
	velocity.x = velocity.move_toward(SPEED * dir, ACCELERATION).x
	add_tick({ "a": "move", "pos": global_position, "vel": velocity })

func add_friction():
	velocity.x = velocity.move_toward(Vector2.ZERO, FRICTION).x

func player_movement():
	if Input.is_action_pressed("ui_left"): sprite.flip_h = true
	if Input.is_action_pressed("ui_right"): sprite.flip_h = false
	move_and_slide()

func player_jump():
	if not is_on_floor(): return
	velocity.y = JUMP_VELOCITY
	snd_jump.playing = true
	add_tick({ "a": "jump", "pos": global_position, "vel": velocity })

func play_animation():
	var now: int = Time.get_ticks_msec()
	
	# Crouching
	if is_crouching: return
	if head_is_obstructed(): return
	
	# Walking
	if now > next_animation:
		sprite.frame = 5
		next_animation = Time.get_ticks_msec() + 600
	
	# Jumping
	if !is_on_floor():
		sprite.frame = 8
	if is_on_floor() and sprite.frame == 8:
		sprite.frame = 5 # landed on ground
	
	last_frame = sprite.frame

func is_crouch_active(direction):
	is_crouching = is_on_floor() and direction.y > 0
	
	if is_crouching:
		sprite.frame = 7
		head_collision.disabled = true
	else:
		if !head_is_obstructed():
			sprite.frame = 5
			head_collision.disabled = false
			return
	
	#add_friction()

func head_is_obstructed():
	return head_ray1.is_colliding() or head_ray2.is_colliding()

func facing_direction():
	var facing = last_dir.normalized().x
	var facing_left = (facing and facing < 0) or sprite.flip_h
	var x = 1 # right
	if facing_left: x = -1
	var dir: Vector2 = Vector2(x, 0)
	return dir

func delay_input(event, param = null):
	var action = str(event) + "|" + str(param)
	input_queue.push_back(action)

func push_backward(force: float = 12.0):
	var action = "push_backward|" + str(force)
	physics_queue.push_back(action)

func push_forward(force: float = 12.0):
	var action = "push_backward|" + str(force)
	physics_queue.push_back(action)

func physics_push_backward(force: float = 12.0):
	#var inverse_x = 0 - velocity.x
	var facing_dir = -1 if sprite.flip_h else 1
	var x = -facing_dir * 2
	var y = -0.2
	velocity = Vector2.ZERO
	apply_force(Vector2(x, y), Vector2(force, force / 2))

func physics_push_forward(force: float = 12.0):
	#var inverse_x = 0 - velocity.x
	var facing_dir = -1 if sprite.flip_h else 1
	var x = facing_dir * 2
	var y = -0.2
	velocity = Vector2.ZERO
	apply_force(Vector2(x, y), Vector2(force, force / 2))

func delayed_inputs():
	var now: int = Time.get_ticks_msec()
	if now < input_time: return
	
	for qa in input_queue:
		# Parse the queued action
		input_queue.pop_front()
		var i = qa.split("|", true)
		var action = i[0]
		var param = i[1]
		
		#print('delayed input: ', action, param)
		
		# Execute the queued action
		if action == 'jump':
			player_jump()
		if action == 'move':
			accelerate(param)

func delayed_physics():
	var now: int = Time.get_ticks_msec()
	if now < physics_time: return
	
	add_tick({ "a": "update", "pos": global_position, "vel": velocity })
	
	for qa in physics_queue:
		# Parse the queued action
		var i = qa.split("|", true)
		var action = i[0]
		var param = i[1]
		
		# Execute the queued action
		if action == 'push_backward':
			physics_push_backward(float(param))
			physics_queue.pop_front()

func set_character(n: String):
	# set character sprite positions
	if n == "girl": 			rect_y = float(character_girl)
	if n == "boy": 				rect_y = float(character_boy)
	if n == "red_knight": 		rect_y = float(character_red_knight)
	if n == "amber_knight": 	rect_y = float(character_amber_knight)
	if n == "apprentice": 		rect_y = float(character_apprentice)
	if n == "wizard": 			rect_y = float(character_wizard)
	if n == "dragon":			rect_y = float(character_dragon)
	if n == "lizard": 			rect_y = float(character_lizard)
	if n == "tony": 			rect_y = float(character_tony)
	if n == "bob": 				rect_y = float(character_bob)
	sprite.region_rect = Rect2(rect_x, rect_y, rect_w, rect_h)

func random_character():
	var r = randf()
	var c = [
		"girl", "boy", "red_knight", "amber_knight", 
		"apprentice", "wizard", "dragon", "lizard", "tony", "bob"
	]
	var i = randi() % c.size()
	return c[i]

var last_update

func add_tick(t):
	var epoch: float = Time.get_unix_time_from_system()
	var now: int = int(epoch * 1000)
	t["ts"] = now
	if is_last_update(t): return
	ticks.push_back(t)
	if t["a"] == "update": last_update = t
	if t["a"] == "move": last_update = t

func is_last_update(t):
	if not t: return false
	if not last_update: return false
	var t_pos = t["pos"]
	var t_vel = t["vel"]
	var u_pos = last_update["pos"]
	var u_vel = last_update["vel"]
	if t_pos == u_pos and t_vel == u_vel:
		return true
	return false

func tick_updates():
	if ticks.size():
		show_ticks() # simulate sending ws.message
		ticks = []   # flush and clear

var message_count = 0
func show_ticks():
	for t in ticks:
		var format_string = "ts:{ts}|action:{a}|pos:{pos}|vel:{vel}"
		var actual_string = format_string.format(t)
		update += actual_string + "\n"
	
	message_count += 1
	update = " -- " + "[" + str(update.length()) + "]" + " id:" + ID + " (message_id=" + str(message_count) + ")" + "\n" + update
	print(update)
	update = ""
