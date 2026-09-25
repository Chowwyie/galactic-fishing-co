class_name Player
extends CharacterBody2D

const SPEED := 235.0

var game
var oxygen_max := 60.0
var oxygen := 60.0
var cargo := 0
var cargo_max := 8
var credits := 0
var harpoon_speed := 540.0
var harpoon_cd := 0.35
var has_oxy_tank := false
var has_cargo_hold := false
var has_harpoon2 := false

var aim_dir := Vector2.RIGHT
var fire_timer := 0.0
var bob_t := 0.0
var swim_t := 0.0
var sprite: AnimatedSprite2D
var cam: Camera2D
var bubbles: CPUParticles2D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	# diver animation frames: idle + 3-frame swim (Dave the Diver style art)
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 4.0)
	sf.set_animation_loop("idle", true)
	sf.add_frame("idle", load("res://assets/sprites/diver_idle.png"))
	sf.add_animation("swim")
	sf.set_animation_speed("swim", 8.0)
	sf.set_animation_loop("swim", true)
	sf.add_frame("swim", load("res://assets/sprites/diver_swim_0.png"))
	sf.add_frame("swim", load("res://assets/sprites/diver_swim_1.png"))
	sf.add_frame("swim", load("res://assets/sprites/diver_swim_2.png"))
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = sf
	sprite.play("idle")
	sprite.scale = Vector2(0.72, 0.72)
	add_child(sprite)
	# bubble trail
	bubbles = CPUParticles2D.new()
	bubbles.amount = 24
	bubbles.lifetime = 1.6
	bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = 10.0
	bubbles.direction = Vector2(0, -1)
	bubbles.spread = 25.0
	bubbles.initial_velocity_min = 25.0
	bubbles.initial_velocity_max = 55.0
	bubbles.gravity = Vector2.ZERO
	bubbles.scale_amount_min = 0.8
	bubbles.scale_amount_max = 1.4
	bubbles.texture = load("res://assets/sprites/bubble.png")
	bubbles.emitting = false
	add_child(bubbles)
	# camera with smoothing
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.zoom = Vector2(0.88, 0.88)  # iter3: Dave-like framing, environment dominates
	cam.limit_left = 0
	cam.limit_right = 2560
	cam.limit_top = -220
	cam.limit_bottom = 1600
	add_child(cam)  # enabled cameras become current automatically on entering the tree

func _unhandled_input(event: InputEvent) -> void:
	if game == null or not game.started or get_tree().paused:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not game.ui_open:
			try_fire()

func try_fire() -> void:
	if fire_timer > 0.0:
		return
	if game.active_harpoons >= 3:
		return
	fire_timer = harpoon_cd
	game.spawn_harpoon(self)
	game.add_shake(3.0)

func _physics_process(delta: float) -> void:
	if game == null or not game.started or get_tree().paused:
		return
	fire_timer = maxf(0.0, fire_timer - delta)
	# aim at mouse
	var m := get_global_mouse_position()
	if m.distance_squared_to(global_position) > 4.0:
		aim_dir = (m - global_position).normalized()
	sprite.rotation = aim_dir.angle()
	sprite.scale.y = -0.72 if aim_dir.x < 0.0 else 0.72
	# movement
	var mv := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		mv.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		mv.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		mv.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		mv.y += 1.0
	if mv.length_squared() > 0.0:
		mv = mv.normalized()
	velocity = mv * SPEED
	# depth gate pushback
	if global_position.y > game.max_depth_y:
		velocity.y = minf(velocity.y, 0.0) - 420.0
	# low oxygen: forced gentle ascent
	if oxygen <= 0.0:
		velocity = Vector2(velocity.x * 0.4, -260.0)
		oxygen = 0.0
	move_and_slide()
	global_position.x = clampf(global_position.x, 30.0, 2530.0)
	global_position.y = clampf(global_position.y, -30.0, 1560.0)
	# oxygen
	var drain := 1.0
	if global_position.y > game.max_depth_y:
		drain = 1.6
	if global_position.y < 80.0:
		oxygen = oxygen_max
	else:
		oxygen = maxf(0.0, oxygen - drain * delta)
	# swim anim + idle bob
	bob_t += delta
	swim_t += delta * (10.0 if mv.length_squared() > 0.0 else 2.0)
	sprite.position.y = sin(bob_t * 2.2) * 3.0
	sprite.speed_scale = 1.6 if mv.length_squared() > 0.0 else 0.5
	var want := "swim" if mv.length_squared() > 0.0 else "idle"
	if sprite.animation != want:
		sprite.play(want)
	bubbles.emitting = mv.length_squared() > 0.0
	# camera lookahead + gentle drift
	var look := aim_dir * 55.0 + velocity * 0.12
	look += Vector2(sin(bob_t * 0.6) * 8.0, cos(bob_t * 0.45) * 6.0)
	cam.offset = cam.offset.lerp(look, 1.0 - exp(-3.0 * delta))
	game.apply_shake_to(cam, delta)
