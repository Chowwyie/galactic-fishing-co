class_name BG3DWorld
extends Node3D

# Real 3D background for the Sunlit Shallows: low-poly rock formations,
# 3D corals/sponges, dune-displaced sandy floor, one directional "sun"
# light, depth fog. Rendered in a SubViewport on a CanvasLayer behind
# the 2D gameplay canvas.
#
# Coordinate mapping: 3D (x, -y) == 2D world (x, y). Orthographic camera
# at Z=600 tracks the 2D Camera2D 1:1, so the 3D world lines up exactly
# with the 2D gameplay plane.

const CAM_Z := 600.0
const BASE_VIEW_H := 720.0 # 2D viewport height at zoom 1

var cam: Camera3D
var viewport: SubViewport

var box_mesh: BoxMesh
var tube_mesh: CylinderMesh
var cone_mesh: CylinderMesh

var mat_rock_near: StandardMaterial3D
var mat_rock_mid: StandardMaterial3D
var mat_rock_far: StandardMaterial3D
var mat_wall: StandardMaterial3D
var mat_sand: StandardMaterial3D
var mat_coral: StandardMaterial3D
var mat_sponge: StandardMaterial3D
var mat_anemone: StandardMaterial3D

func _ready() -> void:
	viewport = get_viewport() as SubViewport
	box_mesh = BoxMesh.new()
	box_mesh.size = Vector3.ONE
	tube_mesh = CylinderMesh.new()
	tube_mesh.radial_segments = 7
	tube_mesh.top_radius = 0.55
	tube_mesh.bottom_radius = 0.7
	tube_mesh.height = 1.0
	cone_mesh = CylinderMesh.new()
	cone_mesh.radial_segments = 7
	cone_mesh.top_radius = 0.08
	cone_mesh.bottom_radius = 0.6
	cone_mesh.height = 1.0
	_build_materials()
	_build_environment()
	_build_light()
	_build_camera()
	_build_floor()
	_build_rock_bands()
	_build_distant_wall()
	_build_corals()
	_sync_viewport_size()
	get_tree().root.size_changed.connect(_sync_viewport_size)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	m.metallic = 0.0
	return m

func _build_materials() -> void:
	mat_rock_near = _mat(Color(0.30, 0.44, 0.58))
	mat_rock_mid = _mat(Color(0.33, 0.49, 0.64))
	mat_rock_far = _mat(Color(0.36, 0.53, 0.69))
	mat_wall = _mat(Color(0.10, 0.23, 0.40))
	mat_sand = _mat(Color(0.72, 0.68, 0.52))
	mat_coral = _mat(Color(0.95, 0.45, 0.55))
	mat_sponge = _mat(Color(0.25, 0.75, 0.70))
	mat_anemone = _mat(Color(1.00, 0.62, 0.30))

func _build_environment() -> void:
	# Flat background color; the water-column gradient is a giant unshaded
	# quad pinned to the camera. (Sky shaders sample EYEDIR per-pixel, which
	# produces a radial artifact under an orthographic camera.)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.42, 0.62)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.38, 0.58, 0.72)
	e.ambient_light_energy = 0.85
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = Color(0.22, 0.50, 0.68)
	e.fog_light_energy = 1.0
	e.fog_depth_begin = 720.0
	e.fog_depth_end = 1560.0
	e.fog_depth_curve = 1.0
	we.environment = e
	add_child(we)
	_build_backdrop()

# Giant gradient quad that follows the camera: the water column itself.
# Unshaded + fog-disabled, with the gradient locked to screen space.
const BACKDROP_W := 4200.0
const BACKDROP_H := 1700.0
var backdrop: MeshInstance3D

func _build_backdrop() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(BACKDROP_W, BACKDROP_H)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type spatial;\n" + \
		"render_mode unshaded, fog_disabled, cull_disabled;\n" + \
		"uniform vec3 top_color : source_color = vec3(0.55, 0.88, 0.95);\n" + \
		"uniform vec3 horizon_color : source_color = vec3(0.30, 0.62, 0.80);\n" + \
		"uniform vec3 bottom_color : source_color = vec3(0.02, 0.10, 0.22);\n" + \
		"uniform float view_h = 720.0;\n" + \
		"uniform float quad_h = 1700.0;\n" + \
		"void fragment() {\n" + \
		"\tfloat up = (0.5 - UV.y) * quad_h / view_h;\n" + \
		"\tvec3 col;\n" + \
		"\tif (up >= 0.0) {\n" + \
		"\t\tcol = mix(horizon_color, top_color, pow(clamp(up * 2.0, 0.0, 1.0), 0.6));\n" + \
		"\t} else {\n" + \
		"\t\tcol = mix(horizon_color, bottom_color, pow(clamp(-up * 2.0, 0.0, 1.0), 0.5));\n" + \
		"\t}\n" + \
		"\tALBEDO = col;\n" + \
		"}\n"
	sm.shader = sh
	backdrop = MeshInstance3D.new()
	backdrop.mesh = quad
	backdrop.material_override = sm
	backdrop.position = Vector3(1280, -300, -1350)
	add_child(backdrop)

func _build_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_color = Color(1.0, 0.97, 0.90)
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	add_child(sun)

func _build_camera() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = BASE_VIEW_H
	cam.near = 10.0
	cam.far = 3000.0
	cam.position = Vector3(1280, -300, CAM_Z)
	cam.current = true
	add_child(cam)

func _sync_viewport_size() -> void:
	if viewport != null:
		viewport.size = Vector2i(get_tree().root.size)

