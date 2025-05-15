extends Node3D
class_name Unit

const debug = false
const debug_path = false

# object instances
@onready var world = get_node("/root/World")
@onready var body = get_node('../Body')
@onready var parent = get_parent()
@onready var selection = $Selection
@onready var path = $Path
@onready var ray_cast_floor = $Path/Floor
@onready var ray_cast_ledge = $Path/Ledge
@onready var ray_cast_left = $Path/Left
@onready var ray_cast_right = $Path/Right
@onready var ray_cast_forward = $Path/Forward
@onready var left_position = $Path/Points/Left
@onready var right_position = $Path/Points/Right
@onready var forward_position = $Path/Points/Forward
@onready var agent = get_node('NavigationAgent3D') as NavigationAgent3D

# game settings
var GRAVITY = ProjectSettings.get_setting("physics/3d/default_gravity")

# global variables
@export var SPEED = 5.0
@export var JUMP_VELOCITY = 4.5

# performance settings
@export var min_distance_to_target = 1 # 4
@export var max_distance_to_target = 2 # 12
@export var timeout_near_target = 2000
@export var timeout_path_duration = 4000
@export var timeout_max_duration = 90000 # 1.5 mins
@export var timeout_path_check = 400
@export var timeout_move_check = 400
@export var timeout_direction_change = 400
@export var bbox_size = Vector3(1.0, 2.0, 1.0)

# gameplay parameters
var selected = false
var path_target = null
var look_target = null
var move_target = null
var move_distance = 0.0
var last_move_dir = null
var last_move_pos = Vector3()
var use_direct_path = true
var current_action = 'init'
var velocity = Vector3()
var moving = false
var falling = false
var attacking = false
var units_in_area = []
var path_vectors = []

# spatial parameters
var bbox_point: AABB
var bbox_normal: AABB
var bbox_large: AABB
var bbox_area: AABB

func _ready():
	deselect()
	add_to_group("units")
	world.register_unit(self)
	bbox_point = AABB(parent.global_transform.origin, Vector3(1, 1, 1))
	bbox_normal = self.get_bbox(1)
	bbox_large = self.get_bbox(3)
	bbox_area = self.get_bbox(12)
	#call_deferred("update_navigation_server")


func _process(_delta):
	if !current_action: return
	near_target_timer()

var next_physics_process_time = 0
func _physics_process(delta):
	var now = Time.get_ticks_msec()
	if now > next_physics_process_time:
		next_physics_process_time = now + 150
	else:
		return
	
	call_deferred("check_in_level")
	#call_deferred("check_collisions")
	
	# improves performance
	# - eliminates excessive node physics calls
	if !current_action: 
		pause_process()
		return
	
	# movement parameters
	var direction = Vector3.ZERO
	
	# apply gravity
	falling = false
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		falling = true
	
	# movement + navigation
	if move_target:
		face_target()
		direction = await next_move_dir()
	
	# don't walk off ledges
	if on_ledge():
		direction.x = 0
		direction.z = 0

	# apply movement
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	
	# apply movement in sub-thread
	if !turning: call_deferred("move_and_slide")
	
	if current_action == 'init' and !falling:
		current_action = null


func is_on_floor():
	if falling: return false
	if ray_cast_floor.is_colliding(): return true
	if parent.global_transform.origin.z >= bbox_normal.size.y * 0.5: return true
	return false


#var next_collision_time = 0
#func check_collisions():
	#var now = Time.get_ticks_msec()
	#if now > next_collision_time:
		#next_collision_time = now + 1000
		#collision.use_collision = !collision.use_collision


var next_physics_time = 0

func move_and_slide():
	if !can_path(): return
	var speed = 0.1
	var now = Time.get_ticks_msec()
	if now > next_physics_time:
		next_physics_time = now + 150
		var ox = to_global(velocity * 0.1).x
		var oz = to_global(velocity * 0.1).z
		var tween = create_tween()
		bbox_normal.position = parent.global_transform.origin
		tween.parallel().tween_property(parent, "global_transform:origin:x", ox, speed)
		tween.parallel().tween_property(parent, "global_transform:origin:y", bbox_normal.size.y  * 0.5, speed)
		tween.parallel().tween_property(parent, "global_transform:origin:z", oz, speed)
		get_navigation_path()


func update_navigation_path():
	if !path_target: return
	await get_tree().physics_frame
	agent.set_target_position(path_target)
	#var start = parent.global_transform.origin
	#var end = path_target
	#var map: RID = NavigationServer3D.get_maps()[0]
	#print(map)
	#await get_tree().physics_frame
	#var nav_path = NavigationServer3D.map_get_path(map, start, end, false)
	#print('navigation path: ', nav_path)


func get_navigation_path():
	if !path_target: return
	if !agent.target_position:
		await update_navigation_path()
		return
	
	if path_vectors.size(): return
	
	if debug: print(self, ' updating path.')
	var p = agent.get_current_navigation_path()
	path_vectors = p
	
	var pos: Vector3 = agent.get_next_path_position()
	#print('agent finished: ', agent.is_navigation_finished())
	#print('agent path: ', p)
	#print('agent pos: ', pos)


