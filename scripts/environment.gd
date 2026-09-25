class_name EnvBuilder
extends Node2D

# 2.5D environment: 4 parallax layers + gameplay plane + animated light/water FX.
# Layer order (back -> front):
#   far (0.10): water gradient + distant silhouettes
#   mid (0.45): rock / coral formations
#   gameplay (1.0): sand floor, seaweed, rocks, corals, rays anchored lightly
#   foreground (1.55): dark seaweed framing

var t := 0.0
var rays: Array = []
var bands: Array = []
var dapples: Array = []
var weeds: Array = []  # each: {node, phase, base_rot}

const ZONE_W := 2560.0

func build() -> void:
	randomize()
	_build_far()
	_build_mid()
	_build_gameplay_plane()
	_build_foreground()
	_build_rays()
	_build_surface()
	_build_particles()

func _layer(parent: Node, motion: Vector2) -> ParallaxLayer:
	var pb := parent
	if parent is ParallaxBackground:
		var l := ParallaxLayer.new()
		l.motion_scale = motion
		parent.add_child(l)
		return l
	return null

func _spr(tex: Texture2D, pos: Vector2, scl: float, mod: Color = Color.WHITE) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.scale = Vector2(scl, scl)
	s.modulate = mod
	return s

func _build_far() -> void:
	var pb := ParallaxBackground.new()
	add_child(pb)
	var far := ParallaxLayer.new()
	far.motion_scale = Vector2(0.10, 0.10)
	pb.add_child(far)
	# water gradient backdrop
	var grad := _spr(load("res://assets/sprites/water_gradient.png"), Vector2(1280, 720), 1.0)
	grad.scale = Vector2(400, 4.2)
	far.add_child(grad)
	# distant silhouettes
	var rock_far: Texture2D = load("res://assets/sprites/rock_far.png")
	for i in range(16):
		var s := _spr(rock_far,
			Vector2(randf_range(0, ZONE_W), randf_range(150, 1450)),
			randf_range(1.5, 3.0),
			Color(0.40, 0.56, 0.80, 0.45))
		far.add_child(s)
	# faint far corals
	for i in range(8):
		var c: Texture2D = load("res://assets/sprites/coral_%d.png" % (i % 3))
		var s := _spr(c, Vector2(randf_range(0, ZONE_W), randf_range(900, 1500)),
			randf_range(1.5, 2.5), Color(0.45, 0.60, 0.85, 0.35))
		far.add_child(s)

func _build_mid() -> void:
	var pb := get_child(0) as ParallaxBackground
	var mid := ParallaxLayer.new()
	mid.motion_scale = Vector2(0.45, 0.45)
	pb.add_child(mid)
	var rock: Texture2D = load("res://assets/sprites/rock.png")
	for i in range(12):
		mid.add_child(_spr(rock, Vector2(randf_range(0, ZONE_W), randf_range(500, 1500)),
			randf_range(1.5, 2.6), Color(0.42, 0.58, 0.82, 0.80)))
	for i in range(10):
		var c: Texture2D = load("res://assets/sprites/coral_%d.png" % (i % 3))
		mid.add_child(_spr(c, Vector2(randf_range(0, ZONE_W), randf_range(700, 1520)),
			randf_range(1.5, 2.5), Color(0.65, 0.78, 0.95, 0.85)))

func _build_gameplay_plane() -> void:
	# sandy floor (two rows of tiles)
	var sand: Texture2D = load("res://assets/sprites/sand.png")
	for x in range(0, int(ZONE_W), 64):
		for y in [1496, 1560]:
			var s := _spr(sand, Vector2(x + 32, y), 1.0)
			add_child(s)
	# light dappling on the sand
	var dapple: Texture2D = load("res://assets/sprites/dapple.png")
	for i in range(18):
		var s := _spr(dapple, Vector2(randf_range(0, ZONE_W), randf_range(1490, 1570)),
			randf_range(2.0, 4.5))
		add_child(s)
		dapples.append({"node": s, "phase": randf() * TAU, "speed": randf_range(0.5, 1.1)})
	# swaying seaweed anchored near the floor
	var sw0: Texture2D = load("res://assets/sprites/seaweed_0.png")
	var sw1: Texture2D = load("res://assets/sprites/seaweed_1.png")
	for i in range(30):
		var a := AnimatedSprite2D.new()
		var sf := SpriteFrames.new()
		sf.add_animation("sway")
		sf.set_animation_speed("sway", 1.6)
		sf.add_frame("sway", sw0)
		sf.add_frame("sway", sw1)
		a.sprite_frames = sf
		a.play("sway")
		a.scale = Vector2(2.5, 2.5)
		a.position = Vector2(randf_range(20, ZONE_W - 20), randf_range(1420, 1490))
		add_child(a)
		weeds.append({"node": a, "phase": randf() * TAU})
	# rocks + corals on the gameplay plane
	var rock: Texture2D = load("res://assets/sprites/rock.png")
	for i in range(14):
		add_child(_spr(rock, Vector2(randf_range(0, ZONE_W), randf_range(1350, 1500)),
			randf_range(1.5, 3.0)))
	for i in range(10):
		var c: Texture2D = load("res://assets/sprites/coral_%d.png" % (i % 3))
		add_child(_spr(c, Vector2(randf_range(0, ZONE_W), randf_range(1380, 1500)),
			randf_range(1.2, 2.2)))