func _box(pos: Vector3, scl: Vector3, rot: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	mi.material_override = mat
	add_child(mi)

func _build_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(4200, 1000)
	plane.subdivide_width = 72
	plane.subdivide_depth = 20
	var arrays := plane.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		var v := verts[i]
		verts[i].y = 26.0 * sin(v.x * 0.008) * cos(v.z * 0.02) + 10.0 * sin(v.x * 0.03 + 1.7)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat_sand
	mi.position = Vector3(1280, -1562, -260)
	add_child(mi)

func _rock_cluster(cx: float, cy: float, cz: float, base: float, n: int, spread: float, rise: float, mat: Material, salt: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 1000 + salt
	for i in n:
		var s := base * r.randf_range(0.45, 1.25)
		_box(
			Vector3(cx + r.randf_range(-spread, spread), cy + r.randf_range(0.0, rise), cz + r.randf_range(-40.0, 40.0)),
			Vector3(s * r.randf_range(0.7, 1.5), s * r.randf_range(0.6, 1.3), s * r.randf_range(0.5, 1.0)),
			Vector3(r.randf_range(-0.35, 0.35), r.randf_range(-0.7, 0.7), r.randf_range(-0.35, 0.35)),
			mat)

func _build_rock_bands() -> void:
	# near band: chunky, darker — frames the gameplay plane
	var xs := [-120.0, 260.0, 640.0, 1020.0, 1400.0, 1780.0, 2160.0, 2540.0, 2700.0]
	var salt := 0
	for x in xs:
		_rock_cluster(x, -1560.0, -100.0, 95.0, 6, 150.0, 130.0, mat_rock_near, salt)
		salt += 1
	# mid band: bigger formations further back
	for x in [-80.0, 340.0, 760.0, 1180.0, 1600.0, 2020.0, 2440.0, 2680.0]:
		_rock_cluster(x, -1560.0, -300.0, 150.0, 6, 190.0, 260.0, mat_rock_mid, salt)
		salt += 1
	# far band: tall, fog-hazed
	for x in [0.0, 430.0, 860.0, 1290.0, 1720.0, 2150.0, 2580.0]:
		_rock_cluster(x, -1560.0, -520.0, 210.0, 5, 230.0, 520.0, mat_rock_far, salt)
		salt += 1
	# a few mid-water pillars for vertical interest
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for i in 4:
		var px: float = [-140.0, 420.0, 2140.0, 2700.0][i]
		_box(Vector3(px, -950.0, -350.0),
			Vector3(r.randf_range(70, 110), r.randf_range(380, 560), r.randf_range(60, 100)),
			Vector3(r.randf_range(-0.12, 0.12), r.randf_range(-0.4, 0.4), r.randf_range(-0.1, 0.1)),
			mat_rock_mid)

func _build_distant_wall() -> void:
	# dark silhouette canyon walls far behind everything
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	var x := -500.0
	var salt := 9000
	while x < 3100.0:
		var w := r.randf_range(280.0, 520.0)
		var h := r.randf_range(500.0, 850.0)
		_box(Vector3(x + w * 0.5, -1560.0 + h * 0.5, -850.0 + r.randf_range(-60.0, 60.0)),
			Vector3(w, h, r.randf_range(120.0, 220.0)),
			Vector3(0, r.randf_range(-0.25, 0.25), 0),
			mat_wall)
		x += w * r.randf_range(0.55, 0.8)
		salt += 1

func _build_corals() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 31337
	# pink branching corals: stem + branches
	for i in 9:
		var cx := r.randf_range(60.0, 2500.0)
		var cz := r.randf_range(-110.0, -40.0)
		var h := r.randf_range(50.0, 95.0)
		_box(Vector3(cx, -1560.0 + h * 0.5, cz), Vector3(9, h, 9), Vector3.ZERO, mat_coral)
		for b in 3:
			var ba := r.randf_range(-0.9, 0.9)
			var bl := h * r.randf_range(0.35, 0.55)
			var by := -1560.0 + h * r.randf_range(0.45, 0.85)
			var br := MeshInstance3D.new()
			br.mesh = box_mesh
			br.material_override = mat_coral
			br.scale = Vector3(6, bl, 6)
			br.position = Vector3(cx + sin(ba) * bl * 0.4, by, cz)
			br.rotation = Vector3(0, 0, ba)
			add_child(br)
	# teal tube sponges
	for i in 9:
		var cx2 := r.randf_range(60.0, 2500.0)
		var cz2 := r.randf_range(-110.0, -40.0)
		for t in int(r.randf_range(2.0, 4.0)):
			var th := r.randf_range(35.0, 80.0)
			var tr := r.randf_range(9.0, 16.0)
			var tm := MeshInstance3D.new()
			tm.mesh = tube_mesh
			tm.material_override = mat_sponge
			tm.scale = Vector3(tr * 2.0, th, tr * 2.0)
			tm.position = Vector3(cx2 + r.randf_range(-22.0, 22.0), -1560.0 + th * 0.5, cz2 + r.randf_range(-14.0, 14.0))
			add_child(tm)
	# orange anemone cones
	for i in 7:
		var ah := r.randf_range(22.0, 40.0)
		var am := MeshInstance3D.new()
		am.mesh = cone_mesh
		am.material_override = mat_anemone
		am.scale = Vector3(44, ah, 44)
		am.position = Vector3(r.randf_range(60.0, 2500.0), -1560.0 + ah * 0.5, r.randf_range(-110.0, -40.0))
		add_child(am)

func _process(_delta: float) -> void:
	var c2d := get_tree().root.get_camera_2d()
	if c2d == null or cam == null:
		return
	var center := c2d.get_screen_center_position()
	cam.position = Vector3(center.x, -center.y, CAM_Z)
	cam.size = BASE_VIEW_H / maxf(c2d.zoom.y, 0.01)
	if backdrop != null:
		backdrop.position = Vector3(cam.position.x, cam.position.y, -1350.0)
