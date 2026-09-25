class_name CatalogUI
extends CanvasLayer

# Collection checklist + per-catch capture screen.
# In-water fish are silhouettes; detailed art appears here for the first time.

var game
var panel: PanelContainer
var list: VBoxContainer
var capture: PanelContainer
var capture_open := false
var is_open := false

func build(p_game: Node2D) -> void:
	game = p_game
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	# --- catalog panel ---
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 480)
	panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.10, 0.18, 0.96)
	style.set_corner_radius_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := Label.new()
	title.text = "GALACTIC FISHING CO. — CATCH CATALOG"
	title.add_theme_font_size_override("font_size", 20)
	v.add_child(title)
	var sub := Label.new()
	sub.text = "Specimens documented this expedition. (TAB to close)"
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	v.add_child(sub)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	v.add_child(list)
	# --- capture popup ---
	capture = PanelContainer.new()
	capture.set_anchors_preset(Control.PRESET_CENTER)
	capture.custom_minimum_size = Vector2(520, 420)
	capture.visible = false
	capture.add_theme_stylebox_override("panel", style)
	add_child(capture)
	_refresh_list()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_TAB and k.pressed and not k.echo:
			if capture_open:
				return
			is_open = not is_open
			panel.visible = is_open
			if is_open:
				_refresh_list()

func _refresh_list() -> void:
	for c in list.get_children():
		c.queue_free()
	for s in FishData.SPECIES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		list.add_child(row)
		var pic := TextureRect.new()
		pic.custom_minimum_size = Vector2(120, 90)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(pic)
		var col := VBoxContainer.new()
		row.add_child(col)
		var name_l := Label.new()
		name_l.add_theme_font_size_override("font_size", 17)
		col.add_child(name_l)
		var d := Label.new()
		d.add_theme_font_size_override("font_size", 13)
		d.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(360, 0)
		col.add_child(d)
		if game.caught_species.has(s["id"]):
			var frames: Array = FishData.frames(s["art"])
			pic.texture = frames[1]
			name_l.text = "%s  (x%d banked)" % [s["name"], game.caught_species[s["id"]]]
			d.text = s["desc"]
		else:
			var frames2: Array = FishData.frames(s["water"])
			pic.texture = frames2[1]
			pic.modulate = Color(0.1, 0.12, 0.16)
			name_l.text = "??? — unidentified silhouette"
			name_l.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
			d.text = "No specimen on file. The shape in the water is all we know. For now."

# Capture popup shown on first catch of each species (pauses the game).
func show_capture(species: Dictionary) -> void:
	capture_open = true
	game.ui_open = true
	get_tree().paused = true
	for c in capture.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	capture.add_child(v)
	var h := Label.new()
	h.text = "NEW SPECIMEN DOCUMENTED"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_size_override("font_size", 16)
	h.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	v.add_child(h)
	var pic := TextureRect.new()
	var frames: Array = FishData.frames(species["art"])
	pic.texture = frames[1]
	pic.custom_minimum_size = Vector2(240, 180)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pic)
	var name_l := Label.new()
	name_l.text = species["name"]
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 24)
	v.add_child(name_l)
	var d := Label.new()
	d.text = species["desc"]
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(440, 0)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.add_theme_font_size_override("font_size", 14)
	d.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	v.add_child(d)
	var btn := Button.new()
	btn.text = "LOG IT  (it was worth %d cr)" % species["value"]
	btn.custom_minimum_size = Vector2(280, 44)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_close_capture)
	v.add_child(btn)
	capture.visible = true
	btn.grab_focus()

func _close_capture() -> void:
	capture.visible = false
	capture_open = false
	game.ui_open = false
	get_tree().paused = false
