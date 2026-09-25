class_name Fish
extends Area2D

var game
var species: Dictionary
var vel := Vector2.ZERO
var state := "wander"  # wander | flee
var wander_target := Vector2.ZERO
var wander_timer := 0.0
var flee_timer := 0.0
var flee_dir := Vector2.RIGHT
var sprite: AnimatedSprite2D
var caught := false

func setup(p_game: Node2D, p_species: Dictionary, pos: Vector2) -> void:
	game = p_game
	species = p_species
	global_position = pos
	collision_layer = 4
	collision_mask = 0
	monitoring = true
	var sf := SpriteFrames.new()
	sf.add_animation("swim")
	sf.set_animation_speed("swim", 6.0)
	sf.set_animation_loop("swim", true)
	for t in FishData.frames(species["water"]):
		sf.add_frame("swim", t)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = sf
	sprite.play("swim")
	sprite.scale = Vector2(3, 3)
	add_child(sprite)
	# collision shape sized to silhouette
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var tex: Texture2D = sf.get_frame_texture("swim", 0)
	rect.size = tex.get_size() * 0.8
	shape.shape = rect
	add_child(shape)
	_pick_wander_target()

func _pick_wander_target() -> void:
	var ang := randf() * TAU
	var dist := randf_range(80.0, 240.0)
	wander_target = global_position + Vector2(cos(ang), sin(ang)) * dist
	wander_target.x = clampf(wander_target.x, 60.0, 2500.0)
	wander_target.y = clampf(wander_target.y, float(species["min_depth"]), 1450.0)
	wander_timer = randf_range(2.0, 4.5)

func _physics_process(delta: float) -> void:
	if caught or get_tree().paused:
		return
	var speed: float = species["speed"]
	var pp: Vector2 = game.player.global_position
	var to_player := global_position - pp
	# threats: player proximity + active harpoons
	var threat := Vector2.ZERO
	if to_player.length() < 175.0:
		threat = to_player.normalized()
	for h in game.harpoons:
		if is_instance_valid(h):
			var th = global_position - h.global_position
			if th.length() < 120.0:
				threat = th.normalized()
				break
	if threat != Vector2.ZERO:
		state = "flee"
		flee_timer = 1.1
		flee_dir = threat
	if state == "flee":
		flee_timer -= delta
		vel = flee_dir * speed * 1.7
		sprite.speed_scale = 2.2
		if flee_timer <= 0.0:
			state = "wander"
			sprite.speed_scale = 1.0
			_pick_wander_target()
	else:
		wander_timer -= delta
		var to_t := wander_target - global_position
		if to_t.length() < 20.0 or wander_timer <= 0.0:
			_pick_wander_target()
		else:
			vel = to_t.normalized() * speed * 0.55
		sprite.speed_scale = 1.0
	global_position += vel * delta
	global_position.x = clampf(global_position.x, 40.0, 2520.0)
	global_position.y = clampf(global_position.y, 120.0, 1470.0)
	if vel.x < -5.0:
		sprite.scale.x = -3.0
	elif vel.x > 5.0:
		sprite.scale.x = 3.0

func catch() -> void:
	caught = true
	queue_free()
