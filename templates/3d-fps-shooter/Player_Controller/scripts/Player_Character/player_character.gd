extends CharacterBody3D

var Game = preload("res://Library/Util/Game.gd").new()
var Player = preload("res://Library/Util/Player.gd").new()

const JUMP_VELOCITY = 4.0
const COYOTE_TIME = 0.1
const NORMAL_SPEED = 1.1
const EXTRA_SPEED = 0.5
const GRAVITY = 40
enum {
	GROUND_CROUCH = -1,
	STANDING = 0,
	AIR_CROUCH = 1
}
enum {
	LEFT = 1,
	CENTRE = 0,
	RIGHT = -1
}

@onready var Camera = get_node("%Camera")
@export var animation_tree: AnimationTree

var Inverted_Mouse: bool = true
var Inverted_Sprint: bool = true

#const SPEED = 5.0
var move_speed: float

var CameraRotation: Vector2 = Vector2(0.0,0.0)
var MouseSensitivity = 0.0009 # 0.001

var shake_rotation = 0 
var Start_Shake_Rotation = 0

var Crouched: bool = false
var Crouch_Blocked: bool = false
@export_category("Crouch Parametres")
@export var Crouch_Toggle: bool = true
@export var Crouch_Collision: ShapeCast3D
@export_range(0.0,3.0) var Crouch_Speed_Reduction = 4.4
@export_range(0.0,0.50) var Crouch_Blend_Speed = .14

@export_category("Lean Parametres")
@export_range(0.0,1.0) var Lean_Speed: float = .2
@export var Right_Lean_Collision: ShapeCast3D
@export var Left_Lean_Collision: ShapeCast3D
var lean_tween

@export_category("Speed Parameters")
@export var Sprint_Timer: Timer
#@export var Sprint_Cooldown_Timer: Timer

@export var Sprint_Cooldown_Time: float = 0.0
@export var Sprint_Time: float = 2.0
@export var Sprint_Replenish_rate: float = 1.0
@export var Sprint_Toggle: bool = true
var Sprint_On_Cooldown: bool = false
var Sprint_Time_Remaining: float = Sprint_Time
@onready var Sprint_Bar: Range = $CanvasLayer/Sprint_Bar

@export_range(1.0,3.0) var Sprint_Speed: float = 0.01
@export_range(0.1,1.0) var Walk_Speed: float = 0.01
var Speed_Modifier: float = NORMAL_SPEED

@export_category("Jump Parameters")
@export var Jump_Peak_Time: float = .1
@export var Jump_Fall_Time: float = 20.0
@export var Jump_Height: float = 0.6
@export var Jump_Distance: float = 0.5
@export var Jump_Buffer_Time: float = .2
@export var Coyote_Time: float = COYOTE_TIME
@onready var Coyote_Timer: Timer = $Coyote_Timer


# Get the gravity from the project settings to be synced with RigidBody nodes.
var Jump_Gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var Fall_Gravity: float
var Jump_Velocity: float
var Speed: float
var Jump_Available: bool = true
var Jump_Buffer: bool = false

var stop_count: int = 0
var last_dir: Vector3
var acceleration_dir: Vector3
var acceleration_rate: float = 0.4
var acceleration_delay: int = 500
var acceleration_time: int = 0

func _ready():
	Update_CameraRotation()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Calculate_Movement_Parameters()
	Game.start()
	
func Update_CameraRotation():
	var current_rotation = get_rotation()
	CameraRotation.x = current_rotation.y
	CameraRotation.y = current_rotation.x
	
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else: Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if event is InputEventMouseMotion:
		var MouseEvent = event.relative * MouseSensitivity
		CameraLook(MouseEvent)
		
	if event.is_action_pressed("crouch"): Crouch()
	if event.is_action_released("crouch"):
		if !Crouch_Toggle and Crouched:
			Crouch()
	
	if Input.is_action_just_released("lean_left") or Input.is_action_just_released("lean_right"):
		if !(Input.is_action_pressed("lean_right") or Input.is_action_pressed("lean_left")):
			lean(CENTRE)
	if Input.is_action_just_pressed("lean_left"):
		lean(LEFT)
	if Input.is_action_just_pressed("lean_right"):
		lean(RIGHT)
		
	if Input.is_action_just_released("sprint") or Input.is_action_just_released("walk"):
		if !(Input.is_action_pressed("walk") or Input.is_action_pressed("sprint")):
			if !Sprint_Toggle:
				Speed_Modifier = NORMAL_SPEED
				exit_sprint()

	if Input.is_action_just_pressed("sprint") and !Crouched:
		if !Sprint_On_Cooldown:
			#Sprint_Timer.start(Sprint_Time_Remaining)
			Sprint_Toggle = true
			Speed_Modifier = NORMAL_SPEED + EXTRA_SPEED

	if Input.is_action_just_pressed("walk") and !Crouched:
		Sprint_Toggle = false
		Speed_Modifier = NORMAL_SPEED