func check_in_level():
	if parent.global_transform.origin.y < -5.0:
		print('warning - unit fell out of level at ' + str(parent.global_transform.origin))
		call_deferred("free")

func get_bbox(size = 1):
	var aabb := AABB(parent.global_transform.origin, bbox_size * size)
	return aabb

func find_units_nearby():
	var found = []
	var units = world.units()
	for unit in units:
		if unit == self: continue
		if !unit: continue
		bbox_large.position = global_transform.origin
		var is_inside = bbox_large.has_point(unit.global_transform.origin)
		if is_inside: found.append(unit)
	return found

func find_units_in_area():
	var found = []
	var units = world.units()
	
	for unit in units:
		if unit == self: continue
		if !unit: continue
		
		bbox_area.position = global_transform.origin
		
		#if debug_path: 
		#	bbox_point.position = unit.global_transform.origin
		#	box(global_transform.origin, bbox_area.size, 0.2, Color('#FFB74A', 0.01))
		#	box(unit.global_transform.origin, bbox_point.size * 4, 0.2, Color('#FFFF99', 0.01))
		
		var ux = unit.global_transform.origin.x
		var uz = unit.global_transform.origin.z
		
		var point_is_inside = bbox_area.intersects_ray(unit.global_transform.origin, Vector3(ux, 1, uz))
		if point_is_inside: found.append(unit)
	
	#if debug_path:
	#	print('find_units_in_area: ', self, ' -- ', found)
	
	return found


func pause_process():
	self.process_mode = Node.PROCESS_MODE_DISABLED
	pause_path_nodes()
func resume_process():
	self.process_mode = Node.PROCESS_MODE_INHERIT
	resume_path_nodes()

func pause_path_nodes():
	ray_cast_ledge.enabled = false
	ray_cast_forward.enabled = false
	ray_cast_left.enabled = false
	ray_cast_right.enabled = false
	
func resume_path_nodes():
	ray_cast_ledge.enabled = true
	ray_cast_forward.enabled = true
	ray_cast_left.enabled = true
	ray_cast_right.enabled = true
	

var facing = false
var turning = false

func face_target():
	if facing: return
	turning = true
	var origin = self.global_transform.origin
	var target = origin - look_target
	var target_angle = atan2(target.x, target.z)
	var qtn = Quaternion(Vector3.UP, target_angle)
	var tween = create_tween()
	var speed = 0.1
	tween.parallel().tween_property(body, "quaternion", qtn, speed)
	tween.parallel().tween_property(path, "quaternion", qtn, speed)
	facing = true
	turning = false


func select():
	selection.visible = true
	selected = true

func deselect():
	selection.visible = false
	selected = false

func set_action(action: String):
	current_action = action
	resume_process()

func unset_action():
	current_action = null


var path_start_time = 0

func move_to(target_pos):
	path_target = target_pos
	use_direct_path = true
	path_to(target_pos)
	path_start_time = Time.get_ticks_msec()
	set_action('move')

func path_to(target_pos):
	look_target = target_pos
	move_target = target_pos
	last_move_dir = null
	facing = false

func end_path_to_target():
	#await delay(1000)
	near_target_time = 0
	near_target_ms = 0
	path_target = null
	move_target = null
	last_move_dir = null
	moving = false
	unset_action()
	
	if debug: print(self, ' path completed.')
	return true

func found_path_to_target():
	var now = Time.get_ticks_msec()
	var diff = randf()
	var duration_ms = now - path_start_time
	
	if units_in_area.size() >= 12 and dist_to_target() < 12:
		return end_path_to_target()
	
	if dist_to_target() < min_distance_to_target + diff:
		return end_path_to_target()
		
	if dist_to_target() < max_distance_to_target + diff:
		if near_target_ms > timeout_near_target:
			return end_path_to_target()
		if duration_ms > timeout_path_duration:
			return end_path_to_target()
	
	if duration_ms > timeout_max_duration:
		return end_path_to_target()
	
	return false


var near_target_ms = 0
var near_target_time = 0

func is_near_target():
	return near_target_ms >= 1

func near_target_timer():
	var now = Time.get_ticks_msec()
	if now > near_target_time:
		near_target_time = now + 100
		if dist_to_target() < min_distance_to_target:
			near_target_ms += 100
		else: near_target_ms = 0


func on_ledge():
	if !ray_cast_ledge.is_colliding(): return true
	return false

var next_move_time = 0
var bad_move_count = 0
var last_distance = 0

func is_moving(): # checks if we have moved since the last move time
	var now = Time.get_ticks_msec()
	if now > next_move_time:
		next_move_time = now + timeout_move_check
		
		# if move than 0.01 from last pos - we are moving
		if abs(dist_to_target() - last_distance) > 0.1:
			bad_move_count = 0
			moving = true
		
		# track each bad move
		bad_move_count += 1
		
		# we are not moving
		if bad_move_count >= 1:
			is_pathing() # turn on pathing briefly
			if debug: print(self, ' is not moving')
			moving = false
	
	last_distance = dist_to_target()
	last_move_pos = self.global_transform.origin
	
	return moving


