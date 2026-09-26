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
	cam.position = Vector2(1280.0, 300.0)
	add_child(cam)
	cam.make_current()
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var hint := Label.new()
	hint.text = "drag to pan — vertical = depth"
	hint.position = Vector2(16, 12)
	hint.modulate = Color(1, 1, 1, 0.45)
	ui.add_child(hint)

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
