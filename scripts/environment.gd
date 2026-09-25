class_name EnvBuilder
extends Node2D

# 2.5D environment accents on the gameplay plane. The volumetric background
# (rocks, corals, sand, water column) is real 3D geometry in BG3DWorld,
# rendered in a SubViewport behind this canvas. This script keeps the
# animated 2D accents: swaying seaweed, light dapples, god-ray shafts,
# surface shimmer, marine snow + micro-bubbles.

var t := 0.0
var rays: Array = []
var bands: Array = []
var dapples: Array = []
var weeds: Array = []  # each: {node, phase}

const ZONE_W := 2560.0

func build() -> void:
	randomize()
	_build_gameplay_accents()
	_build_foreground_accents()
	_build_rays()
	_build_surface()
	_build_particles()

func _spr(tex: Texture2D, pos: Vector2, scl: float, mod: Color = Color.WHITE) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.scale = Vector2(scl, scl)
	s.modulate = mod
	return s

func _build_gameplay_accents() -> void:
	# light dappling on the sand (over the 3D floor)
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
		a.scale = Vector2(0.75, 0.75)
		a.position = Vector2(randf_range(20, ZONE_W - 20), randf_range(1420, 1490))
		add_child(a)
		weeds.append({"node": a, "phase": randf() * TAU})

func _build_foreground_accents() -> void:
	# dark seaweed framing the view (no parallax — the 3D world carries depth now)
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
		a.scale = Vector2(randf_range(1.0, 1.8), randf_range(1.0, 1.8))
		a.position = Vector2(randf_range(-100, ZONE_W + 100), randf_range(100, 1500))
		a.modulate = Color(0.35, 0.55, 0.65, 0.85)
		add_child(a)
		weeds.append({"node": a, "phase": randf() * TAU})

func _build_rays() -> void:
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
		add_child(poly)
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
