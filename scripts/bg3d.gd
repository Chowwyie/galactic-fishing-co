class_name BG3DWorld
extends Node3D

# 3D background for the viewer: a few rock slabs on three depth planes with
# real differential parallax, a world-locked depth-darkening water gradient,
# and depth-synced atmosphere - rendered in a SubViewport on a CanvasLayer.
#
# Depth model: dark detailed foreground gateways near the camera, mid slabs
# floating in open water, pale far shapes. Each plane follows the 2D pan at
# its own rate (1.0 / 0.7 / 0.4), so the planes drift against each other.
# Fog color, ambient light, and the water gradient all key off the 2D
# camera depth, so the 3D melts into the water column.

const CAM_Z := 600.0
const PARALLAX := 0.7
const F_FORE := 1.0
const F_MID := 0.7
const F_BACK := 0.4
const BASE_VIEW_H := 720.0 # 2D viewport height at zoom 1
const WORLD_TOP := 400.0 # 3D y of content top (positive = above the surface)
const WORLD_BOTTOM := -1800.0 # 3D y of content bottom
const DEPTH_MAX := 1600.0 # 2D y at which the water reaches full deep color

# Water column stops (2D y: 0 = surface, DEPTH_MAX = abyss).
const COL_TOP := Color(0.42, 0.78, 0.90)
const COL_MID := Color(0.10, 0.34, 0.55)
const COL_BOT := Color(0.01, 0.06, 0.14)

var cam: Camera3D
var viewport: SubViewport
var env: Environment
var backdrop_mat: ShaderMaterial
var backdrop: MeshInstance3D

var box_mesh: BoxMesh
var boulder_meshes: Array[ArrayMesh] = []

var mat_sil_far: StandardMaterial3D
var mat_sil_mid: StandardMaterial3D
var mat_sil_fore: StandardMaterial3D
var layer_fore: Node3D
var layer_mid: Node3D
var layer_back: Node3D

func _ready() -> void:
	viewport = get_viewport() as SubViewport
	box_mesh = BoxMesh.new()
	box_mesh.size = Vector3.ONE
	_build_materials()
	_build_boulders()
	_build_environment()
	_build_backdrop()
	_build_light()
	_build_camera()
	_build_ranges()
	_sync_viewport_size()
	get_tree().root.size_changed.connect(_sync_viewport_size)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	# Shaded: the boulders carry flat face normals, so the directional light
	# shades each facet. That lit/unlit facet variation IS the rock detail.
	# Fog still applies, so they melt into the water column with distance.
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.roughness = 0.95
	m.metallic = 0.0
	return m

func _build_materials() -> void:
	# Rock tiers: dark navy, darker when nearer the camera.
	mat_sil_fore = _mat(Color(0.05, 0.10, 0.22))
	mat_sil_mid = _mat(Color(0.05, 0.13, 0.26))
	mat_sil_far = _mat(Color(0.10, 0.18, 0.33))

# Irregular faceted boulders: a subdivided box with seeded vertex jitter and
# flat face normals. Reads as rock, not glass cubes.
func _build_boulders() -> void:
	for i in 4:
		boulder_meshes.append(_make_boulder(5000 + i * 131))

