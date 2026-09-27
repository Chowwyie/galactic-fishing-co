extends Node3D
## 3D water volume spike: Camera3D + water-sky environment + god-ray cards
## as real 3D quads + two-layer CPUParticles3D marine snow, plus the
## faceted hill cluster as the background behind the 2D play plane.

const CARD_COUNT := 24
const CARD_WRAP := 240.0
const RAY_SHADER := preload("res://shaders/ray_card_3d.gdshader")
const HILL_SCENE := preload("res://models/hill_cluster.glb")
const HILL_SHADER := preload("res://shaders/hill_facet.gdshader")

var _cam_base := Vector3(0.0, 2.0, 5.0)
var _cards_root: Node3D
var _snow_root: Node3D
var _debug_pan := false
const PAN_RANGE := 350.0
const PAN_SPEED := 60.0
# Debug camera tools (behind ?debug_pan, never part of the game).
const ZONE_MIN_X := -430.0
const ZONE_MAX_X := 438.0
const PRESET_ENTRY := -280.0
const PRESET_CENTER := 0.0
const PRESET_DEEP := 320.0
var _debug_label: Label
var _hills: Node3D
var _pan_tween: Tween

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	# Camera is locked on the single 2D play plane: straight-on, fixed.
	# Debug: ?debug_pan=1 in URL enables WASD/arrow panning (not part of game).
	_check_debug()
	camera.position = _cam_base
	_build_light()
	_build_hills()
	get_viewport().size_changed.connect(_rebuild)
	_rebuild()
	if _debug_pan:
		_build_debug_ui()


func _check_debug() -> void:
	if "--debug-pan" in OS.get_cmdline_user_args():
		_debug_pan = true
		return
	if OS.has_feature("web"):
		var win = JavaScriptBridge.get_interface("window")
		if win != null:
			var search: String = str(win.location.search)
			_debug_pan = search.contains("debug_pan")
			# ?cam_x=129 — jump the camera to an exact x for debugging
			var cx_idx := search.find("cam_x=")
			if cx_idx >= 0:
				var cx_end := search.find("&", cx_idx)
				var cx_str := search.substr(cx_idx + 6, cx_end - cx_idx - 6 if cx_end >= 0 else search.length())
				if cx_str.is_valid_float():
					_cam_base.x = clampf(cx_str.to_float(), -PAN_RANGE, PAN_RANGE)


func _process(delta: float) -> void:
	_wrap_cards()
	if not _debug_pan:
		return
	var dir := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir += 1.0
	if dir != 0.0:
		camera.position.x = clampf(camera.position.x + dir * PAN_SPEED * delta, -PAN_RANGE, PAN_RANGE)
	if _debug_label:
		var pct := (camera.position.x - ZONE_MIN_X) / (ZONE_MAX_X - ZONE_MIN_X) * 100.0
		var dtxt := "CAM x=%d y=%d %d%%" % [roundi(camera.position.x), roundi(camera.position.y), roundi(pct)]
		if _hills:
			dtxt += " | HILL d=%d" % roundi(camera.position.distance_to(_hills.global_position))
		_debug_label.text = dtxt


func _unhandled_input(event: InputEvent) -> void:
	# Touch-drag (iPhone) and mouse-drag pan: content follows the finger.
	# UI buttons consume their own touches, so drags starting on them don't pan.
	if not _debug_pan:
		return
	if event is InputEventScreenDrag:
		_pan_by_pixels((event as InputEventScreenDrag).relative.x)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_pan_by_pixels(mm.relative.x)


func _pan_by_pixels(px: float) -> void:
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 0.0:
		return
	var hw := _frustum_half_width(105.0, vp.x / vp.y)
	var wpp := hw * 2.0 / vp.x
	camera.position.x = clampf(camera.position.x - px * wpp, -PAN_RANGE, PAN_RANGE)


