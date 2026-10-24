@tool
@icon("res://addons/juicecam/icons/juice_cam_cinematic_2d.png")
class_name JuiceCamCinematic2D
extends Node2D

## A pose in a named cinematic sequence. Playback state belongs to each camera,
## so the same points can be used independently by split-screen cameras.

enum DampingType {
	SMOOTH_DAMP,
	SPRING_DAMP,
	EXPONENTIAL_DECAY,
}

const GROUP_NAME: StringName = &"juice_cam_cinematics_2d"
const CAMERA_GROUP_NAME: StringName = &"juice_cam_cameras_2d"
const MARKER_TEXTURE: Texture2D = preload("res://addons/juicecam/icons/juice_cam_cinematic_marker_2d.svg")
const MARKER_SIZE: Vector2 = Vector2(48.0, 48.0)
const MARKER_OPACITY: float = 1.0
const MARKER_Z_INDEX: int = 4096

var _marker: Sprite2D = null
var _debug_cameras: Dictionary[int, Node2D] = {}

@export_group("Sequence")
## Points with the same name play in ascending sequence-position order.
@export var sequence_name: String = "":
	set(value):
		if sequence_name == value:
			return
		sequence_name = value
		_refresh_peer_configuration_warnings()
## Order of this point within its named sequence.
@export_range(0, 100000, 1) var sequence_position: int = 0:
	set(value):
		if sequence_position == value:
			return
		sequence_position = maxi(0, value)
		_refresh_peer_configuration_warnings()
## Disabled points are ignored when a camera starts the sequence.
@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value
		_refresh_peer_configuration_warnings()
## Time to hold after the camera arrives. Zero advances as soon as it arrives.
@export_range(0.0, 3600.0, 0.05, "suffix:s") var hold_time: float = 1.0:
	set(value):
		hold_time = maxf(0.0, value)

@export_group("Shot")
## Camera zoom scale for this point.
@export_custom(PROPERTY_HINT_LINK, "") var target_zoom: Vector2 = Vector2.ONE

@export_group("Motion Override")
## Forces smoothing on and uses this point's tuning. Damping type affects position;
## rotation and zoom use their own Smooth Damp durations.
@export var override_motion_settings: bool = false:
	set(value):
		if override_motion_settings == value:
			return
		override_motion_settings = value
		notify_property_list_changed()
## Position damping algorithm used while this point is active.
@export var damping_type: DampingType = DampingType.SMOOTH_DAMP:
	set(value):
		if damping_type == value:
			return
		damping_type = value
		notify_property_list_changed()
## Arrival duration for position under Smooth Damp (smaller is faster).
@export_range(0.001, 10.0, 0.01, "suffix:s") var position_smooth_time: float = 0.2
## Position speed cap in pixels per second. Zero means unlimited.
@export_range(0.0, 100000.0, 1.0, "or_greater", "suffix:px/s") var position_max_speed: float = 0.0
## Oscillation frequency in Hz for Spring Damp.
@export_range(0.1, 30.0, 0.1, "suffix:Hz") var spring_frequency: float = 5.0
## Damping ratio for Spring Damp. Values below 1 allow overshoot.
@export_range(0.1, 3.0, 0.05) var spring_damping: float = 1.0
## Speed rate for Exponential Decay.
@export_range(0.1, 50.0, 0.5) var decay_rate: float = 8.0
## Arrival duration for rotation under Smooth Damp.
@export_range(0.001, 10.0, 0.01, "suffix:s") var rotation_smooth_time: float = 0.2
## Arrival duration for zoom under Smooth Damp.
@export_range(0.001, 10.0, 0.01, "suffix:s") var zoom_smooth_time: float = 0.2

func _enter_tree() -> void:
	add_to_group(GROUP_NAME)
	_refresh_peer_configuration_warnings()
	if Engine.is_editor_hint():
		_ensure_marker()
		_update_marker()
	set_process(Engine.is_editor_hint())
	if not Engine.is_editor_hint():
		for candidate: Node in get_tree().get_nodes_in_group(CAMERA_GROUP_NAME):
			if not candidate is Node2D:
				continue
			var camera: Node2D = candidate as Node2D
			if camera.get_viewport() == get_viewport() and bool(camera.get("debug_draw_enabled")):
				set_camera_debug(camera, true)