func _build_foreground() -> void:
	var pb := get_child(0) as ParallaxBackground
	var fg := ParallaxLayer.new()
	fg.motion_scale = Vector2(1.55, 1.55)
	pb.add_child(fg)
	var f0: Texture2D = load("res://assets/sprites/seaweed_fg_0.png")
	var f1: Texture2D = load("res://assets/sprites/seaweed_fg_1.png")
	for i in range(12):
		var a := AnimatedSprite2D.new()
		var sf := SpriteFrames.new()
		sf.add_animation("sway")
		sf.set_animation_speed("sway", 1.1)
		sf.add_frame("sway", f0)
		sf.add_frame("sway", f1)
		a.sprite_frames = sf
		a.play("sway")
		a.scale = Vector2(randf_range(3.0, 5.0), randf_range(3.0, 5.0))
		a.position = Vector2(randf_range(-100, ZONE_W + 100), randf_range(100, 1500))
		a.modulate = Color(0.35, 0.55, 0.65, 0.85)
		fg.add_child(a)
		weeds.append({"node": a, "phase": randf() * TAU})

func _build_rays() -> void:
	var pb := get_child(0) as ParallaxBackground
	var rl := ParallaxLayer.new()
	rl.motion_scale = Vector2(0.25, 0.25)
	pb.add_child(rl)
	for i in range(7):
		var poly := Polygon2D.new()
		var x := 120.0 + i * 380.0 + randf_range(-60, 60)
		var top_w := randf_range(40, 90)
		var bot_w := top_w + randf_range(120, 220)
		var slant := 160.0
		poly.polygon = PackedVector2Array([
			Vector2(x - top_w * 0.5, -120), Vector2(x + top_w * 0.5, -120),
			Vector2(x + slant + bot_w * 0.5, 1050), Vector2(x + slant - bot_w * 0.5, 1050),
		])
		poly.color = Color(0.82, 0.96, 1.0, 0.10)
		rl.add_child(poly)
		rays.append({"node": poly, "phase": randf() * TAU, "speed": randf_range(0.4, 0.9)})

func _build_surface() -> void:
	# ripple shimmer bands seen from below, ping-ponging gently
	var band: Texture2D = load("res://assets/sprites/surface_band.png")
	for i in range(2):
		var s := _spr(band, Vector2(640, 10 + i * 22), 1.0, Color(1, 1, 1, 0.75 - i * 0.25))
		s.scale = Vector2(5, 1)
		add_child(s)
		bands.append({"node": s, "phase": float(i) * 2.1, "amp": 46.0 - i * 14.0, "speed": 0.35 + i * 0.22})

func _build_particles() -> void:
	# marine snow across the whole zone
	var snow := CPUParticles2D.new()
	snow.amount = 380
	snow.lifetime = 14.0
	snow.preprocess = 14.0
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(1280, 850)
	snow.position = Vector2(1280, 750)
	snow.direction = Vector2(0, 1)
	snow.spread = 18.0
	snow.initial_velocity_min = 8.0
	snow.initial_velocity_max = 26.0
	snow.gravity = Vector2.ZERO
	snow.scale_amount_min = 0.7
	snow.scale_amount_max = 1.6
	snow.color = Color(1, 1, 1, 0.55)
	snow.texture = load("res://assets/sprites/snow.png")
	add_child(snow)
	# micro-bubbles rising
	var bub := CPUParticles2D.new()
	bub.amount = 70
	bub.lifetime = 9.0
	bub.preprocess = 9.0
	bub.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bub.emission_rect_extents = Vector2(1280, 850)
	bub.position = Vector2(1280, 750)
	bub.direction = Vector2(0, -1)
	bub.spread = 30.0
	bub.initial_velocity_min = 15.0
	bub.initial_velocity_max = 40.0
	bub.gravity = Vector2.ZERO
	bub.scale_amount_min = 0.8
	bub.scale_amount_max = 1.8
	bub.color = Color(0.9, 0.97, 1.0, 0.5)
	bub.texture = load("res://assets/sprites/bubble.png")
	add_child(bub)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	t += delta
	for r in rays:
		(r["node"] as Polygon2D).modulate.a = 0.65 + 0.35 * sin(t * r["speed"] + r["phase"])
	for b in bands:
		var n: Sprite2D = b["node"]
		n.position.x = 640.0 + sin(t * b["speed"] + b["phase"]) * b["amp"]
	for dp in dapples:
		var n2: Sprite2D = dp["node"]
		n2.modulate.a = 0.55 + 0.45 * sin(t * dp["speed"] + dp["phase"])
	for w in weeds:
		var n3: AnimatedSprite2D = w["node"]
		n3.rotation = sin(t * 0.9 + w["phase"]) * 0.07
