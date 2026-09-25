class_name EnvBuilder
extends Node2D

# 2.5D environment accents on the gameplay plane. The volumetric background
# (rocks, corals, sand, water column) is real 3D geometry in BG3DWorld,
# rendered in a SubViewport behind this canvas. This script keeps the
# animated 2D accents: swaying seaweed, light dapples, god-ray shafts,
# surface shimmer, marine snow + micro-bubbles.

var game: Node2D
var t := 0.0
var rays: Array = []
var bands: Array = []
var dapples: Array = []
var weeds: Array = []  # each: {node, phase}
var bobbers: Array = []  # v3 accents: {node, base_y, phase, amp, speed, mode}
var parallax: Array = []  # far backdrop: {node, base, f}

const ZONE_W := 2560.0

func build(p_game: Node2D) -> void:
	game = p_game
	randomize()
	_build_sand_floor()
	_build_v3_accents()
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

func _build_sand_floor() -> void:
	# Tiled sand strip along the bottom (the 3D dune floor is gone on web).
	var sand: Texture2D = load("res://assets/sprites/sand.png")
	var tint := Color(0.72, 0.8, 0.88)
	for row in range(2):
		for i in range(40):
			var sp := _spr(sand, Vector2(32.0 + i * 64.0, 1512.0 + row * 64.0), 1.0, tint)
			sp.flip_h = randi() % 2 == 0
			sp.flip_v = randi() % 2 == 0
			sp.rotation = (randi() % 4) * PI / 2.0
			add_child(sp)
	# light dappling on the sand
	var dapple: Texture2D = load("res://assets/sprites/dapple.png")
	for i in range(18):
		var dp := _spr(dapple, Vector2(randf_range(0, ZONE_W), randf_range(1490, 1570)),
			randf_range(2.0, 4.5))
		add_child(dp)
		dapples.append({"node": dp, "phase": randf() * TAU, "speed": randf_range(0.5, 1.1)})

func _pf(node: Sprite2D, base: Vector2, f: float) -> void:
	parallax.append({"node": node, "base": base, "f": f})

