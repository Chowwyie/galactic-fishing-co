extends Node3D
## Standalone viewer for the cliff set: neutral camera + simple underwater
## light, no water volume. The set is developed and judged on its own here.

var _t := 0.0
var _cam_base := Vector3(0.0, 2.0, 5.0)

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	get_viewport().size_changed.connect(_rebuild)
	_rebuild()


func _process(delta: float) -> void:
	_t += delta
	camera.position = _cam_base + Vector3(sin(_t * 0.05) * 1.5, sin(_t * 0.037 + 1.3) * 1.0, 0.0)


func _rebuild() -> void:
	pass
