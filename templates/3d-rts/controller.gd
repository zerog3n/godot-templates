extends Node3D

var mouse_action = preload("res://mouse_action.tscn")

@onready var camera = $Camera3D
@onready var select = $SelectBox

# constants
const SPEED = 1
const ZOOM_SPEED = 1
const MAX_ZOOM = 10
const MOVE_MARGIN = 20
const MOVE_SPEED = 30

# parameters
var camera_speed = 1
var camera_origin
var mouse_position = Vector2()

var is_zooming = false
var last_zoom_direction
var zoom_direction
var zoom_decay = 0
var zoom_acceleration = 0.0

var last_move_direction
var move_direction
var move_decay = 0
var move_acceleration = 0.0
var last_click_position

var unit_on_hover
var selected_units = []
var single_select = false
var multi_select = false


func _ready():
	#get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME # debugging
	var refresh_rate = DisplayServer.screen_get_refresh_rate()
	if refresh_rate < 0.0: refresh_rate = 60.0
	
	Engine.max_fps = int(refresh_rate)
	Engine.physics_ticks_per_second = int(refresh_rate)
	
	if refresh_rate >= 144:
		ProjectSettings.set_setting("lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 5)
		ProjectSettings.set_setting("lights_and_shadows/positional_shadow/soft_shadow_filter_quality", 5)
	
	if refresh_rate <= 60:
		ProjectSettings.set_setting("lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 0)
		ProjectSettings.set_setting("lights_and_shadows/positional_shadow/soft_shadow_filter_quality", 0)
	
	camera_origin = camera.position
	print('camera initialised: refresh_rate = ' + str(refresh_rate))


func _process(_delta):
	if Input.is_action_just_pressed("cancel_action"):
		cancel_actions()
	
	if Input.is_action_just_pressed("secondary_action"):
		var pos = get_mouse_ground_position()
		if pos:
			spawn_action_click(pos, Color('#00FF00')) # Color('#3ECFFF')
			move_selected_units(pos)
	
	elif Input.is_action_just_released("primary_action"):
		mouse_position = get_viewport().get_mouse_position()
		unselect()
		select_units(mouse_position, select.start_position)
		last_click_position = null
	
	elif Input.is_action_just_pressed("primary_action"):
		mouse_position = get_viewport().get_mouse_position()
		var unit = get_unit_under_mouse()
		if unit and unit != unit_on_hover:
			unit_on_hover = unit
		else: unit_on_hover = null
		last_click_position = mouse_position

func unselect():
	if not last_click_position: return
	if is_select_box_active(): return
	if not unit_on_hover:
		deselect_all()

func is_select_box_active():
	var min_side_length = 4
	var x = select.box_size.x
	var y = select.box_size.y
	if x > min_side_length and y > min_side_length: return true
	return false

func cancel_actions():
	for unit in selected_units:
		if unit and "unset_action" in unit: unit.unset_action()

func move_selected_units(pos):
	for unit in selected_units:
		if unit and "move_to" in unit: unit.move_to(pos)

func select_units(pos, start):
	var new_selected_units = []
	var in_selection = get_units_in_selection(start, pos)
	
	# single unit selection
	if unit_on_hover != null and !is_select_box_active():
		deselect_all()
		new_selected_units.append(unit_on_hover)
		single_select = true
		multi_select = false
	
	# multi unit selection
	elif in_selection.size():
		deselect_all()
		new_selected_units = in_selection
		single_select = false
		multi_select = true
	
	if new_selected_units.size() != 0:
		for unit in new_selected_units:
			if unit and "select" in unit:
				#print(unit, ' selected.')
				unit.select()
		selected_units = new_selected_units

func deselect_all():
	for unit in selected_units:
		if "deselect" in unit: unit.deselect()
	selected_units = []

func _physics_process(delta):
	var input_alternate = Input.is_action_pressed("alternative_action")
	
	# camera zoom
	var input_zoom_in = Input.is_action_just_released("camera_zoom_in")
	var input_zoom_out = Input.is_action_just_released("camera_zoom_out")
	var zoom_amount = 4
	if input_alternate: zoom_amount = 8
	if input_zoom_in:
		zoom(-zoom_amount)
	if input_zoom_out: 
		zoom(zoom_amount)
	
	# camera movement
	var input_dir = Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	var speed = SPEED * camera_speed
	var multiplier = 2
	if input_alternate: multiplier = 4
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		last_move_direction = direction
		move_acceleration = min(move_acceleration + 0.1, 0.25)
		camera.global_position.x += direction.x * speed * move_acceleration * multiplier
		camera.global_position.z += direction.z * speed * move_acceleration * multiplier
		move_decay = 0.25
	else:
		if move_decay > 0:
			camera.global_position.x += last_move_direction.x * speed * 0.25 * move_decay
			camera.global_position.z += last_move_direction.z * speed * 0.25 * move_decay
			move_decay = move_decay - 1 * delta
		else:
			last_move_direction = null
			move_acceleration = 0

func zoom(dir: float):
	var tween = create_tween()
	var dest = camera.position + Vector3(0, dir, 0)
	tween.tween_property(camera, "position:y", dest.y, 0.2)

func get_unit_under_mouse():
	var result = shoot_ray(5)
	if result:
		var unit = result.collider.get_parent()
		#print('get_unit_under_mouse: ', str(result))
		#print('get_unit_under_mouse: ', str(result.collider))
		#print('get_unit_under_mouse: ', str(unit))
		return unit

func get_mouse_ground_position():
	var result = shoot_ray(1)
	#print('get_mouse_ground_position: ', str(result))
	if result: return result.position

func get_units_in_selection(top_left, bot_right):
	if top_left.x > bot_right.x:
		var tmp = top_left.x
		top_left.x = bot_right.x
		bot_right.x = tmp
	if top_left.y > bot_right.y:
		var tmp = top_left.y
		top_left.y = bot_right.y
		bot_right.y = tmp
	var rect = Rect2(top_left, bot_right - top_left)
	var box_selected_units = []
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if rect.has_point(camera.unproject_position(unit.global_transform.origin)):
			#box(unit.global_transform.origin)
			box_selected_units.append(unit)
	return box_selected_units

func shoot_ray(mask = 5):
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_length = 1000
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * ray_length
	#line(from, to, 15)
	var space = get_world_3d().direct_space_state
	var params = PhysicsRayQueryParameters3D.new()
	params.from = from
	params.to = to
	params.exclude = []
	params.collision_mask = mask
	return space.intersect_ray(params)

func line(pos1: Vector3, pos2: Vector3, lifetime = 0.2, color = Color.WHITE_SMOKE):
	var mesh_instance := MeshInstance3D.new()
	var immediate_mesh := ImmediateMesh.new()
	var material := ORMMaterial3D.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate_mesh.surface_add_vertex(pos1)
	immediate_mesh.surface_add_vertex(pos2)
	immediate_mesh.surface_end()
	mesh_instance.mesh = immediate_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	get_tree().get_root().add_child(mesh_instance)
	return await mesh_cleanup(mesh_instance, lifetime)

func point(pos: Vector3, lifetime = 0.2, radius = 0.05, color = Color.WHITE_SMOKE):
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
	return await mesh_cleanup(mesh_instance, lifetime)

func box(pos: Vector3, size = Vector3(1,1,1), lifetime = 0.6, color = Color.CYAN, transparency = 0.3):
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

func spawn_action_click(pos: Vector3, color = Color.WHITE_SMOKE):
	var e = mouse_action.instantiate()
	e.position = pos
	e.color = color
	get_tree().get_root().add_child(e)

func mesh_cleanup(mesh_instance: MeshInstance3D, lifetime: float = 0.5):
	await get_tree().create_timer(lifetime).timeout
	mesh_instance.queue_free()

func final_cleanup(mesh_instance: MeshInstance3D, persist_ms: float):
	get_tree().get_root().add_child(mesh_instance)
	if persist_ms == 1:
		await get_tree().physics_frame
		mesh_instance.queue_free()
		print('cleanup')
	elif persist_ms > 0:
		await get_tree().create_timer(persist_ms).timeout
		mesh_instance.queue_free()
		print('cleanup')
	else: return mesh_instance
