extends Node2D

# Minimal viewer for the BG3DWorld slab background (V5).
# Drag to pan: the 3D camera follows the 2D camera at 0.7x parallax,
# and the water-column color keys off vertical depth.

var cam: Camera2D
var dragging := false

const PAN_MIN := Vector2(0.0, 0.0)
const PAN_MAX := Vector2(2560.0, 1600.0)

func _ready() -> void:
	_build_bg3d()
	cam = Camera2D.new()
	cam.position = Vector2(1280.0, 450.0)
	add_child(cam)
	_fit_zoom()
	get_tree().root.size_changed.connect(_fit_zoom)
	_build_particles()
	cam.make_current()
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var hint := Label.new()
	hint.text = "drag to pan — vertical = depth"
	hint.position = Vector2(16, 12)
	hint.modulate = Color(1, 1, 1, 0.45)
	ui.add_child(hint)

# Fit the view width to the screen shape: the 3D ortho height is
# 720 / zoom, so pick zoom to always show ~1400 world units across.
# On landscape this is ~1.0 (the original game framing); on portrait
# phones it zooms out so the ranges read as distant silhouettes.
func _fit_zoom() -> void:
	var vs := Vector2(get_tree().root.size)
	if vs.y <= 0.0 or cam == null:
		return
	var z := 720.0 * (vs.x / vs.y) / 1400.0
	cam.zoom = Vector2(z, z)

# Soft radial sprite generated in code (no asset files needed).
func _dot_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t

var snow: CPUParticles2D

# Sparse marine snow drifting down, restored from the game build.
# The emitter follows the camera so the field covers the pan range.
func _build_particles() -> void:
	snow = CPUParticles2D.new()
	snow.amount = 120
	snow.lifetime = 14.0
	snow.preprocess = 14.0
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(800, 1600)
	snow.direction = Vector2(0, 1)
	snow.spread = 18.0
	snow.initial_velocity_min = 8.0
	snow.initial_velocity_max = 26.0
	snow.gravity = Vector2.ZERO
	snow.scale_amount_min = 0.7
	snow.scale_amount_max = 1.6
	snow.color = Color(1, 1, 1, 0.55)
	snow.texture = _dot_texture()
	add_child(snow)
func _process(_delta: float) -> void:
	if cam != null:
		if snow != null:
			snow.position = cam.position

func _build_bg3d() -> void:
	# Real 3D background behind the 2D canvas: a SubViewport with its own
	# 3D world, drawn on a canvas layer below everything 2D.
	var bg_layer := CanvasLayer.new()
	bg_layer.name = "BG3D"
	bg_layer.layer = -100
	add_child(bg_layer)
	var svc := SubViewportContainer.new()
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.stretch = false
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.handle_input_locally = false
	sv.gui_disable_input = true
	svc.add_child(sv)
	var bg3d := BG3DWorld.new()
	sv.add_child(bg3d)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		_pan(event.relative)
	elif event is InputEventScreenTouch:
		dragging = event.pressed
	elif event is InputEventScreenDrag and dragging:
		_pan(event.relative)

func _pan(relative: Vector2) -> void:
	# Drag content with the pointer: camera moves opposite.
	cam.position = (cam.position - relative / maxf(cam.zoom.x, 0.01)).clamp(PAN_MIN, PAN_MAX)