func _jump_to(tx: float) -> void:
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	_pan_tween = create_tween()
	_pan_tween.tween_property(camera, "position:x",
			clampf(tx, -PAN_RANGE, PAN_RANGE), 0.6)		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _copy_debug_state() -> void:
	var txt := "=== FRAME STATE ===\n"
	# Camera full state
	var cp := camera.global_position
	var cr := camera.global_rotation_degrees
	txt += "CAM pos(%.2f,%.2f,%.2f) rot(%.1f,%.1f,%.1f) fov=%.1f near=%.2f far=%.1f\n" % [cp.x, cp.y, cp.z, cr.x, cr.y, cr.z, camera.fov, camera.near, camera.far]
	var vp_size := get_viewport().get_visible_rect().size
	txt += "VIEWPORT %dx%d\n" % [int(vp_size.x), int(vp_size.y)]
	# Hill cluster transform
	if _hills:
		var hp := _hills.global_position
		var hs := _hills.global_transform.basis.get_scale()
		txt += "HILLS pos(%.2f,%.2f,%.2f) scale(%.3f,%.3f,%.3f)\n" % [hp.x, hp.y, hp.z, hs.x, hs.y, hs.z]
	# ALL meshes (not just in frustum)
	txt += "--- MESHES ---\n"
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(self, meshes)
	var idx := 0
	for m in meshes:
		if not m.mesh:
			continue
		var wp := m.global_position
		var ws := m.global_transform.basis.get_scale()
		var aabb := m.global_transform * m.get_aabb()
		var in_f := false
		for cx in [aabb.position.x, aabb.end.x]:
			for cy in [aabb.position.y, aabb.end.y]:
				for cz in [aabb.position.z, aabb.end.z]:
					if camera.is_position_in_frustum(Vector3(cx, cy, cz)):
						in_f = true
						break
				if in_f:
					break
			if in_f:
				break
		var dist := cp.distance_to(wp)
		var vis := "V" if m.visible else "H"
		# Screen rect if in frustum
		var scr := ""
		if in_f:
			var min2 := Vector2(INF, INF)
			var max2 := Vector2(-INF, -INF)
			for cx in [aabb.position.x, aabb.end.x]:
				for cy in [aabb.position.y, aabb.end.y]:
					for cz in [aabb.position.z, aabb.end.z]:
						var corner := Vector3(cx, cy, cz)
						if camera.is_position_behind(corner):
							continue
						var p2 := camera.unproject_position(corner)
						min2.x = minf(min2.x, p2.x)
						min2.y = minf(min2.y, p2.y)
						max2.x = maxf(max2.x, p2.x)
						max2.y = maxf(max2.y, p2.y)
			if min2.x <= max2.x:
				scr = " scr(%.0f,%.0f %dx%d)" % [min2.x, min2.y, int(max2.x - min2.x), int(max2.y - min2.y)]
		txt += "%d. [%s]%s pos(%.1f,%.1f,%.1f) scale(%.2f,%.2f,%.2f) aabbY[%.1f,%.1f] frustum=%s d=%.1f%s\n" % [idx, vis, m.name, wp.x, wp.y, wp.z, ws.x, ws.y, ws.z, aabb.position.y, aabb.end.y, str(in_f), dist, scr]
		idx += 1
		if idx >= 30:
			txt += "... truncated\n"
			break
	# Lights
	txt += "--- LIGHTS ---\n"
	var lights: Array[Light3D] = []
	_collect_lights(self, lights)
	for l in lights:
		var lp := l.global_position
		txt += "%s pos(%.1f,%.1f,%.1f) energy=%.2f shadow=%s\n" % [l.name, lp.x, lp.y, lp.z, l.light_energy, str(l.shadow_enabled)]
	DisplayServer.clipboard_set(txt)
	if _debug_label:
		_debug_label.text = "Copied %d meshes!" % idx


func _collect_lights(n: Node, out: Array[Light3D]) -> void:
	if n is Light3D:
		out.append(n as Light3D)
	for child in n.get_children():
		_collect_lights(child, out)


func _collect_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for child in n.get_children():
		_collect_meshes(child, out)


func _debug_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _build_debug_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DebugUI"
	add_child(layer)
	# Position readout, top-left.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _debug_bg())
	panel.position = Vector2(16, 16)
	_debug_label = Label.new()
	_debug_label.add_theme_font_size_override("font_size", 22)
	_debug_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
	panel.add_child(_debug_label)
	layer.add_child(panel)
	# Jump presets, bottom-center. Big touch targets for iPhone.
	var bar := HBoxContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -200.0
	bar.offset_right = 200.0
	bar.offset_top = -104.0
	bar.offset_bottom = -32.0
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 12)
	layer.add_child(bar)
	for preset in [["Entry", PRESET_ENTRY], ["Center", PRESET_CENTER], ["Deep", PRESET_DEEP]]:
		var b := Button.new()
		b.text = preset[0]
		b.custom_minimum_size = Vector2(112, 64)
		b.add_theme_font_size_override("font_size", 24)
		var tx: float = preset[1]
		b.pressed.connect(_jump_to.bind(tx))
		bar.add_child(b)
	var cb := Button.new()
	cb.text = "Copy"
	cb.custom_minimum_size = Vector2(112, 64)
	cb.add_theme_font_size_override("font_size", 24)
	cb.pressed.connect(_copy_debug_state)
	bar.add_child(cb)


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
	hills.position = Vector3(0.0, 10.0, -180.0)
	hills.scale = Vector3(0.35, 0.42, 0.35)
	hills.rotation.y = 0.0
	_hills = hills
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


func _wrap_cards() -> void:
	# World-space rays stay fixed in the set (correct parallax). As the camera
	# pans, cards that fall behind the wrap window recycle ahead of it, so the
	# density around the camera is constant and nothing ever pops in-frame.
	if _cards_root == null or camera == null:
		return
	var half := CARD_WRAP * 0.5
	var cx := camera.position.x
	for c in _cards_root.get_children():
		var dx: float = c.position.x - cx
		if dx < -half:
			c.position.x += CARD_WRAP
		elif dx > half:
			c.position.x -= CARD_WRAP


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
		mi.position = Vector3(rng.randf_range(-1.0, 1.0) * CARD_WRAP * 0.5, rng.randf_range(16.0, 26.0), z)
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
