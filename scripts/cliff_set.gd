extends Node3D
## Procedural cliff set v2: low-poly FACETED rock. Each stratum is an
## irregular polygonal extrusion -- jittered footprint, noise-displaced
## rings, chamfered top edge -- built de-indexed with outward face normals,
## so the rock reads as stylized stone instead of boxes. Flat tops are kept
## for the mesa look of the concept art.

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


func _hash(x: int, y: int) -> float:
	var h := x * 374761393 + y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0


func _vnoise(x: float, y: float) -> float:
	var xi := int(floor(x))
	var yi := int(floor(y))
	var xf: float = x - floor(x)
	var yf: float = y - floor(y)
	var u: float = xf * xf * (3.0 - 2.0 * xf)
	var v: float = yf * yf * (3.0 - 2.0 * yf)
	var a := _hash(xi, yi)
	var b := _hash(xi + 1, yi)
	var c := _hash(xi, yi + 1)
	var d := _hash(xi + 1, yi + 1)
	return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v


## Append triangle (a,b,c), flipping winding so the face normal points along
## `outward`. Winding-proof: works regardless of the engine's front-face rule
## because the material is cull-disabled and normals are geometric.
func _tri(verts: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var nrm := (b - a).cross(c - a)
	if nrm.dot(outward) < 0.0:
		verts.append(a)
		verts.append(c)
		verts.append(b)
	else:
		verts.append(a)
		verts.append(b)
		verts.append(c)


func _rock_stratum(c: Vector3, r_bot: float, r_top: float, h: float, seed_off: float, mat: Material) -> void:
	var sides := 7 + _rng.randi_range(0, 2)
	var angs := PackedFloat32Array()
	var rads := PackedFloat32Array()
	for i in sides:
		angs.append(TAU * float(i) / float(sides) + _rng.randf_range(-0.18, 0.18))
		rads.append(_rng.randf_range(0.86, 1.14))
	var ring_f := [0.0, 0.45, 0.8, 1.0]
	var ring_r := [r_bot, lerpf(r_bot, r_top, 0.45) * 1.05, lerpf(r_bot, r_top, 0.8), r_top]
	var pts: Array = []
	for ri in ring_f.size():
		var ring: Array = []
		for i in sides:
			var n := _vnoise(float(i) * 1.7 + seed_off, float(ri) * 2.3 + seed_off * 0.7)
			var r: float = float(ring_r[ri]) * rads[i] * (0.90 + 0.20 * n)
			var px := c.x + cos(angs[i]) * r
			var pz := c.z + sin(angs[i]) * r
			var py := c.y + float(ring_f[ri]) * h + (n - 0.5) * h * 0.08
			ring.append(Vector3(px, py, pz))
		pts.append(ring)
	# Chamfer ring: inset at the top edge so no razor rim.
	var bevel: Array = []
	for i in sides:
		var n := _vnoise(float(i) * 1.7 + seed_off, 9.1 + seed_off)
		var r := r_top * rads[i] * (0.90 + 0.20 * n) * 0.88
		bevel.append(Vector3(c.x + cos(angs[i]) * r, c.y + h, c.z + sin(angs[i]) * r))
	var top_center := Vector3(c.x, c.y + h, c.z)
	var bot_center := Vector3(c.x, c.y, c.z)
	var up := Vector3(0.0, 1.0, 0.0)
	var verts := PackedVector3Array()
	for ri in range(ring_f.size() - 1):
		for i in sides:
			var j := (i + 1) % sides
			var mid: Vector3 = (pts[ri][i] + pts[ri][j] + pts[ri + 1][j]) / 3.0
			var out := Vector3(mid.x - c.x, 0.0, mid.z - c.z).normalized()
			_tri(verts, pts[ri][i], pts[ri][j], pts[ri + 1][j], out)
			_tri(verts, pts[ri][i], pts[ri + 1][j], pts[ri + 1][i], out)
	var top_ring: Array = pts[ring_f.size() - 1]
	for i in sides:
		var j := (i + 1) % sides
		var mid2: Vector3 = (top_ring[i] + top_ring[j] + bevel[j]) / 3.0
		var out2 := Vector3(mid2.x - c.x, 0.6, mid2.z - c.z).normalized()
		_tri(verts, top_ring[i], top_ring[j], bevel[j], out2)
		_tri(verts, top_ring[i], bevel[j], bevel[i], out2)
	for i in sides:
		var j := (i + 1) % sides
		_tri(verts, bevel[i], bevel[j], top_center, up)
		_tri(verts, pts[0][j], pts[0][i], bot_center, -up)
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for t in range(0, verts.size(), 3):
		var nrm := (verts[t + 1] - verts[t]).cross(verts[t + 2] - verts[t]).normalized()
		normals[t] = nrm
		normals[t + 1] = nrm
		normals[t + 2] = nrm
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)


func _add_mesa(base: Vector3, width: float, height: float, strata: int, mat: Material) -> void:
	var y := base.y
	var r := width * 0.5
	var sh := height / float(strata)
	for i in strata:
		var rb := r * _rng.randf_range(0.95, 1.05)
		var rt := rb * _rng.randf_range(0.80, 0.90)
		var h := sh * _rng.randf_range(0.90, 1.10)
		var ox := _rng.randf_range(-1.6, 1.6)
		var oz := _rng.randf_range(-1.6, 1.6)
		_rock_stratum(Vector3(base.x + ox, y, base.z + oz), rb, rt, h, _rng.randf() * 100.0, mat)
		y += h
		r = rt
	# Cap overhang: flat top wider than the neck, like the concept mesas.
	var cap_h := sh * 0.45
	_rock_stratum(Vector3(base.x, y, base.z), r * 1.05, r * 1.28, cap_h, _rng.randf() * 100.0, mat)


func _add_box(pos: Vector3, size: Vector3, mat: Material, rot_y: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation.y = rot_y
	mi.material_override = mat
	add_child(mi)
