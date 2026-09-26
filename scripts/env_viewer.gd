extends Node3D
# Side-view underwater environment - Dave the Diver style layered parallax
# Drag horizontally to pan (parallax layers move at different speeds)

var camera: Camera3D
var cam_x := 0.0
var dragging := false

# Parallax layers: [node, parallax_factor]
var layers: Array = []

func _ready():
	# === Environment: deep underwater blue ===
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.18, 0.35)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.20, 0.45, 0.65)
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.28, 0.48)
	env.fog_density = 0.018
	env.fog_sky_affect = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.3
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	
	# === Sun: strong light from above ===
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.1, -0.3, 0)  # mostly downward, slight angle
	sun.light_color = Color(0.65, 0.88, 1.0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	add_child(sun)
	
	# === God rays: spotlights from above ===
	for i in range(3):
		var ray := SpotLight3D.new()
		ray.position = Vector3(-20 + i * 20, 45, -10)
		ray.rotation = Vector3(-1.35, 0, 0.1 * (i - 1))
		ray.light_color = Color(0.5, 0.8, 0.95, 1.0)
		ray.light_energy = 2.5
		ray.spot_range = 80.0
		ray.spot_angle = 12.0
		add_child(ray)
	
	# === Rock material (shared) ===
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.42, 0.46, 0.50)
	rock_mat.roughness = 0.95
	
	# === Dark silhouette material (foreground) ===
	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.08, 0.12, 0.18)
	dark_mat.roughness = 1.0
	
	# === LAYERS (back to front) ===
	# Far: massive distant cliffs
	var far = _add_mesh("res://assets/environment/bg_far.obj", Vector3(0, -8, -85), rock_mat, 2.0)
	layers.append([far, 0.15])
	var far2 = _add_mesh("res://assets/environment/bg_far.obj", Vector3(60, -8, -95), rock_mat, 2.0)
	layers.append([far2, 0.12])
	var far3 = _add_mesh("res://assets/environment/bg_far.obj", Vector3(-60, -8, -95), rock_mat, 2.0)
	layers.append([far3, 0.12])
	
	# Mid: medium cliffs
	var mid = _add_mesh("res://assets/environment/bg_mid.obj", Vector3(0, -5, -40), rock_mat, 1.5)
	layers.append([mid, 0.35])
	var mid2 = _add_mesh("res://assets/environment/bg_mid.obj", Vector3(45, -5, -45), rock_mat, 1.5)
	layers.append([mid2, 0.32])
	var mid3 = _add_mesh("res://assets/environment/bg_mid.obj", Vector3(-45, -5, -45), rock_mat, 1.5)
	layers.append([mid3, 0.32])
	
	# Play area walls (full parallax = 1.0)
	var wl = _add_mesh("res://assets/environment/wall_left.obj", Vector3(-32, 0, 0), rock_mat, 1.0)
	layers.append([wl, 1.0])
	var wr = _add_mesh("res://assets/environment/wall_right.obj", Vector3(32, 0, 0), rock_mat, 1.0)
	layers.append([wr, 1.0])
	
	# Foreground: dark silhouettes at edges (move faster than camera)
	var fg_l = _add_mesh("res://assets/environment/wall_left.obj", Vector3(-22, -5, 25), dark_mat, 0.8)
	layers.append([fg_l, 1.4])
	var fg_r = _add_mesh("res://assets/environment/wall_right.obj", Vector3(22, -5, 25), dark_mat, 0.8)
	layers.append([fg_r, 1.4])
	
	# === Marine snow particles ===
	_add_particles()
	
	# === Camera: side view ===
	camera = Camera3D.new()
	camera.fov = 55.0
	camera.position = Vector3(0, 14, 55)
	camera.look_at(Vector3(0, 14, 0), Vector3.UP)
	add_child(camera)

func _add_mesh(path: String, pos: Vector3, mat: Material, scl: float) -> MeshInstance3D:
	var mesh = load(path)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = Vector3(scl, scl, scl)
	mi.material_override = mat
	add_child(mi)
	return mi

func _add_particles():
	var p := GPUParticles3D.new()
	p.amount = 300
	p.lifetime = 12.0
	p.position = Vector3(0, 15, 0)
	
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 20.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0, -0.2, 0)
	pm.scale_min = 0.05
	pm.scale_max = 0.15
	pm.color = Color(0.7, 0.85, 0.95, 0.6)
	
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	var qmat := StandardMaterial3D.new()
	qmat.albedo_color = Color(0.8, 0.9, 1.0, 0.5)
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = qmat
	
	p.process_material = pm
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(Vector3(-60, -10, -60), Vector3(120, 60, 120))
	add_child(p)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		cam_x = clamp(cam_x - event.relative.x * 0.05, -30.0, 30.0)
		_update_parallax()
	elif event is InputEventScreenTouch:
		dragging = event.pressed
	elif event is InputEventScreenDrag:
		cam_x = clamp(cam_x - event.relative.x * 0.08, -30.0, 30.0)
		_update_parallax()

func _update_parallax():
	camera.position.x = cam_x
	camera.look_at(Vector3(cam_x, 14, 0), Vector3.UP)
	# Move layers by parallax factor
	for entry in layers:
		var node: MeshInstance3D = entry[0]
		var factor: float = entry[1]
		# Store base x in metadata on first run
		if not node.has_meta("base_x"):
			node.set_meta("base_x", node.position.x)
		var base_x: float = node.get_meta("base_x")
		node.position.x = base_x + cam_x * (1.0 - factor)