func _build_v3_accents() -> void:
	# v3 pixel-art carries the scene: batch E far silhouettes (parallax),
	# batches A-D mid/near. Seeded so placement is stable across runs.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260925
	var tint := Color(0.8, 0.88, 0.95)
	# batch E: far backdrop silhouettes, slow parallax behind everything.
	# Rock forms only, so they read as canyon walls. The bottom 35% of each
	# texture has a baked alpha fade so no hard horizontal edge shows where
	# the wall meets open water. Coral-forest is tinted deep blue and kept in
	# the lower band so it reads as a distant reef, never a floating island.
	var rock_tint := Color(0.45, 0.58, 0.9, 0.85)
	var reef_tint := Color(0.35, 0.48, 0.85, 0.85)
	var back := [
		["env-distant-spires", 2, 2.2, 3.0, 300.0, 950.0, rock_tint],
		["env-cliff-wall", 1, 2.2, 3.0, 300.0, 950.0, rock_tint],
		["env-distant-arch", 1, 2.2, 3.0, 300.0, 950.0, rock_tint],
		["env-coral-forest", 1, 2.2, 2.8, 700.0, 950.0, reef_tint],
	]
	for bd in back:
		var texe: Texture2D = load("res://assets/sprites/%s.png" % bd[0])
		for i in range(bd[1]):
			var pe := Vector2(rng.randf_range(150, ZONE_W - 150), rng.randf_range(bd[4], bd[5]))
			var se := _spr(texe, pe, rng.randf_range(bd[2], bd[3]), bd[6])
			add_child(se)
			_pf(se, pe, 0.45)
	# batch A: rocks near the floor (no 3D boulders on web — these are the rocks now)
	var rocks := [["env-mossy-boulder", 3, 0.6, 0.9], ["env-rock-spire", 2, 0.5, 0.8],
		["env-rock-arch", 2, 0.6, 0.9], ["env-jagged-cluster", 2, 0.5, 0.8]]
	for r in rocks:
		var tex: Texture2D = load("res://assets/sprites/%s.png" % r[0])
		for i in range(r[1]):
			var pr := Vector2(rng.randf_range(40, ZONE_W - 40), rng.randf_range(1460.0, 1540.0))
			add_child(_spr(tex, pr, rng.randf_range(r[2], r[3]), tint))
	# batch B: corals near the floor, gentle sway
	var corals := [["env-brain-coral", 2], ["env-sea-fan", 2], ["env-mushroom-coral", 2], ["env-red-branching", 2]]
	for c in corals:
		var tex2: Texture2D = load("res://assets/sprites/%s.png" % c[0])
		for i in range(c[1]):
			var pc := Vector2(rng.randf_range(40, ZONE_W - 40), rng.randf_range(1450.0, 1520.0))
			var n := _spr(tex2, pc, rng.randf_range(0.5, 0.8), tint)
			add_child(n)
			bobbers.append({"node": n, "base_y": pc.y, "phase": rng.randf() * TAU,
				"amp": 0.06, "speed": rng.randf_range(0.6, 1.1), "mode": "sway"})
	# batch C: plants kept SMALL, mostly floor-anchored near the frame edges as framing
	var plants := ["env-eelgrass", "env-feather-fern", "env-broad-leaf"]
	for pli in range(11):
		var tex3: Texture2D = load("res://assets/sprites/%s.png" % plants[pli % 3])
		var edge_x := rng.randf_range(40, 380) if pli % 2 == 0 else rng.randf_range(ZONE_W - 380, ZONE_W - 40)
		var pp := Vector2(edge_x, rng.randf_range(1440.0, 1530.0))
		var n2 := _spr(tex3, pp, rng.randf_range(0.45, 0.65), tint)
		add_child(n2)
		bobbers.append({"node": n2, "base_y": pp.y, "phase": rng.randf() * TAU,
			"amp": 0.08, "speed": rng.randf_range(0.7, 1.2), "mode": "sway"})
	# a few small drifting kelp bits near the top edges
	for i in range(3):
		var tex4: Texture2D = load("res://assets/sprites/%s.png" % plants[i % 3])
		var pt := Vector2(rng.randf_range(60, 340) if i % 2 == 0 else rng.randf_range(ZONE_W - 340, ZONE_W - 60),
			rng.randf_range(150.0, 350.0))
		var nt := _spr(tex4, pt, rng.randf_range(0.4, 0.55), Color(0.8, 0.88, 0.95, 0.7))
		add_child(nt)
		bobbers.append({"node": nt, "base_y": pt.y, "phase": rng.randf() * TAU,
			"amp": 12.0, "speed": rng.randf_range(0.4, 0.7), "mode": "bob"})
	# drifting glow plankton mid-water: soft light motes only, no rock body —
	# they must never read as floating boulders
	var gp: Texture2D = load("res://assets/sprites/glow.png")
	for i in range(4):
		var pg := Vector2(rng.randf_range(60, ZONE_W - 60), rng.randf_range(300.0, 1200.0))
		var g := _spr(gp, pg, rng.randf_range(1.2, 2.0), Color(0.55, 1.0, 0.85, 0.55))
		add_child(g)
		_pf(g, pg, 0.8)
		bobbers.append({"node": g, "phase": rng.randf() * TAU,
			"amp": 0.2, "speed": rng.randf_range(0.4, 0.8), "mode": "pulse", "alpha": 0.55})
	# batch D: shells + sand ripples on the floor
	var shells := [["env-starfish", 3, 0.5, 0.75], ["env-scallop-shell", 3, 0.5, 0.75], ["env-rubble-pile", 3, 0.5, 0.75]]
	for sh in shells:
		var tex5: Texture2D = load("res://assets/sprites/%s.png" % sh[0])
		for i in range(sh[1]):
			var ps := Vector2(rng.randf_range(40, ZONE_W - 40), rng.randf_range(1500.0, 1560.0))
			add_child(_spr(tex5, ps, rng.randf_range(sh[2], sh[3]), tint))
	var rip: Texture2D = load("res://assets/sprites/env-sand-ripples.png")
	for i in range(4):
		var pr2 := Vector2(rng.randf_range(100, ZONE_W - 100), rng.randf_range(1520.0, 1570.0))
		add_child(_spr(rip, pr2, rng.randf_range(1.5, 2.5), Color(1, 1, 1, 0.35)))

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
	if game != null and game.player != null and game.player.cam != null:
		var cc: Vector2 = game.player.cam.get_screen_center_position()
		for pl in parallax:
			var pn: Sprite2D = pl["node"]
			var pb: Vector2 = pl["base"]
			var pf: float = pl["f"]
			pn.position = pb * pf + cc * (1.0 - pf)
	for b in bobbers:
		var bn2: Sprite2D = b["node"]
		if b["mode"] == "pulse":
			bn2.modulate.a = b["alpha"] + sin(t * b["speed"] + b["phase"]) * b["amp"]
	for b in bobbers:
		var bn: Sprite2D = b["node"]
		if b["mode"] == "bob":
			bn.position.y = b["base_y"] + sin(t * b["speed"] + b["phase"]) * b["amp"]
		else:
			bn.rotation = sin(t * b["speed"] + b["phase"]) * b["amp"]
