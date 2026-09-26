extends Control
## Water spike: fullscreen shader water + square marine snow.
## No camera, no 3D set yet — that comes next.

@onready var snow: CPUParticles2D = $Snow


func _ready() -> void:
	_build_snow()
	get_tree().root.size_changed.connect(_fit_snow)
	_fit_snow()


func _build_snow() -> void:
	snow.amount = 150
	snow.lifetime = 12.0
	snow.preprocess = 12.0
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.direction = Vector2(0, 1)
	snow.spread = 12.0
	snow.initial_velocity_min = 6.0
	snow.initial_velocity_max = 18.0
	snow.gravity = Vector2.ZERO
	snow.scale_amount_min = 0.6
	snow.scale_amount_max = 1.4
	snow.color = Color(1, 1, 1, 0.5)
	snow.texture = _mote_texture()


func _fit_snow() -> void:
	var vs := get_viewport_rect().size
	snow.position = vs * 0.5
	snow.emission_rect_extents = vs * 0.5


func _mote_texture() -> Texture2D:
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)
