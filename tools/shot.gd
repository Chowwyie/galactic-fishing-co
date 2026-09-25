extends SceneTree

var game: Node
var frame := 0
var shots := [150.0, 750.0, 1400.0]
var shot_i := 0
var settle := 0

func _init() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	game = packed.instantiate()
	root.add_child(game)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		game._start_game()
	if frame < 15:
		return false
	if shot_i >= shots.size():
		return true
	var player = game.get("player")
	if player:
		player.position = Vector2(1280, shots[shot_i])
		player.velocity = Vector2.ZERO
	settle += 1
	if settle >= 25:
		var img := root.get_texture().get_image()
		var path := "/tmp/gfc_shot_%d.png" % shot_i
		img.save_png(path)
		print("SAVED ", path)
		shot_i += 1
		settle = 0
	return false
