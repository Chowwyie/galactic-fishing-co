extends Node3D
## 3D water volume spike: Camera3D + water-sky environment + god-ray cards
## as real 3D quads + two-layer CPUParticles3D marine snow, plus the
## faceted hill cluster as the background behind the 2D play plane.

const CARD_COUNT := 8
const RAY_SHADER := preload("res://shaders/ray_card_3d.gdshader")
const HILL_SCENE := preload("res://models/hill_cluster.glb")
const HILL_SHADER := preload("res://shaders/hill_facet.gdshader")

var _cam_base := Vector3(0.0, 2.0, 5.0)
var _cards_root: Node3D
var _snow_root: Node3D

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	# Camera is locked on the single 2D play plane: straight-on, fixed.
	camera.position = _cam_base
	_build_light()
	_build_hills()
	get_viewport().size_changed.connect(_rebuild)
	_rebuild()


func _build_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-75.0, 20.0, 0.0)
	sun.light_color = Color(0.9, 0.97, 1.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = false
	add_child(sun)


func _build_hills() -> void:
	# Background set: the hill cluster sits behind the 2D play plane,
	# massive in frame. The camera stays locked on the play plane; the hills
	# are dressed with the faceted 3-step toon ramp so every facet reads as
	# one flat color cell against the pixel-art foreground.
	var hills: Node3D = HILL_SCENE.instantiate()
	hills.name = "HillCluster"
	# Backdrop framing: the range is squashed in depth into a shallow frieze
	# behind the play plane, cropped by the fixed camera so the hero hill is
	# colossal in frame. Camera stays locked on the 2D play plane.
	hills.position = Vector3(0.0, 10.0, -80.0)
	hills.scale = Vector3(0.35, 0.35, 0.35)
	hills.rotation.y = 0.0
	add_child(hills)
	var mat := ShaderMaterial.new()
	mat.shader = HILL_SHADER
	for mi in hills.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat


func _rebuild() -> void:
	_clear(_cards_root)
	_clear(_snow_root)
	_build_cards()
	_build_snow()


func _clear(node: Node) -> void:
	if is_instance_valid(node) and is_instance_valid(node.get_parent()):
		node.get_parent().remove_child(node)
		node.free()


func _viewport_aspect() -> float:
	return get_viewport().get_visible_rect().size.aspect()


func _frustum_half_width(dist: float, aspect: float) -> float:
	return dist * tan(deg_to_rad(camera.fov * 0.5)) * aspect


func _build_cards() -> void:
	_cards_root = Node3D.new()
	_cards_root.name = "RayCards"
	add_child(_cards_root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260926
	var aspect := _viewport_aspect()
	for i in CARD_COUNT:
		var z := -lerpf(28.0, 70.0, float(i) / float(CARD_COUNT - 1)) + rng.randf_range(-4.0, 4.0)
		var dist := -z + 5.0
		var hw := _frustum_half_width(dist, aspect)
		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(rng.randf_range(4.0, 9.0), rng.randf_range(70.0, 85.0))
		mi.mesh = quad
		var mat := ShaderMaterial.new()
		mat.shader = RAY_SHADER
		mat.set_shader_parameter("intensity", rng.randf_range(0.35, 0.6) * exp(-dist * 0.008))
		mat.set_shader_parameter("seed", rng.randf() * 100.0)
		mi.material_override = mat
		# Tall enough that the top is always above the frame: shafts emerge
		# from the bright surface water, never from a visible edge.
		mi.position = Vector3(rng.randf_range(-0.85, 0.85) * hw, rng.randf_range(16.0, 26.0), z)
		mi.rotation.z = deg_to_rad(10.0)
		_cards_root.add_child(mi)


func _build_snow() -> void:
	# Emitter holder tilted 30 deg (half the camera FOV) so its local X/Z plane
	# rides exactly on the frustum top plane: local +y is the above-frame
	# direction, local -z runs away from the camera along the top of the view.
	# Motes spawn in a thin strip just above the frame and fall through it, so
	# nothing ever spawns or dies inside the visible volume. Parented to the
	# camera (fixed, no drift).
	_snow_root = Node3D.new()
	_snow_root.name = "Snow"
	_snow_root.rotation.x = deg_to_rad(30.0)
	camera.add_child(_snow_root)
	var aspect := _viewport_aspect()
	var xw_near := _frustum_half_width(34.0, aspect)
	var xw_far := _frustum_half_width(64.0, aspect)
	_make_snow_band(140, 0.12, 0.7, 1.4, 0.5, -27.5, 12.5, xw_near)
	_make_snow_band(360, 0.12, 0.7, 1.4, 0.5, -57.5, 17.5, xw_far)
	_make_snow_band(18, 0.35, 0.8, 1.3, 0.65, -27.5, 12.5, xw_near)
	_make_snow_band(46, 0.35, 0.8, 1.3, 0.65, -57.5, 17.5, xw_far)


func _make_snow_band(amount: int, mesh_size: float, s_min: float, s_max: float,
		alpha: float, zc: float, z_half: float, x_hw: float) -> void:
	var q := CPUParticles3D.new()
	q.amount = amount
	q.lifetime = 105.0
	q.preprocess = 105.0
	q.local_coords = false
	q.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	q.emission_box_extents = Vector3(x_hw * 1.05, 1.0, z_half)
	q.position = Vector3(0.0, 2.0, zc)
	# SnowTilt-space vector that maps to world straight-down.
	q.direction = Vector3(0.0, -0.866, 0.5)
	q.spread = 10.0
	q.initial_velocity_min = 0.8
	q.initial_velocity_max = 2.0
	q.gravity = Vector3.ZERO
	q.scale_amount_min = s_min
	q.scale_amount_max = s_max
	var quad := QuadMesh.new()
	quad.size = Vector2(mesh_size, mesh_size)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bm.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	quad.material = bm
	q.mesh = quad
	# Safety-net fade; spawn and death both happen off-screen now.
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	grad.add_point(0.12, Color(1.0, 1.0, 1.0, alpha))
	grad.add_point(0.88, Color(1.0, 1.0, 1.0, alpha))
	q.color_ramp = grad
	q.visibility_aabb = AABB(Vector3(-90.0, -60.0, -120.0), Vector3(180.0, 170.0, 150.0))
	_snow_root.add_child(q)
