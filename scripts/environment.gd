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
var bobbers: Array = []  # v3 accents: {node, base_y, phase, amp, speed, mode}

const ZONE_W := 2560.0

func build() -> void:
	randomize()
	_build_gameplay_accents()
	_build_foreground_accents()
	_build_rays()
	_build_surface()
	_build_particles()
	_build_v3_accents()

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
	# dark background seaweed tufts, kept small and faint so they read as distant plants
	var f0: Texture2D = load("res://assets/sprites/seaweed_fg_0.png")
	var f1: Texture2D = load("res://assets/sprites/seaweed_fg_1.png")
	for i in range(8):
		var a := AnimatedSprite2D.new()
		var sf := SpriteFrames.new()
		sf.add_animation("sway")
		sf.set_animation_speed("sway", 1.1)
		sf.add_frame("sway", f0)
		sf.add_frame("sway", f1)
		a.sprite_frames = sf
		a.play("sway")
		a.scale = Vector2(randf_range(0.6, 1.0), randf_range(0.6, 1.0))
		a.position = Vector2(randf_range(-100, ZONE_W + 100), randf_range(200, 1400))
		a.modulate = Color(0.4, 0.6, 0.7, 0.5)
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
	for b in bobbers:
		var bn: Sprite2D = b["node"]
		if b["mode"] == "bob":
			bn.position.y = b["base_y"] + sin(t * b["speed"] + b["phase"]) * b["amp"]
		else:
			bn.rotation = sin(t * b["speed"] + b["phase"]) * b["amp"]

func _build_v3_accents() -> void:
	# v3 pixel-art accents (batches A-D near the sandy floor / mid-water,
	# batch E as far backdrop silhouettes) over the real 3D boulder base.
	# Seeded so placement is stable across runs.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260925
	var tint := Color(0.8, 0.88, 0.95)
	# batch A: rocks near the floor (complement the 3D boulders, don't duplicate)
	var rocks := [["env-mossy-boulder", 3, 0.7, 1.0], ["env-rock-spire", 2, 0.6, 0.9],
		["env-rock-arch", 2, 0.7, 1.0], ["env-jagged-cluster", 2, 0.6, 0.9]]
	for r in rocks:
		var tex: Texture2D = load("res://assets/sprites/%s.png" % r[0])
		for i in range(r[1]):
			var sc := rng.randf_range(r[2], r[3])
			var pos := Vector2(rng.randf_range(40, ZONE_W - 40), rng.randf_range(1440.0, 1560.0))
			add_child(_spr(tex, pos, sc, tint))
	# batch B: corals, gentle sway
	var corals := [["env-brain-coral", 2], ["env-sea-fan", 2], ["env-mushroom-coral", 2], ["env-red-branching", 2]]
	for c in corals:
		var tex2: Texture2D = load("res://assets/sprites/%s.png" % c[0])
		for i in range(c[1]):
			var pos2 := Vector2(rng.randf_range(40, ZONE_W - 40), rng.randf_range(1440.0, 1520.0))
			var n := _spr(tex2, pos2, rng.randf_range(0.6, 0.9), tint)
			add_child(n)
			bobbers.append({"node": n, "base_y": pos2.y, "phase": rng.randf() * TAU,
				"amp": 0.06, "speed": rng.randf_range(0.6, 1.1), "mode": "sway"})
	# batch C: plants near the floor + drifting glow plankton mid-water
	var plants := [["env-eelgrass", 3], ["env-feather-fern", 3], ["env-broad-leaf", 2]]
	for pl in plants:
		var tex3: Texture2D = load("res://assets/sprites/%s.png" % pl[0])
		for i in range(pl[1]):
			var pos3 := Vector2(rng.randf_range(40, ZONE_W - 40), rng.randf_range(1440.0, 1520.0))
			var n2 := _spr(tex3, pos3, rng.randf_range(0.7, 1.0), tint)
			add_child(n2)
			bobbers.append({"node": n2, "base_y": pos3.y, "phase": rng.randf() * TAU,
				"amp": 0.08, "speed": rng.randf_range(0.7, 1.2), "mode": "sway"})
	var gp: Texture2D = load("res://assets/sprites/env-glow-plankton.png")
	for i in range(6):
		var pos4 := Vector2(rng.randf_range(60, ZONE_W - 60), rng.randf_range(300.0, 1200.0))
		var g := _spr(gp, pos4, rng.randf_range(0.5, 0.8), Color(0.7, 1.0, 0.9, 0.8))
		add_child(g)
		bobbers.append({"node": g, "base_y": pos4.y, "phase": rng.randf() * TAU,
			"amp": 14.0, "speed": rng.randf_range(0.4, 0.8), "mode": "bob"})
	# batch D: shells + sand ripples on the floor
	var shells := [["env-starfish", 3, 0.5, 0.8], ["env-scallop-shell", 3, 0.5, 0.8], ["env-rubble-pile", 3, 0.5, 0.8]]
	for sh in shells:
		var tex4: Texture2D = load("res://assets/sprites/%s.png" % sh[0])
		for i in range(sh[1]):
			var sc2 := rng.randf_range(sh[2], sh[3])
			var pos5 := Vector2(rng.randf_range(40, ZONE_W - 40), rng.randf_range(1500.0, 1560.0))
			add_child(_spr(tex4, pos5, sc2, tint))
	var rip: Texture2D = load("res://assets/sprites/env-sand-ripples.png")
	for i in range(3):
		var pos6 := Vector2(rng.randf_range(100, ZONE_W - 100), rng.randf_range(1520.0, 1570.0))
		add_child(_spr(rip, pos6, rng.randf_range(1.5, 2.5), Color(1, 1, 1, 0.35)))
	# batch E: far backdrop silhouettes (dark blue art; tree order draws them behind fish/player)
	var back := [["env-distant-spires", 2, 3.0, 3.6], ["env-coral-forest", 1, 2.8, 3.2],
		["env-cliff-wall", 1, 3.0, 3.4], ["env-distant-arch", 1, 2.8, 3.2]]
	for bd in back:
		var tex5: Texture2D = load("res://assets/sprites/%s.png" % bd[0])
		for i in range(bd[1]):
			var pos7 := Vector2(rng.randf_range(100, ZONE_W - 100), rng.randf_range(350.0, 950.0))
			add_child(_spr(tex5, pos7, rng.randf_range(bd[2], bd[3]), Color(0.5, 0.62, 0.92, 0.9)))