var screen_shake_inputs: int = 0
var screen_shake_time: int = 0
var screen_shake_delay: int = 100 # ms
var screen_is_shaking: bool = false
var screen_shake_action: StringName

func shake_screen():
	var now = Time.get_ticks_msec()
	
	if not screen_is_shaking: 
		Game.log('screen is shaking')
		screen_is_shaking = true
		screen_shake_time = now + screen_shake_delay
		
	if screen_shake_action:
		Game.log('screen shake action: ' + screen_shake_action)
		Player.input(screen_shake_action)
	
	if now < screen_shake_time: return
	
	if screen_shake_inputs >= 4:
		screen_is_shaking = false
		screen_shake_inputs = 0
		screen_shake_action = ''
	
	if screen_is_shaking:
		
		if screen_shake_inputs == 0:
			screen_shake_action = Player.input('lean_left')
			Game.log(' - left action press')
			screen_shake_time = now + screen_shake_delay
			screen_shake_inputs = 1
			return
			
		if screen_shake_inputs == 1:
			screen_shake_action = Player.input('lean_left')
			Game.log(' - left action release')
			screen_shake_time = now + screen_shake_delay
			screen_shake_inputs = 2
			return
			
		if screen_shake_inputs == 2:
			screen_shake_action = Player.input('lean_right')
			Game.log(' - right action press')
			screen_shake_time = now + screen_shake_delay
			screen_shake_inputs = 3
			return
			
		if screen_shake_inputs == 3:
			screen_shake_action = Player.input('lean_right')
			Game.log(' - right action release')
			screen_shake_time = now + screen_shake_delay
			screen_shake_inputs = 4
			
			return

func Calculate_Movement_Parameters()->void:
	#Jump_Gravity = (2*Jump_Height)/pow(Jump_Peak_Time,2)
	#Fall_Gravity = (2*Jump_Height)/pow(Jump_Fall_Time,2)
	Jump_Gravity = float(GRAVITY) / 2
	Fall_Gravity = GRAVITY
	Jump_Velocity = Jump_Gravity * Jump_Peak_Time
	Speed = Jump_Distance/(Jump_Peak_Time+Jump_Fall_Time)
	move_speed = Speed

func lean(blend_amount: int):
	#if is_on_floor():
	if lean_tween:
		lean_tween.kill()
	
	lean_tween = get_tree().create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SPRING)
	lean_tween.tween_property(animation_tree,"parameters/lean_blend/blend_amount", blend_amount, Lean_Speed)

func lean_collision():
	animation_tree["parameters/left_collision_blend/blend_amount"] = lerp(
		float(animation_tree["parameters/left_collision_blend/blend_amount"]),float(Left_Lean_Collision.is_colliding()),Lean_Speed
	)
	animation_tree["parameters/right_collision_blend/blend_amount"] = lerp(
		float(animation_tree["parameters/right_collision_blend/blend_amount"]),float(Right_Lean_Collision.is_colliding()),Lean_Speed
	)

func Crouch():
	var Blend
	if !Crouch_Collision.is_colliding():
		if Crouched:
			Blend = STANDING
		else:
			Speed_Modifier = NORMAL_SPEED
			Sprint_Toggle = false
			exit_sprint()
			
			if is_on_floor():
				Blend = GROUND_CROUCH
			else:
				Blend = AIR_CROUCH
		var blend_tween = get_tree().create_tween()
		blend_tween.tween_property(animation_tree,"parameters/Crouch_Blend/blend_amount",Blend,Crouch_Blend_Speed)
		Crouched = !Crouched
	else:
		Crouch_Blocked = true

func CameraLook(Movement: Vector2):
	CameraRotation += Movement
	
	transform.basis = Basis()
	Camera.transform.basis = Basis()
	
	var MouseRotation_y = -CameraRotation.y
	if Inverted_Mouse: MouseRotation_y = CameraRotation.y
	
	rotate_object_local(Vector3(0,1,0),-CameraRotation.x) # first rotate in Y
	Camera.rotate_object_local(Vector3(1,0,0), MouseRotation_y) # then rotate in X
	CameraRotation.y = clamp(CameraRotation.y,-1.5,1.2)
	
