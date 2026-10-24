@tool
extends "res://addons/juicecam/2d/addons/juice_cam_output_modifier_2d.gd"

const TRACKER_GROUP: StringName = &"juicecam_scene_lifecycle_tracker"


func setup(camera: Node2D) -> void:
	_record(camera, "addon_setup_count")


func exit(camera: Node2D) -> void:
	_record(camera, "addon_exit_count")


func modify_output(_frame: JuiceCamAddonFrame2D) -> void:
	pass


func _record(camera: Node2D, counter_name: StringName) -> void:
	if not is_instance_valid(camera) or not camera.is_inside_tree():
		return
	var tracker: Node = camera.get_tree().get_first_node_in_group(TRACKER_GROUP)
	if tracker == null:
		return
	tracker.set_meta(counter_name, int(tracker.get_meta(counter_name, 0)) + 1)