var next_path_time = 0

func is_pathing(): # checks if we are deviating from direct path
	var now = Time.get_ticks_msec()
	if now > next_path_time:
		next_path_time = now + timeout_path_check # checks once every 50ms
		return true
	return false


func left_direction():
	return left_position.global_position
func right_direction():
	return right_position.global_position
func forward_direction():
	return forward_position.global_position


func random_direction():
	if random(): return right_direction()
	else: return left_direction()


func left_distance():
	return left_position.global_position.distance_to(path_target)
func right_distance():
	return right_position.global_position.distance_to(path_target)


func can_move_forward():
	if !ray_cast_forward.is_colliding(): return true
	return false
func can_turn_left():
	if !ray_cast_left.is_colliding(): return true
	return false
func can_turn_right():
	if !ray_cast_right.is_colliding(): return true
	return false


func dist_to_target():
	if path_target:
		var dist = self.global_transform.origin.distance_to(path_target)
		#print(self, ' distance to target: ', dist, ' ', bad_move_count)
		return dist
	return 10000.0


var next_dir_time = 0
var next_turn_time = 0
var last_dir = Vector3.ZERO

func find_move_direction():
	if use_direct_path: return
	
	var dir = path_target
	var now = Time.get_ticks_msec()
	
	if now > next_dir_time:
		next_dir_time = now + timeout_direction_change
		
		if random():
			if random():
				if random():
					use_direct_path = true
					path_to(path_target)
					return
		
		if is_pathing():
			
			if is_moving() and can_move_forward():
				path_to(forward_direction())
				return
			
			# each turn direction availability
			var lt = can_turn_left()
			var rt = can_turn_right()
			
			# the closest turn direction
			var ld = left_distance()
			var rd = right_distance()
			
			# check if can turn only left or right
			# - return available direction
			# - or return the current direction
			if lt and !rt:
				if debug: print(' - left turn')
				dir = left_direction()
				
			elif rt and !lt:
				if debug: print(' - right turn')
				dir = right_direction()
			
			elif ld < rd:
				if debug: print(' - left turn (distance)')
				dir = left_direction()
				
			elif rd < ld:
				if debug: print(' - right turn (distance)')
				dir = right_direction()
				
			else:
				dir = random_direction()
				var turn = 'right'
				if dir != right_direction(): turn = 'left'
				if debug: print(' - ' + turn + ' turn (random)')
			
			units_in_area = find_units_in_area()
			
			last_dir = dir
			return path_to(dir)


func check_direct_path():
	if !use_direct_path: return
	if !can_move_forward(): use_direct_path = false
	if !can_turn_left(): use_direct_path = false
	if !can_turn_left(): use_direct_path = false

func can_path():
	if !can_move_forward(): return false
	if !can_turn_left(): return false
	if !can_turn_left(): return false
	return true


func next_move_dir():
	if found_path_to_target():
		return Vector3.ZERO
	
	if !path_target:
		return Vector3.ZERO
	
	check_direct_path()
	find_move_direction()
	
	if random():
		if random():
			if random():
				return Vector3.ZERO
	
	if !move_target:
		return Vector3.ZERO
	
	# calculate normalised direction
	var origin = self.global_transform.origin
	var target = move_target - origin
	var direction = target.normalized()
	
	last_move_dir = direction
	return direction


func point(pos: Vector3, lifetime = 0.2, radius = 0.025, color = Color.WHITE_SMOKE):
	var mesh_instance := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	var material := ORMMaterial3D.new()
	mesh_instance.mesh = sphere_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.position = pos
	sphere_mesh.radius = radius
	sphere_mesh.height = radius*2
	sphere_mesh.material = material
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	get_tree().get_root().add_child(mesh_instance)
	await get_tree().create_timer(lifetime).timeout
	mesh_instance.queue_free()


func line(pos1: Vector3, pos2: Vector3, lifetime = 0.2, color = Color.WHITE_SMOKE):
	var mesh_instance := MeshInstance3D.new()
	var immediate_mesh := ImmediateMesh.new()
	var material := ORMMaterial3D.new()
	mesh_instance.mesh = immediate_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate_mesh.surface_add_vertex(pos1)
	immediate_mesh.surface_add_vertex(pos2)
	immediate_mesh.surface_end()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	get_tree().get_root().add_child(mesh_instance)
	await get_tree().create_timer(lifetime).timeout
	mesh_instance.free()


func box(pos: Vector3, size = Vector3(1,1,1), lifetime = 0.2, color = Color.WHITE_SMOKE, transparency = 0.1):
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	var material := ORMMaterial3D.new()
	mesh_instance.mesh = box_mesh
	box_mesh.size = size
	box_mesh.material = material
	#material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = transparency
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.position = pos
	get_tree().get_root().add_child(mesh_instance)
	await get_tree().create_timer(lifetime).timeout
	mesh_instance.free()


func delay(ms: int):
	await get_tree().create_timer(ms * 0.001).timeout
	return true


func random():
	var r = randf()
	if r < 0.5: return true
	return false


func randomish():
	var r = randf()
	if r < 0.7: return true
	return false