func exit_sprint():
	if !Sprint_Timer.is_stopped():
		Sprint_Time_Remaining = Sprint_Timer.time_left
		Sprint_Timer.stop()

func Sprint_Replenish(delta):
	var Sprint_Bar_Value
	if !Sprint_On_Cooldown and (Speed_Modifier != Sprint_Speed):
		# Stamina Replenishing
		#if not is_on_floor(): return # enable this if jumping should prevent stamina recovery
		if Input.is_action_pressed("sprint"): return
		Sprint_Time_Remaining = move_toward(Sprint_Time_Remaining, Sprint_Time, delta*Sprint_Replenish_rate*2)
		Sprint_Bar_Value= (Sprint_Time_Remaining/Sprint_Time)*100
		
	else:
		# Running
		Sprint_Bar_Value = (Sprint_Timer.time_left/Sprint_Time)*100
	
	#print("value:" + str(Sprint_Bar_Value), " timer:" + str(Sprint_Timer.time_left), " time:" + str(Sprint_Time))
	Sprint_Bar.value = Sprint_Bar_Value
	
	if Sprint_Bar_Value == 100:
		Sprint_Bar.hide()
	else:
		#Sprint_Bar.show()
		pass

var next_shake_time: int = 0

func _physics_process(delta):
	Sprint_Replenish(delta)
	lean_collision()
	
	#var now = Game.time()
	#if now > next_shake_time:
	#	next_shake_time = now + 5000
	#	shake_screen()
	
	#if screen_is_shaking:
	#	shake_screen()
		
	if Crouched and Crouch_Blocked:
		if !Crouch_Collision.is_colliding():
			Crouch_Blocked = false
			if !Input.is_action_pressed("crouch") and !Crouch_Toggle:
				Crouch()

	# Add the gravity.
	if not is_on_floor():
		if Coyote_Timer.is_stopped():
			Coyote_Timer.start(Coyote_Time)
	
		if velocity.y>0:
			velocity.y -= Jump_Gravity * delta
		else:
			velocity.y -= Fall_Gravity * delta
	else:
		Jump_Available = true
		Coyote_Timer.stop()
		var Speed_Multiplier = 0.5
		if Crouched: Speed_Multiplier = 0.8
		move_speed = (Speed / max((float(Crouched)*Crouch_Speed_Reduction),1)) * Speed_Modifier * Speed_Multiplier
		if Jump_Buffer:
			Jump()
			Jump_Buffer = false
	
	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept"):
		if Jump_Available:
			if Crouched:
				Crouch()
			else:
				lean(CENTRE)
				Jump()
		else:
			Jump_Buffer = true
			get_tree().create_timer(Jump_Buffer_Time).timeout.connect(on_jump_buffer_timeout)

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction == Vector3.ZERO and not Input.is_action_pressed("sprint"):
		stop_count += 1
		if stop_count > 30:
			stop_count = 0
			Sprint_Toggle = false
			Speed_Modifier = NORMAL_SPEED
	
	if abs(direction.x) > 0 or abs(direction.y) > 0:
		acceleration_dir = direction
	
	if abs(acceleration_dir.x) > 0 or abs(acceleration_dir.z) > 0:
		acceleration_dir.x = move_toward(acceleration_dir.x, 0, 4.0 * delta)
		acceleration_dir.z = move_toward(acceleration_dir.z, 0, 4.0 * delta)
		direction.x = direction.x + acceleration_dir.x
		direction.z = direction.z + acceleration_dir.z
		#print('acceleration applied', acceleration_dir)
	
	velocity.x = move_toward(velocity.x, direction.x * move_speed, Speed)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, Speed)
	
	move_and_slide()
	last_dir = direction

func Jump()->void:
	velocity.y = Jump_Velocity
	Jump_Available = false

func _on_sprint_timer_timeout() -> void:
	Sprint_On_Cooldown = true
	get_tree().create_timer(Sprint_Cooldown_Time).timeout.connect(_on_sprint_cooldown_timeout)
	Speed_Modifier = NORMAL_SPEED
	Sprint_Time_Remaining = 0

func _on_sprint_cooldown_timeout():
	Sprint_On_Cooldown = false


func _on_coyote_timer_timeout() -> void:
	Jump_Available = false

func on_jump_buffer_timeout()->void:
	Jump_Buffer = false
