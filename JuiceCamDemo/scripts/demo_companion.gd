extends Node2D

## Small moving landmark used to show weighted multi-target framing.

@export var follow_target: Node2D
@export var horizontal_offset: float = 1800.0
@export var vertical_offset: float = -28.0
@export var bob_height: float = 18.0
@export var bob_speed: float = 2.2

var _elapsed: float = 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(follow_target):
		return
	_elapsed += delta
	global_position = follow_target.global_position + Vector2(
		horizontal_offset,
		vertical_offset + sin(_elapsed * bob_speed) * bob_height
	)
