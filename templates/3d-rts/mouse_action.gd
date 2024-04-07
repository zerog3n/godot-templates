extends Node3D

var lifetime = 0.6
var color = Color.WHITE_SMOKE
var radius = 0.02
var rate_fade = 0.4
var rate_sphere = 0.14
var rate_torus = 0.10
var min_radius = 0.02
var max_radius = 1.60
var mesh: MeshInstance3D
var sphere: SphereMesh
var torus: TorusMesh
var material: ORMMaterial3D

func _ready():
	spawn_animation()

func _process(_delta):
	animate()
	fade()

var next_frame = 0
func animate():
	var now = Time.get_ticks_msec()
	if now > next_frame:
		next_frame = now + 200
		
		if sphere and sphere.radius < max_radius:
			var tween = create_tween()
			var r = clampf(sphere.radius + rate_sphere, min_radius, max_radius)
			tween.parallel().tween_property(sphere, "radius", r, 0.2)
		
		if torus and torus.outer_radius < max_radius:
			var tween = create_tween()
			var ri = clampf(torus.inner_radius + rate_torus, min_radius, max_radius)
			var ro = clampf(torus.outer_radius + rate_torus, min_radius, max_radius)
			tween.parallel().tween_property(torus, "inner_radius", ri, 0.2)
			tween.parallel().tween_property(torus, "outer_radius", ro, 0.2)

var next_fade = 0
func fade():
	var now = Time.get_ticks_msec()
	if now > next_fade:
		next_fade = now + 100
		
		if material and material.albedo_color.a <= 1.0:
			var t = clampf(material.albedo_color.a - rate_fade, 0.0, 1.0)
			var tween = create_tween()
			tween.parallel().tween_property(material, "albedo_color:a", t, 0.2)

func spawn_animation():
	mesh = MeshInstance3D.new()
	material = ORMMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	
	# sphere animation
	#sphere = SphereMesh.new()
	#mesh.mesh = sphere
	#sphere.radius = radius
	#sphere.height = radius*2
	#sphere.material = material
	
	# torus animation
	torus = TorusMesh.new()
	mesh.mesh = torus
	torus.inner_radius = 0.20
	torus.outer_radius = 0.30
	torus.rings = 24
	torus.ring_segments = 16
	torus.material = material
	
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.position = position
	
	get_tree().get_root().add_child(mesh)
	return await mesh_cleanup()

func mesh_cleanup():
	await get_tree().create_timer(lifetime).timeout
	if mesh: mesh.free()
	self.free()
