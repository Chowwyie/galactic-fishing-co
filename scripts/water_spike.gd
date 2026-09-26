extends Control
## Water spike: Beer-Lambert water shader (procedural god rays) +
## two-layer marine snow, emitted above the screen, drifting through.

var snow_far: CPUParticles2D
var snow_near: CPUParticles2D
var _far_vmin := 6.0
var _near_vmin := 4.0


func _ready() -> void:
	snow_far = $Snow
	_setup_layer(snow_far, 130, 0.5, 1.0, 0.40, _far_vmin, 18.0)
	snow_near = CPUParticles2D.new()
	add_child(snow_near)
	_setup_layer(snow_near, 28, 1.6, 2.8, 0.60, _near_vmin, 12.0)
	get_tree().root.size_changed.connect(_fit_snow)
	_fit_snow()


func _setup_layer(p: CPUParticles2D, amount: int, s_min: float, s_max: float, alpha: float, v_min: float, v_max: float) -> void:
	p.amount = amount
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
	_place_layer(snow_far, vs, _far_vmin)
	_place_layer(snow_near, vs, _near_vmin)


func _place_layer(p: CPUParticles2D, vs: Vector2, v_min: float) -> void:
	var life := (vs.y + 240.0) / v_min
	p.lifetime = life
	p.preprocess = life
	p.position = Vector2(vs.x * 0.5, -30.0)
	p.emission_rect_extents = Vector2(vs.x * 0.5, 10.0)
	p.restart()


func _mote_texture() -> Texture2D:
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)
