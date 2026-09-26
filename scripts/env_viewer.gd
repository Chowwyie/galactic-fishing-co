extends Node3D
# Environment viewer - loads cliffs, orbit camera with touch

var yaw := 0.0
var pitch := -0.12
var distance := 70.0
var target := Vector3(0, 15, -10)

var camera: Camera3D
var dragging := false
var touches := {}

func _ready():
	# Setup environment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.22, 0.40)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.50, 0.70)
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.30, 0.50)
	env.fog_density = 0.012
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	
	# Sun
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.6, -0.5, 0)
	sun.light_color = Color(0.75, 0.92, 1.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	
	# Rock material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.51, 0.55)
	mat.roughness = 0.95
	
	# Load cliffs
	_add_mesh("res://assets/environment/wall_left.obj", Vector3(-28, 0, 5), mat)
	_add_mesh("res://assets/environment/wall_right.obj", Vector3(28, 0, 5), mat)
	_add_mesh("res://assets/environment/bg_mid.obj", Vector3(0, 0, -35), mat)
	_add_mesh("res://assets/environment/bg_far.obj", Vector3(0, -5, -80), mat)
	
	# Camera
	camera = Camera3D.new()
	camera.fov = 60.0
	add_child(camera)
	update_camera()

func _add_mesh(path: String, pos: Vector3, mat: Material):
	var mesh = load(path)
	if mesh == null:
		push_error("Failed to load: " + path)
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	add_child(mi)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = max(25.0, distance - 6.0)
			update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = min(160.0, distance + 6.0)
			update_camera()
	elif event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.005
		pitch = clamp(pitch - event.relative.y * 0.005, -1.1, 0.6)
		update_camera()
	elif event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
	elif event is InputEventScreenDrag and touches.size() == 1:
		var prev: Vector2 = touches[event.index]
		var delta := event.position - prev
		yaw -= delta.x * 0.008
		pitch = clamp(pitch - delta.y * 0.008, -1.1, 0.6)
		update_camera()
		touches[event.index] = event.position

func update_camera():
	var off := Vector3(
		distance * cos(pitch) * sin(yaw),
		distance * sin(pitch),
		distance * cos(pitch) * cos(yaw)
	)
	camera.position = target + off
	camera.look_at(target, Vector3.UP)
