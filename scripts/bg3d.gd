class_name BG3DWorld
extends Node3D

# Real 3D background for the Sunlit Shallows: distant rock-silhouette ranges
# with genuine 3D form, a world-locked depth-darkening water gradient, and
# depth-synced atmosphere — rendered in a SubViewport on a CanvasLayer behind
# the 2D gameplay canvas.
#
# Depth model: the 3D camera follows the 2D camera at PARALLAX (< 1), so the
# far ranges drift slower than the foreground: real parallax depth. Fog color,
# ambient light, and the water gradient all key off the 2D camera's absolute
# depth, so the 3D melts into the 2D water column from surface to floor.
#
# The 2D art owns the mid/foreground (rock walls, spires, floor, actors).
# This layer is strictly the FAR environment: dark navy silhouettes.

const CAM_Z := 600.0
const PARALLAX := 0.7
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
var mat_sil_spire: StandardMaterial3D

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
	# Unshaded: far silhouettes must never catch directional light on their
	# facets (that flat-shaded CG look is what reads as "low-poly geometry"
	# next to the 2D pixel art). Fog still applies, so they melt into the
	# water column with distance.
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.roughness = 0.95
	m.metallic = 0.0
	return m

func _build_materials() -> void:
	# Distant silhouettes: dark navy, darker the farther the tier.
	mat_sil_far = _mat(Color(0.03, 0.08, 0.17))
	mat_sil_mid = _mat(Color(0.05, 0.13, 0.26))
	mat_sil_spire = _mat(Color(0.06, 0.15, 0.30))

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
			seen[key] = v + Vector3(r.randf_range(-0.28, 0.28), r.randf_range(-0.28, 0.28), r.randf_range(-0.28, 0.28))
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

func _boulder(pos: Vector3, scl: Vector3, rot: Vector3, mat: Material, variant: int) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = boulder_meshes[variant % boulder_meshes.size()]
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	mi.material_override = mat
	add_child(mi)

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
	env.fog_depth_end = 1700.0
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
	sun.light_color = Color(1.0, 0.97, 0.90)
	sun.light_energy = 0.45
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

# Sparse, deliberate composition: a few hero slabs with open water between
# them, backed by faint ridgelines. Solid rock only - no arches, no holes.
# (Rebuilt from scratch 2026-09-26; the old dense scatter is gone.)
func _build_ranges() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 20260925
	# Faintest ridgeline: wide, low, almost fully fogged.
	_place(r, -1150.0, mat_sil_far,
		[-500.0, 1000.0, 2500.0], 800.0, 1000.0, 320.0, 460.0)
	# Second ridgeline: soft mid-fog shapes.
	_place(r, -1000.0, mat_sil_far,
		[200.0, 2000.0], 600.0, 800.0, 420.0, 560.0)
	# Hero slabs: four well-separated forms, open water between each.
	_place(r, -750.0, mat_sil_mid,
		[-300.0, 800.0, 1900.0, 2900.0], 300.0, 460.0, 420.0, 760.0)
	# Two slender spire accents for vertical rhythm.
	_place(r, -620.0, mat_sil_spire,
		[1350.0, 2450.0], 90.0, 140.0, 520.0, 900.0)

func _place(r: RandomNumberGenerator, z: float, mat: Material,
		xs: Array, w_min: float, w_max: float, h_min: float, h_max: float) -> void:
	for xv in xs:
		var x := float(xv)
		var w := r.randf_range(w_min, w_max)
		var h := r.randf_range(h_min, h_max)
		var py := r.randf_range(WORLD_BOTTOM + 300.0, WORLD_TOP - 300.0)
		_boulder(
			Vector3(x + r.randf_range(-120.0, 120.0), py, z + r.randf_range(-40.0, 40.0)),
			Vector3(w, h, w * r.randf_range(0.45, 0.6)),
			Vector3(r.randf_range(-0.08, 0.08), r.randf_range(-0.3, 0.3), r.randf_range(-0.08, 0.08)),
			mat,
			r.randi() % 4)

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
	cam.size = BASE_VIEW_H / maxf(c2d.zoom.y, 0.01)
	if backdrop != null:
		backdrop.position = Vector3(cam.position.x, cam.position.y, -1350.0)
		backdrop_mat.set_shader_parameter("cam_y", cam.position.y)
	# Melt the 3D into the water column at the camera's absolute depth.
	var water := _water_color(center.y)
	env.fog_light_color = water * 0.92
	env.ambient_light_color = water * 1.05
	env.background_color = water