func _make_boulder(salt: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = salt
	var bm := BoxMesh.new()
	bm.subdivide_width = 3
	bm.subdivide_height = 3
	bm.subdivide_depth = 3
	bm.size = Vector3.ONE
	var src := ArrayMesh.new()
	src.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bm.surface_get_arrays(0))
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(src, 0)
	var seen := {}
	for i in mdt.get_vertex_count():
		var v := mdt.get_vertex(i)
		var key := "%0.2f|%0.2f|%0.2f" % [v.x, v.y, v.z]
		if not seen.has(key):
			seen[key] = v + Vector3(r.randf_range(-0.16, 0.16), r.randf_range(-0.16, 0.16), r.randf_range(-0.16, 0.16))
		mdt.set_vertex(i, seen[key])
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for f in mdt.get_face_count():
		var a := mdt.get_vertex(mdt.get_face_vertex(f, 0))
		var b := mdt.get_vertex(mdt.get_face_vertex(f, 1))
		var c := mdt.get_vertex(mdt.get_face_vertex(f, 2))
		var n := (b - a).cross(c - a)
		if n.length() < 0.00001:
			continue
		n = n.normalized()
		verts.append_array(PackedVector3Array([a, b, c]))
		normals.append_array(PackedVector3Array([n, n, n]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out

func _boulder(parent: Node3D, pos: Vector3, scl: Vector3, rot: Vector3, mat: Material, variant: int) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = boulder_meshes[variant % boulder_meshes.size()]
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = COL_MID
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = COL_MID * 1.1
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = COL_MID * 0.9
	env.fog_light_energy = 1.0
	env.fog_depth_begin = 700.0
	env.fog_depth_end = 2000.0
	env.fog_depth_curve = 1.0
	we.environment = env
	add_child(we)

# Water column: a giant unshaded quad that follows the camera. The gradient is
# WORLD-locked (computed from each pixel's absolute depth), so the water
# genuinely darkens as the player dives. Fog-disabled: it IS the background.
const BACKDROP_W := 4200.0
const BACKDROP_H := 2400.0

func _build_backdrop() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(BACKDROP_W, BACKDROP_H)
	backdrop_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type spatial;\n" + \
		"render_mode unshaded, fog_disabled, cull_disabled;\n" + \
		"uniform vec3 col_top : source_color = vec3(0.42, 0.78, 0.90);\n" + \
		"uniform vec3 col_mid : source_color = vec3(0.10, 0.34, 0.55);\n" + \
		"uniform vec3 col_bot : source_color = vec3(0.01, 0.06, 0.14);\n" + \
		"uniform float cam_y = -300.0;\n" + \
		"uniform float quad_h = 2400.0;\n" + \
		"uniform float depth_max = 1600.0;\n" + \
		"void fragment() {\n" + \
		"\tfloat world_y = cam_y + (0.5 - UV.y) * quad_h;\n" + \
		"\tfloat d = clamp(-world_y / depth_max, 0.0, 1.0);\n" + \
		"\tvec3 col;\n" + \
		"\tif (d < 0.45) {\n" + \
		"\t\tcol = mix(col_top, col_mid, pow(d / 0.45, 0.7));\n" + \
		"\t} else {\n" + \
		"\t\tcol = mix(col_mid, col_bot, pow((d - 0.45) / 0.55, 0.8));\n" + \
		"\t}\n" + \
		"\tALBEDO = col;\n" + \
		"}\n"
	backdrop_mat.shader = sh
	backdrop = MeshInstance3D.new()
	backdrop.mesh = quad
	backdrop.material_override = backdrop_mat
	backdrop.position = Vector3(1280, -300, -1350)
	add_child(backdrop)

func _build_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_color = Color(0.90, 0.95, 1.0)
	sun.light_energy = 0.7
	sun.shadow_enabled = false
	add_child(sun)

func _build_camera() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = BASE_VIEW_H
	cam.near = 10.0
	cam.far = 3000.0
	cam.position = Vector3(1280 * PARALLAX, -300 * PARALLAX, CAM_Z)
	cam.current = true
	add_child(cam)

func _sync_viewport_size() -> void:
	if viewport != null:
		viewport.size = Vector2i(get_tree().root.size)

# Three-plane parallax composition (rebuilt 2026-09-26 from the reference
# shot): dark detailed foreground gateways framing the view, a couple of mid
# slabs floating in open water, pale far shapes low in frame. Each plane lives
# under its own container so panning produces real differential parallax.
func _build_ranges() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 20260926
	layer_fore = _make_layer("Fore")
	layer_mid = _make_layer("Mid")
	layer_back = _make_layer("Back")
	# Foreground gateways: tall dark masses at the frame edges, center open.
	_place(r, layer_fore, -150.0, mat_sil_fore, [600.0, 1950.0], 440.0, 520.0, 3200.0, 3600.0, -450.0, 150.0)
	# Mid slabs: a couple of forms in open water.
	_place(r, layer_mid, -600.0, mat_sil_mid, [750.0, 1300.0], 450.0, 560.0, 480.0, 660.0, -350.0, 100.0)
	# Background: pale faint shapes, low in frame.
	_place(r, layer_back, -1000.0, mat_sil_far, [950.0, 1650.0], 650.0, 800.0, 350.0, 450.0, 700.0, 250.0)

func _make_layer(layer_name: String) -> Node3D:
	var l := Node3D.new()
	l.name = layer_name
	add_child(l)
	return l

func _place(r: RandomNumberGenerator, layer: Node3D, z: float, mat: Material, xs: Array, w_min: float, w_max: float, h_min: float, h_max: float, y_center: float, y_jit: float) -> void:
	for xv in xs:
		var x := float(xv)
		var w := r.randf_range(w_min, w_max)
		var h := r.randf_range(h_min, h_max)
		_boulder(layer, Vector3(x + r.randf_range(-100.0, 100.0), y_center + r.randf_range(-y_jit, y_jit), z + r.randf_range(-30.0, 30.0)), Vector3(w, h, w * r.randf_range(0.5, 0.65)), Vector3(r.randf_range(-0.06, 0.06), r.randf_range(-0.25, 0.25), r.randf_range(-0.06, 0.06)), mat, r.randi() % 4)

# GDScript mirror of the water ramp, for syncing fog/ambient to camera depth.
func _water_color(depth2d: float) -> Color:
	var d := clampf(depth2d / DEPTH_MAX, 0.0, 1.0)
	if d < 0.45:
		return COL_TOP.lerp(COL_MID, pow(d / 0.45, 0.7))
	return COL_MID.lerp(COL_BOT, pow((d - 0.45) / 0.55, 0.8))

func _process(_delta: float) -> void:
	var c2d := get_tree().root.get_camera_2d()
	if c2d == null or cam == null:
		return
	var center := c2d.get_screen_center_position()
	cam.position = Vector3(center.x * PARALLAX, -center.y * PARALLAX, CAM_Z)
	_shift_layer(layer_fore, F_FORE, center)
	_shift_layer(layer_mid, F_MID, center)
	_shift_layer(layer_back, F_BACK, center)
	cam.size = BASE_VIEW_H / maxf(c2d.zoom.y, 0.01)
	if backdrop != null:
		backdrop.position = Vector3(cam.position.x, cam.position.y, -1350.0)
		backdrop_mat.set_shader_parameter("cam_y", cam.position.y)
	# Melt the 3D into the water column at the camera's absolute depth.
	var water := _water_color(center.y)
	env.fog_light_color = water * 0.92
	env.ambient_light_color = water * 1.05
	env.background_color = water

# Differential parallax: each rock plane drifts at its own rate against the
# 2D pan, so foreground gateways sweep past while far shapes barely move.
func _shift_layer(layer: Node3D, f: float, center: Vector2) -> void:
	if layer != null:
		layer.position = Vector3(center.x * (PARALLAX - f), center.y * (f - PARALLAX), 0.0)