func _exit_tree() -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
	_debug_cameras.clear()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not enabled or sequence_name.strip_edges().is_empty() or not is_inside_tree():
		return warnings
	for candidate: Node in get_tree().get_nodes_in_group(GROUP_NAME):
		if not candidate is JuiceCamCinematic2D or candidate == self:
			continue
		var other_point: JuiceCamCinematic2D = candidate as JuiceCamCinematic2D
		if (
			other_point.enabled
			and not other_point.is_queued_for_deletion()
			and other_point.get_viewport() == get_viewport()
			and other_point.sequence_name == sequence_name
			and other_point.sequence_position == sequence_position
		):
			var warning_text: String = (
				"Sequence '%s' has another enabled point with position ID %d in this viewport. "
				+ "Assign unique position IDs; duplicate IDs fall back to scene-path order."
			)
			warnings.append(warning_text % [sequence_name, sequence_position])
			break
	return warnings


func _process(_delta: float) -> void:
	_update_marker()


func _validate_property(property: Dictionary) -> void:
	if not override_motion_settings and property.name in [
		&"damping_type",
		&"position_smooth_time",
		&"position_max_speed",
		&"spring_frequency",
		&"spring_damping",
		&"decay_rate",
		&"rotation_smooth_time",
		&"zoom_smooth_time",
	]:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif property.name in [&"position_smooth_time", &"position_max_speed"] and damping_type != DampingType.SMOOTH_DAMP:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif property.name in [&"spring_frequency", &"spring_damping"] and damping_type != DampingType.SPRING_DAMP:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif property.name == &"decay_rate" and damping_type != DampingType.EXPONENTIAL_DECAY:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func set_camera_debug(camera: Node2D, draw_enabled: bool) -> void:
	if not is_instance_valid(camera) or camera.get_viewport() != get_viewport():
		return
	var camera_id: int = camera.get_instance_id()
	if draw_enabled:
		_debug_cameras[camera_id] = camera
	else:
		_debug_cameras.erase(camera_id)
	_update_marker_visibility()


func forget_camera(camera: Node2D) -> void:
	if not is_instance_valid(camera):
		return
	_debug_cameras.erase(camera.get_instance_id())
	_update_marker_visibility()


func _update_marker_visibility() -> void:
	var should_show: bool = Engine.is_editor_hint() or not _debug_cameras.is_empty()
	if should_show:
		_ensure_marker()
		_marker.visible = true
		_update_marker()
	elif is_instance_valid(_marker):
		_marker.visible = false
	set_process(should_show)


func _ensure_marker() -> void:
	var existing_marker: Node = get_node_or_null("JuiceCamDebugMarker")
	if existing_marker is Sprite2D and not existing_marker.is_queued_for_deletion():
		_marker = existing_marker as Sprite2D
		return
	if existing_marker != null:
		remove_child(existing_marker)
		existing_marker.queue_free()

	_marker = Sprite2D.new()
	_marker.name = "JuiceCamDebugMarker"
	_marker.texture = MARKER_TEXTURE
	_marker.modulate = Color(1.0, 1.0, 1.0, MARKER_OPACITY)
	_marker.top_level = true
	_marker.z_as_relative = false
	_marker.z_index = MARKER_Z_INDEX
	_marker.owner = null
	add_child(_marker, false, Node.INTERNAL_MODE_FRONT)


func _update_marker() -> void:
	if not is_instance_valid(_marker):
		return
	var marker_position: Vector2 = global_position
	if _marker.global_position != marker_position:
		_marker.global_position = marker_position

	var texture_size: Vector2 = Vector2(MARKER_TEXTURE.get_size())
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	# Cancel the canvas zoom to keep the sprite at a fixed viewport-pixel size.
	var canvas_scale: Vector2 = get_viewport().get_canvas_transform().get_scale()
	var zoom_x: float = maxf(absf(canvas_scale.x), 0.001)
	var zoom_y: float = maxf(absf(canvas_scale.y), 0.001)
	var desired_scale: Vector2 = Vector2(
		MARKER_SIZE.x / (texture_size.x * zoom_x),
		MARKER_SIZE.y / (texture_size.y * zoom_y)
	)
	if not _marker.scale.is_equal_approx(desired_scale):
		_marker.scale = desired_scale


func _refresh_peer_configuration_warnings() -> void:
	if not is_inside_tree():
		return
	for candidate: Node in get_tree().get_nodes_in_group(GROUP_NAME):
		if candidate is JuiceCamCinematic2D and candidate.get_viewport() == get_viewport():
			(candidate as JuiceCamCinematic2D).update_configuration_warnings()
