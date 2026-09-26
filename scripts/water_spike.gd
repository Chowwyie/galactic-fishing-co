extends Control
## Water spike v2: Beer-Lambert water shader + two-layer marine snow
## (many tiny far motes, few large near motes). No 3D set yet.

var snow_far: CPUParticles2D
var snow_near: CPUParticles2D


func _ready() -> void:
	snow_far = $Snow
	_setup_layer(snow_far, 130, 0.5, 1.0, 0.40, 6.0, 18.0)
	snow_near = CPUParticles2D.new()
	add_child(snow_near)
	_setup_layer(snow_near, 28, 1.6, 2.8, 0.60, 4.0, 12.0)
	get_tree().root.size_changed.connect(_fit_snow)
	_fit_snow()


func _setup_layer(p: CPUParticles2D, amount: int, s_min: float, s_max: float, alpha: float, v_min: float, v_max: float) -> void:
	p.amount = amount
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(0, 1)
	p.spread = 12.0
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = Vector2.ZERO
	p.scale_amount_min = s_min
	p.scale_amount_max = s_max
	p.color = Color(1, 1, 1, alpha)
	p.texture = _mote_texture()


func _fit_snow() -> void:
	var vs := get_viewport_rect().size
	for p in [snow_far, snow_near]:
		p.position = vs * 0.5
		p.emission_rect_extents = vs * 0.5


func _mote_texture() -> Texture2D:
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)
