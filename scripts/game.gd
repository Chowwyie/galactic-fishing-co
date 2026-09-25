extends Node2D

# Galactic Fishing Co. — Sunlit Shallows vertical slice.
# Orchestrates world, player, fish, harpoons, ship, HUD, catalog, environment.

var world: Node2D
var player: Player
var hud: Hud
var catalog: CatalogUI
var ship_ui: ShipUI
var env: EnvBuilder
var bg3d: BG3DWorld
var harpoons: Array = []
var active_harpoons := 0
var started := false
var ui_open := false
var max_depth_y := 1300.0
var debt_remaining := 5000
var cargo_manifest: Array = []
var caught_species := {}
var title_layer: CanvasLayer
var shake := 0.0
var flash: ColorRect

const USE_3D_BG := false  # 2026-09-25: 3D SubViewport renders on desktop only,
# not in the web export (only the Environment gradient shows). v3 2D art carries the scene.

func _ready() -> void:
	if USE_3D_BG:
		_build_bg3d()
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	env = EnvBuilder.new()
	world.add_child(env)
	env.build(self)
	# player
	player = Player.new()
	player.game = self
	player.position = Vector2(1280, 260)
	world.add_child(player)
	spawn_fish()
	# UI
	hud = Hud.new()
	add_child(hud)
	hud.build(self)
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)
	catalog = CatalogUI.new()
	add_child(catalog)
	catalog.build(self)
	ship_ui = ShipUI.new()
	add_child(ship_ui)
	ship_ui.build(self)
	_build_title()
	hud.refresh()
	_web_qa_hook()

func _build_title() -> void:
	title_layer = CanvasLayer.new()
	title_layer.layer = 50
	add_child(title_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.12, 0.22, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_layer.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.custom_minimum_size = Vector2(700, 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	title_layer.add_child(v)
	var t := Label.new()
	t.text = "GALACTIC FISHING CO."
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 56)
	t.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	v.add_child(t)
	var s := Label.new()
	s.text = "Sunlit Shallows — vertical slice\n\nFish show as silhouettes in the water.\nCatch them to discover what they really are."
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", 18)
	s.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	v.add_child(s)
	var c := Label.new()
	c.text = "WASD / arrows — swim    ·    mouse — aim    ·    click — harpoon\nE — talk to S.H.I.P. at the ship    ·    TAB — fish catalog"
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_theme_font_size_override("font_size", 15)
	c.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	v.add_child(c)
	var b := Button.new()
	b.text = "DIVE"
	b.custom_minimum_size = Vector2(240, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(_start_game)
	v.add_child(b)
	b.grab_focus()

func _start_game() -> void:
	started = true
	title_layer.queue_free()

func spawn_fish() -> void:
	for i in range(24):
		var depth := randf_range(180.0, 1350.0)
		var options: Array = []
		for s in FishData.SPECIES:
			if depth >= float(s["min_depth"]) - 50.0:
				options.append(s)
		if options.is_empty():
			options.append(FishData.SPECIES[0])
		var sp: Dictionary = options[randi() % options.size()]
		var f := Fish.new()
		f.setup(self, sp, Vector2(randf_range(80, 2480), depth))
		world.add_child(f)

func spawn_harpoon(p: Player) -> void:
	var h := Harpoon.new()
	h.setup(self, p, p.aim_dir, p.harpoon_speed)
	world.add_child(h)
	harpoons.append(h)
	active_harpoons += 1
	h.tree_exited.connect(func() -> void:
		active_harpoons = maxi(0, active_harpoons - 1)
		harpoons.erase(h))

func catch_fish(f: Fish, pos: Vector2) -> void:
	if f.caught:
		return
	if player.cargo >= player.cargo_max:
		hud.floater(pos, "CARGO FULL — sell at the ship!", Color(1.0, 0.6, 0.3))
		return
	var sp: Dictionary = f.species
	f.catch()
	player.cargo += 1
	cargo_manifest.append(sp["id"])
	caught_species[sp["id"]] = int(caught_species.get(sp["id"], 0)) + 1
	# juice: poof + flash + shake + floater
	catch_poof(pos)
	flash.color.a = 0.35
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.35)
	add_shake(6.0)
	hud.floater(pos, "+1 %s" % sp["name"], Color(0.6, 1.0, 0.7))
	hud.refresh()
	# first catch of a species -> capture screen reveals the real fish
	if int(caught_species[sp["id"]]) == 1:
		catalog.show_capture(sp)

func catch_poof(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.amount = 16
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.95
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 12.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, -60)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	p.color = Color(0.95, 1.0, 1.0, 0.9)
	p.texture = load("res://assets/sprites/bubble.png")
	p.position = pos
	world.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)

func sell_sparkle(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.amount = 30
	p.lifetime = 1.0
	p.one_shot = true
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 40.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 220.0
	p.gravity = Vector2(0, 120)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.4
	p.color = Color(1.0, 0.9, 0.4, 1.0)
	p.texture = load("res://assets/sprites/glow.png")
	p.position = pos
	world.add_child(p)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)

func add_shake(amount: float) -> void:
	shake = minf(shake + amount, 14.0)

func apply_shake_to(cam: Camera2D, delta: float) -> void:
	if shake > 0.05:
		cam.offset += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
		shake = maxf(0.0, shake - 26.0 * delta)

func _process(_delta: float) -> void:
	if not started:
		return
	hud.refresh()
	if not ui_open and not ship_ui.dialog_open and ship_ui.near_ship():
		hud.show_prompt("[E] Talk to S.H.I.P.")
	else:
		hud.hide_prompt()

func _build_bg3d() -> void:
	# Real 3D background behind the 2D canvas: a SubViewport with its own
	# 3D world, drawn on a canvas layer below everything 2D.
	var bg_layer := CanvasLayer.new()
	bg_layer.name = "BG3D"
	bg_layer.layer = -100
	add_child(bg_layer)
	var svc := SubViewportContainer.new()
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.stretch = false
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.handle_input_locally = false
	sv.gui_disable_input = true
	svc.add_child(sv)
	bg3d = BG3DWorld.new()
	sv.add_child(bg3d)
func _web_qa_hook() -> void:
	# Screenshot-QA affordance for the web export only: loading
	# index.html#y=<depth> skips the title and drops the player at that depth.
	if not OS.has_feature("web"):
		return
	var hash: String = str(JavaScriptBridge.eval("window.location.hash", true))
	if hash.begins_with("#y="):
		_start_game()
		player.position = Vector2(1280, clampf(hash.trim_prefix("#y=").to_float(), 0.0, 1560.0))
