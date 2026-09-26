extends Node3D
## 3D water volume spike: Camera3D + water-sky environment + god-ray cards
## as real 3D quads + two-layer CPUParticles3D marine snow. No set pieces.

const CARD_COUNT := 8
const RAY_SHADER := preload("res://shaders/ray_card_3d.gdshader")

var _t := 0.0
var _cam_base := Vector3(0.0, 2.0, 5.0)
var _cards_root: Node3D
var _snow_root: Node3D

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_build_light()
	get_viewport().size_changed.connect(_rebuild)
	_rebuild()


func _process(delta: float) -> void:
	_t += delta
	# Barely-there drift so the cards show parallax against the water.
	camera.position = _cam_base + Vector3(sin(_t * 0.05) * 1.5, sin(_t * 0.037 + 1.3) * 1.0, 0.0)


func _build_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-75.0, 20.0, 0.0)
	sun.light_color = Color(0.9, 0.97, 1.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = false
	add_child(sun)


func _rebuild() -> void:
	_clear(_cards_root)
	_clear(_snow_root)
	_build_cards()
	_build_snow()


func _clear(node: Node) -> void:
	if is_instance_valid(node):
		remove_child(node)
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
	_snow_root = Node3D.new()
	_snow_root.name = "Snow"
	add_child(_snow_root)
	var hw := _frustum_half_width(50.0, _viewport_aspect())
	_make_snow_layer(320, 0.12, 0.7, 1.4, 0.5, hw)
	_make_snow_layer(40, 0.35, 0.8, 1.3, 0.65, hw)


func _make_snow_layer(amount: int, mesh_size: float, s_min: float, s_max: float, alpha: float, hw: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 30.0
	p.preprocess = 30.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(hw * 1.05, 26.0, 30.0)
	p.position = Vector3(0.0, 4.0, -45.0)
	p.direction = Vector3(0.0, -1.0, 0.0)
	p.spread = 10.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = s_min
	p.scale_amount_max = s_max
	var quad := QuadMesh.new()
	quad.size = Vector2(mesh_size, mesh_size)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bm.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	quad.material = bm
	p.mesh = quad
	# Fade in/out over lifetime so motes never pop inside the volume.
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	grad.add_point(0.12, Color(1.0, 1.0, 1.0, alpha))
	grad.add_point(0.88, Color(1.0, 1.0, 1.0, alpha))
	p.color_ramp = grad
	p.visibility_aabb = AABB(Vector3(-80.0, -40.0, -110.0), Vector3(160.0, 130.0, 130.0))
	_snow_root.add_child(p)
