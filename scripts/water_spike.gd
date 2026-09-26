extends Control
## Water spike v3: Beer-Lambert water + textured god-ray cards
## (additive planes, drifting slowly) + two-layer marine snow.

const RAY_COUNT := 6

var snow_far: CPUParticles2D
var snow_near: CPUParticles2D
var _far_vmin := 6.0
var _near_vmin := 4.0
var _rays_layer: Control
var _cards: Array = []
var _shaft_tex: Texture2D
var _ray_shader: Shader


func _ready() -> void:
	_shaft_tex = _make_shaft_texture()
	_ray_shader = load("res://shaders/god_ray.gdshader") as Shader
	_rays_layer = Control.new()
	_rays_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rays_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rays_layer)
	move_child(_rays_layer, 1)
	snow_far = $Snow
	_setup_layer(snow_far, 130, 0.5, 1.0, 0.40, _far_vmin, 18.0)
	snow_near = CPUParticles2D.new()
	add_child(snow_near)
	_setup_layer(snow_near, 28, 1.6, 2.8, 0.60, _near_vmin, 12.0)
	get_tree().root.size_changed.connect(_fit_all)
	_fit_all()


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for c in _cards:
		var n := c["node"] as TextureRect
		n.position.x = float(c["base_x"]) + sin(t * float(c["speed"]) + float(c["phase"])) * float(c["amp"])


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


func _fit_all() -> void:
	_fit_snow()
	_fit_rays()


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


func _fit_rays() -> void:
	var vs := get_viewport_rect().size
	for c in _cards:
		(c["node"] as Node).queue_free()
	_cards.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260926
	var slots := [0.08, 0.24, 0.40, 0.57, 0.73, 0.90]
	for i in RAY_COUNT:
		var tr := TextureRect.new()
		tr.texture = _shaft_tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var w := vs.x * rng.randf_range(0.05, 0.10)
		var h := vs.y * 1.3
		tr.size = Vector2(w, h)
		tr.pivot_offset = Vector2(w * 0.5, 0.0)
		tr.rotation = deg_to_rad(-10.0)
		var base_x := vs.x * float(slots[i]) - w * 0.5
		tr.position = Vector2(base_x, -vs.y * 0.12)
		var mat := ShaderMaterial.new()
		mat.shader = _ray_shader
		mat.set_shader_parameter("intensity", rng.randf_range(0.22, 0.42))
		mat.set_shader_parameter("breathe_speed", rng.randf_range(0.10, 0.25))
		mat.set_shader_parameter("phase", rng.randf() * TAU)
		tr.material = mat
		_rays_layer.add_child(tr)
		_cards.append({
			"node": tr,
			"base_x": base_x,
			"amp": vs.x * rng.randf_range(0.008, 0.02),
			"speed": rng.randf_range(0.05, 0.12),
			"phase": rng.randf() * TAU,
		})


func _make_shaft_texture() -> Texture2D:
	var w := 64
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v := float(y) / float(h - 1)
		var down := pow(1.0 - v, 1.6)
		for x in w:
			var u := float(x) / float(w - 1)
			var across := 1.0 - absf(u - 0.5) * 2.0
			across = pow(maxf(across, 0.0), 1.8)
			var nz := 0.75 + 0.25 * sin(u * 12.0 + v * 5.0) * sin(u * 7.0 - v * 9.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(across * down * nz, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _mote_texture() -> Texture2D:
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)
