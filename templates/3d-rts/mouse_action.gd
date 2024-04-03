extends Node3D

var lifetime = 0.40
var color = Color.WHITE_SMOKE
var radius = 0.05
var rate = 0.12
var min_radius = 0.05
var max_radius = 0.30
var mesh
var sphere
var material
var next_frame = 0

func _ready():
	spawn_animation()

func _process(delta):
	var now = Time.get_ticks_msec()
	if now > next_frame:
		next_frame = now + 15 # every 15ms
		animate()

func animate():
	if not sphere: return
	if sphere.radius < max_radius:
		var tween = create_tween()
		var r = clampf(sphere.radius + rate, min_radius, max_radius)
		tween.tween_property(sphere, "radius", r, 0.2)
		# TODO: add opacity tween

func spawn_animation():
	mesh = MeshInstance3D.new()
	sphere = SphereMesh.new()
	material = ORMMaterial3D.new()
	mesh.mesh = sphere
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.position = position
	sphere.radius = radius
	sphere.height = radius*2
	sphere.material = material
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	get_tree().get_root().add_child(mesh)
	return await mesh_cleanup()

func mesh_cleanup():
	await get_tree().create_timer(lifetime).timeout
	if mesh: mesh.queue_free()
