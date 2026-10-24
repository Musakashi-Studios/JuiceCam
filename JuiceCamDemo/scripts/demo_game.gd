@tool
extends Node2D

## Keeps the demo camera's first target linked while the scene is edited or played.


func _enter_tree() -> void:
	var camera: JuiceCam2D = get_node_or_null("JuiceCam2D") as JuiceCam2D
	var player: Node2D = get_node_or_null("Player") as Node2D
	if not is_instance_valid(camera) or not is_instance_valid(player):
		return
	if camera.get_primary_target() == null:
		camera.set_primary_target(player)
	var targets: Array[JuiceCamTargetData] = camera.get_all_targets()
	if not targets.is_empty():
		targets[0].use_lookahead = true
		targets[0].lookahead_factor = 0.28
