class_name Hud
extends CanvasLayer

var game
var oxy_bar: ProgressBar
var cargo_label: Label
var credits_label: Label
var debt_label: Label
var prompt_label: Label
var warn_label: Label
var hint_label: Label
var fog: ColorRect
var vignette: TextureRect

func build(p_game: Node2D) -> void:
	game = p_game
	layer = 5
	# depth fog (screen space, alpha driven by depth)
	fog = ColorRect.new()
	fog.color = Color(0.02, 0.08, 0.18, 0.0)
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fog)
	# vignette
	vignette = TextureRect.new()
	vignette.texture = load("res://assets/sprites/vignette.png")
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.85
	add_child(vignette)
	# subtle backing scrims: HUD text stays readable over bright surface water and the dark abyss
	_add_scrim(Control.PRESET_TOP_LEFT, Vector2(8, 6), Vector2(238, 54))
	_add_scrim(Control.PRESET_TOP_RIGHT, Vector2(-246, 6), Vector2(238, 58))
	_add_scrim(Control.PRESET_BOTTOM_LEFT, Vector2(8, -54), Vector2(196, 42))
	_add_scrim(Control.PRESET_BOTTOM_RIGHT, Vector2(-370, -52), Vector2(362, 44))
	# top-left: oxygen
	var oxy_box := VBoxContainer.new()
	oxy_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	oxy_box.position = Vector2(16, 14)
	add_child(oxy_box)
	var oxy_title := Label.new()
	oxy_title.text = "OXYGEN"
	oxy_title.add_theme_font_size_override("font_size", 14)
	oxy_box.add_child(oxy_title)
	oxy_bar = ProgressBar.new()
	oxy_bar.custom_minimum_size = Vector2(220, 18)
	oxy_bar.max_value = 100.0
	oxy_bar.value = 100.0
	oxy_bar.show_percentage = false
	oxy_box.add_child(oxy_bar)
	# top-right: credits + debt
	var money := VBoxContainer.new()
	money.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	money.position = Vector2(-236, 14)
	money.custom_minimum_size = Vector2(220, 0)
	money.alignment = BoxContainer.ALIGNMENT_END
	add_child(money)
	credits_label = _mk_label(money, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	debt_label = _mk_label(money, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	# bottom-left: cargo
	cargo_label = Label.new()
	cargo_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	cargo_label.position = Vector2(16, -44)
	cargo_label.add_theme_font_size_override("font_size", 20)
	add_child(cargo_label)
	# bottom-center: interact prompt + warnings
	prompt_label = Label.new()
	# full-width bottom anchor: text stays centered for any label width (no magic offsets)
	prompt_label.anchor_left = 0.0
	prompt_label.anchor_top = 1.0
	prompt_label.anchor_right = 1.0
	prompt_label.anchor_bottom = 1.0
	prompt_label.offset_top = -90.0
	prompt_label.offset_bottom = -60.0
	prompt_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 20)
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	prompt_label.add_theme_constant_override("outline_size", 5)
	prompt_label.visible = false
	add_child(prompt_label)
	warn_label = Label.new()
	warn_label.anchor_left = 0.0
	warn_label.anchor_top = 1.0
	warn_label.anchor_right = 1.0
	warn_label.anchor_bottom = 1.0
	warn_label.offset_top = -130.0
	warn_label.offset_bottom = -100.0
	warn_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_label.add_theme_font_size_override("font_size", 22)
	warn_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	warn_label.add_theme_constant_override("outline_size", 5)
	warn_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	warn_label.visible = false
	add_child(warn_label)
	# bottom-right: hints
	hint_label = Label.new()
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint_label.position = Vector2(-360, -44)
	hint_label.custom_minimum_size = Vector2(344, 30)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	hint_label.text = "WASD move · click harpoon · E ship · TAB catalog"
	add_child(hint_label)

func _add_scrim(preset: int, pos: Vector2, size: Vector2) -> void:
	var p := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.015, 0.05, 0.10, 0.38)
	s.set_corner_radius_all(7)
	p.add_theme_stylebox_override("panel", s)
	p.set_anchors_preset(preset)
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)

func _mk_label(parent: Control, size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = align
	parent.add_child(l)
	return l

func refresh() -> void:
	var p = game.player
	oxy_bar.max_value = p.oxygen_max
	oxy_bar.value = p.oxygen
	var frac: float = p.oxygen / p.oxygen_max
	var col := Color(0.35, 0.85, 1.0)
	if frac < 0.3:
		col = Color(1.0, 0.4, 0.3)
	elif frac < 0.6:
		col = Color(1.0, 0.8, 0.3)
	oxy_bar.add_theme_stylebox_override("fill", _bar_style(col))
	cargo_label.text = "CARGO  %d / %d" % [p.cargo, p.cargo_max]
	credits_label.text = "CREDITS  %d" % p.credits
	debt_label.text = "DEBT  %d" % game.debt_remaining
	# depth fog + vignette deepen past the gate
	var depth := clampf((p.global_position.y - game.max_depth_y) / 250.0, 0.0, 1.0)
	fog.color.a = depth * 0.55
	vignette.modulate.a = 0.85 + depth * 0.15
	var beyond: bool = p.global_position.y > game.max_depth_y
	warn_label.visible = beyond or p.oxygen <= 0.0
	if p.oxygen <= 0.0:
		warn_label.text = "LOW OXYGEN — ASCENDING!"
	elif beyond:
		warn_label.text = "!! SUIT DEPTH RATING EXCEEDED !!"

func _bar_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(4)
	return s

func show_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = true

func hide_prompt() -> void:
	prompt_label.visible = false

func floater(world_pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.position = world_pos + Vector2(-10, -30)
	l.z_index = 50
	game.world.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 46.0, 0.9).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(l, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(l.queue_free)
