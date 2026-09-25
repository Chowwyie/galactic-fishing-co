class_name Harpoon
extends Area2D

var game
var dir := Vector2.RIGHT
var speed := 540.0
var max_dist := 430.0
var traveled := 0.0
var dead := false
var sprite: Sprite2D
var rope: Line2D
var origin: Node2D

func setup(p_game: Node2D, p_origin: Node2D, p_dir: Vector2, p_speed: float) -> void:
	game = p_game
	origin = p_origin
	dir = p_dir
	speed = p_speed
	global_position = p_origin.global_position + p_dir * 30.0
	collision_layer = 2
	collision_mask = 4
	monitoring = true
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/harpoon.png")
	sprite.scale = Vector2(3, 3)
	sprite.rotation = dir.angle()
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 14)
	shape.shape = rect
	add_child(shape)
	rope = Line2D.new()
	rope.width = 2.0
	rope.default_color = Color(0.75, 0.72, 0.65, 0.9)
	rope.top_level = true
	game.world.add_child(rope)
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if dead:
		return
	if area is Fish and not (area as Fish).caught:
		dead = true
		game.catch_fish(area as Fish, global_position)
		_despawn()

func _physics_process(delta: float) -> void:
	if dead or get_tree().paused:
		return
	var step := speed * delta
	global_position += dir * step
	traveled += step
	if is_instance_valid(origin):
		rope.points = PackedVector2Array([origin.global_position, global_position])
	if traveled >= max_dist:
		dead = true
		_despawn()

func _despawn() -> void:
	if is_instance_valid(rope):
		rope.queue_free()
	if is_instance_valid(self):
		queue_free()
