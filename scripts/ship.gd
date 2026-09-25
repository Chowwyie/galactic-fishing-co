class_name ShipUI
extends CanvasLayer

# Physical ship at the surface + holographic axolotl-cat AI avatar with
# dialogue states (greeting / sold / farewell / empty) + upgrade shop v0.

var game
var ship: Sprite2D
var ship_base_y := 30.0
var bob_t := 0.0
var dialog: PanelContainer
var avatar: TextureRect
var text_label: Label
var btn_box: VBoxContainer
var dialog_open := false
var glitch_timer := 0.0
var glitch_t := 0.0

const LINES := {
	"greeting": "Oh! A contractor! Up from the shallows already?\nSell me your catch and we'll chip away at that debt of yours. Galactic Fishing Co. believes in you. (Legally, we have to say that.)",
	"empty": "Your cargo hold is... echoing. Bold strategy! The debt, however, remains. It always remains.\nBring me fish, contractor. The ocean provides. Probably.",
	"farewell": "Pleasure doing business! Remember: the Company values you exactly as much as your last haul.\nWhich is to say: come back soon.",
}

func build(p_game: Node2D) -> void:
	game = p_game
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	# physical ship sprite bobbing at the surface
	ship = Sprite2D.new()
	ship.texture = load("res://assets/sprites/ship.png")
	ship.scale = Vector2(4, 4)
	ship.position = Vector2(1280, ship_base_y)
	game.world.add_child(ship)
	# dialogue panel (bottom strip)
	dialog = PanelContainer.new()
	dialog.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dialog.custom_minimum_size = Vector2(0, 220)
	dialog.offset_top = -240
	dialog.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.09, 0.16, 0.97)
	style.border_color = Color(0.35, 0.9, 1.0, 0.6)
	style.set_border_width_all(2)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	dialog.add_theme_stylebox_override("panel", style)
	add_child(dialog)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	dialog.add_child(h)
	avatar = TextureRect.new()
	avatar.texture = load("res://assets/ship_avatar.webp")
	avatar.custom_minimum_size = Vector2(150, 150)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(avatar)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	h.add_child(right)
	var name_l := Label.new()
	name_l.text = "S.H.I.P. — Sales & Happiness Interface, Pal"
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.add_theme_color_override("font_color", Color(0.5, 0.95, 1.0))
	right.add_child(name_l)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(700, 90)
	text_label.add_theme_font_size_override("font_size", 15)
	right.add_child(text_label)
	btn_box = VBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 6)
	right.add_child(btn_box)

func _process(delta: float) -> void:
	bob_t += delta
	if is_instance_valid(ship):
		ship.position.y = ship_base_y + sin(bob_t * 1.3) * 6.0
		ship.rotation = sin(bob_t * 0.9) * 0.03
	if dialog_open and is_instance_valid(avatar):
		# hologram flicker + occasional glitch
		avatar.modulate.a = 0.82 + 0.18 * abs(sin(bob_t * 11.0))
		glitch_timer -= delta
		if glitch_timer <= 0.0:
			glitch_t = 0.14
			glitch_timer = randf_range(3.0, 7.0)
		if glitch_t > 0.0:
			glitch_t -= delta
			avatar.position.x = randf_range(-5, 5)
			avatar.modulate.a = randf_range(0.3, 0.7)
		else:
			avatar.position.x = 0.0

func near_ship() -> bool:
	var p = game.player.global_position
	return p.distance_to(Vector2(1280, 60)) < 170.0 and p.y < 220.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_E and k.pressed and not k.echo:
			if game == null or not game.started:
				return
			if dialog_open:
				return
			if near_ship() and not game.ui_open:
				open_greeting()

func _clear_buttons() -> void:
	for c in btn_box.get_children():
		c.queue_free()

func _add_button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 36)
	b.pressed.connect(cb)
	btn_box.add_child(b)

func open_greeting() -> void:
	dialog_open = true
	game.ui_open = true
	get_tree().paused = true
	dialog.visible = true
	text_label.text = LINES["greeting"]
	_clear_buttons()
	var n: int = game.cargo_manifest.size()
	_add_button("Sell catch (%d fish)" % n, _do_sell)
	_add_button("Ship upgrades", open_shop)
	_add_button("Back to the water", close_dialog)

func _do_sell() -> void:
	var p = game.player
	var n: int = game.cargo_manifest.size()
	_clear_buttons()
	if n == 0:
		text_label.text = LINES["empty"]
		_add_button("I'll find fish. Somehow.", close_dialog)
		return
	var total := 0
	for id in game.cargo_manifest:
		total += FishData.get_species(id)["value"]
	p.credits += total
	p.cargo = 0
	game.cargo_manifest.clear()
	game.debt_remaining = maxi(0, game.debt_remaining - total)
	game.sell_sparkle(Vector2(1280, 90))
	game.add_shake(5.0)
	text_label.text = "Sold %d fish for %d credits! Applied directly to your debt. Only %d remaining!\nEvery haul brings freedom closer. (Freedom is a registered trademark of Galactic Fishing Co.)" % [n, total, game.debt_remaining]
	_add_button("Ship upgrades", open_shop)
	_add_button("Back to the water", _farewell)

func _farewell() -> void:
	text_label.text = LINES["farewell"]
	_clear_buttons()
	_add_button("Dive!", close_dialog)

func open_shop() -> void:
	_clear_buttons()
	var p = game.player
	text_label.text = "Contractor improvement packages! One tier each. The Company invests in its assets. You are the asset."
	var items := [
		{"key": "oxy", "name": "O2 Tank XL — 90s oxygen (600 cr)", "cost": 600, "owned": p.has_oxy_tank},
		{"key": "cargo", "name": "Cargo Hold+ — 14 capacity (500 cr)", "cost": 500, "owned": p.has_cargo_hold},
		{"key": "harp", "name": "Harpoon MK-II — faster, longer (750 cr)", "cost": 750, "owned": p.has_harpoon2},
	]
	for it in items:
		var label_text: String = it["name"]
		if it["owned"]:
			label_text = "[OWNED] " + it["name"]
		elif p.credits < it["cost"]:
			label_text += "  (need %d more)" % (it["cost"] - p.credits)
		var key: String = it["key"]
		_add_button(label_text, func(): _buy(key))
	_add_button("Back", open_greeting)

func _buy(key: String) -> void:
	var p = game.player
	var costs := {"oxy": 600, "cargo": 500, "harp": 750}
	if p.credits < costs[key]:
		return
	var owned := false
	match key:
		"oxy":
			owned = p.has_oxy_tank
			if not owned:
				p.has_oxy_tank = true
				p.oxygen_max = 90.0
				p.oxygen = 90.0
		"cargo":
			owned = p.has_cargo_hold
			if not owned:
				p.has_cargo_hold = true
				p.cargo_max = 14
		"harp":
			owned = p.has_harpoon2
			if not owned:
				p.has_harpoon2 = true
				p.harpoon_speed = 740.0
				p.harpoon_cd = 0.22
	if not owned:
		p.credits -= costs[key]
		game.hud.floater(Vector2(1280, 120), "UPGRADE INSTALLED", Color(0.5, 1.0, 0.6))
	open_shop()

func close_dialog() -> void:
	dialog.visible = false
	dialog_open = false
	game.ui_open = false
	get_tree().paused = false
