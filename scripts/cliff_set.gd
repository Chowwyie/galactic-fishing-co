extends Node3D
## Procedural cliff set for the Sunlit Shallows layer, inspired by the kept
## "underwater cliff" concept art: flat-topped stepped mesas, warm sunlit tops,
## cool shadowed faces, dark framing masses left/right, pale far mesas, sandy
## seabed. Solid rock, no holes. Built to sit inside the water_3d volume so the
## ray cards get real occlusion.

const ROCK_SHADER := preload("res://shaders/cliff_rock.gdshader")

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20260927
	var rock_mat := _make_mat(Color(0.96, 0.80, 0.58), Color(0.36, 0.47, 0.50), 0.10)
	var sand_mat := _make_mat(Color(1.00, 0.87, 0.64), Color(0.55, 0.62, 0.55), 0.20)
	# Sandy seabed, top at y = -24.
	_add_box(Vector3(0.0, -28.0, -60.0), Vector3(400.0, 8.0, 220.0), sand_mat, 0.0)
	# Dark foreground framers, rising past the top of the frame.
	_add_mesa(Vector3(-20.0, -24.0, -16.0), 24.0, 52.0, 5, rock_mat)
	_add_mesa(Vector3(22.0, -24.0, -20.0), 26.0, 56.0, 5, rock_mat)
	# Warm mid-ground mesas, center left open.
	_add_mesa(Vector3(-14.0, -24.0, -48.0), 22.0, 38.0, 4, rock_mat)
	_add_mesa(Vector3(20.0, -24.0, -58.0), 26.0, 44.0, 4, rock_mat)
	_add_mesa(Vector3(-2.0, -24.0, -72.0), 30.0, 40.0, 4, rock_mat)
	# Pale far mesas; the water fog does the hazing.
	_add_mesa(Vector3(-30.0, -24.0, -100.0), 34.0, 46.0, 4, rock_mat)
	_add_mesa(Vector3(34.0, -24.0, -108.0), 30.0, 42.0, 4, rock_mat)


func _make_mat(top: Color, side: Color, caustic_strength: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ROCK_SHADER
	m.set_shader_parameter("top_color", top)
	m.set_shader_parameter("side_color", side)
	m.set_shader_parameter("caustic_strength", caustic_strength)
	return m


func _add_mesa(base: Vector3, width: float, height: float, strata: int, mat: Material) -> void:
	var y := base.y
	var w := width
	var sh := height / float(strata)
	for i in strata:
		var bw := w * _rng.randf_range(0.94, 1.06)
		var bd := w * _rng.randf_range(0.80, 0.95)
		var bh := sh * _rng.randf_range(0.90, 1.10)
		var ox := _rng.randf_range(-1.6, 1.6)
		var oz := _rng.randf_range(-1.6, 1.6)
		_add_box(Vector3(base.x + ox, y + bh * 0.5, base.z + oz),
				Vector3(bw, bh, bd), mat, _rng.randf_range(-0.08, 0.08))
		y += bh
		w *= _rng.randf_range(0.82, 0.92)
	# Cap overhang: flat top wider than the neck, like the concept mesas.
	var cap_h := sh * 0.45
	_add_box(Vector3(base.x, y + cap_h * 0.5, base.z),
			Vector3(w * 1.25, cap_h, w * 1.15), mat, _rng.randf_range(-0.05, 0.05))


func _add_box(pos: Vector3, size: Vector3, mat: Material, rot_y: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation.y = rot_y
	mi.material_override = mat
	add_child(mi)
