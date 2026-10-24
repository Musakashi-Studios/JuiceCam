@tool
extends Node2D

## Base class for world-space 2D regions that modify one or more JuiceCam2D nodes.

const RegistryScript: GDScript = preload(
	"res://addons/juicecam/2d/juice_cam_influence_registry_2d.gd"
)
const INFLUENCE_GROUP: StringName = &"juice_cam_influences_2d"
const DEBUG_STROKE_WIDTH: float = -1.0

@export_group("Influence")
## Turns this influence region on or off for every camera.
@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value
		queue_redraw()

## Higher-priority influences take precedence when several can affect a camera.
@export_range(-100000, 100000, 1) var priority: int = 0

var _inside_cameras: Dictionary[int, Node2D] = {}
var _debug_cameras: Dictionary[int, Node2D] = {}


func _enter_tree() -> void:
	add_to_group(INFLUENCE_GROUP)
	set_notify_transform(true)
	var registry: JuiceCamInfluenceRegistry2D = RegistryScript.get_existing(get_tree())
	if registry != null:
		registry.register_node(self)


func _ready() -> void:
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	z_as_relative = false
	queue_redraw()


func _exit_tree() -> void:
	var cameras: Array[Node2D] = []
	for camera: Node2D in _inside_cameras.values():
		cameras.append(camera)
	for camera: Node2D in cameras:
		if is_instance_valid(camera):
			_on_camera_exited(camera)
	_inside_cameras.clear()
	_debug_cameras.clear()
	var registry: JuiceCamInfluenceRegistry2D = RegistryScript.get_existing(get_tree())
	if registry != null:
		registry.unregister_node(self)


func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSFORM_CHANGED or not is_inside_tree():
		return
	var registry: JuiceCamInfluenceRegistry2D = RegistryScript.get_existing(get_tree())
	if registry != null:
		registry.update_node(self)


func _draw() -> void:
	if _should_draw_influence_debug():
		_draw_influence_debug()


func _should_draw_influence_debug() -> bool:
	return enabled and (Engine.is_editor_hint() or not _debug_cameras.is_empty())


func get_influence_local_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2.ZERO)


func get_influence_world_aabb() -> Rect2:
	var local_rect: Rect2 = get_influence_local_rect()
	var corners: Array[Vector2] = [
		global_transform * local_rect.position,
		global_transform * Vector2(local_rect.end.x, local_rect.position.y),
		global_transform * local_rect.end,
		global_transform * Vector2(local_rect.position.x, local_rect.end.y),
	]
	var minimum: Vector2 = corners[0]
	var maximum: Vector2 = corners[0]
	for corner: Vector2 in corners:
		minimum = minimum.min(corner)
		maximum = maximum.max(corner)
	return Rect2(minimum, maximum - minimum)


func _influence_shape_changed() -> void:
	queue_redraw()
	var registry: JuiceCamInfluenceRegistry2D = RegistryScript.get_existing(get_tree()) if is_inside_tree() else null
	if registry != null:
		registry.update_node(self)


func contains_world_point(_world_position: Vector2) -> bool:
	return false


func update_camera_overlap(camera: Node2D, world_position: Vector2) -> bool:
	if not is_instance_valid(camera) or not is_inside_tree() or is_queued_for_deletion():
		return false
	var camera_id: int = camera.get_instance_id()
	var was_inside: bool = _inside_cameras.has(camera_id)
	var is_inside: bool = enabled and contains_world_point(world_position)
	if was_inside == is_inside:
		return is_inside
	if is_inside:
		_inside_cameras[camera_id] = camera
		_on_camera_entered(camera)
	else:
		_inside_cameras.erase(camera_id)
		_on_camera_exited(camera)
	return is_inside


func is_camera_inside(camera: Node2D) -> bool:
	return is_instance_valid(camera) and _inside_cameras.has(camera.get_instance_id())


func set_camera_debug(camera: Node2D, draw_enabled: bool) -> void:
	if not is_instance_valid(camera):
		return
	var camera_id: int = camera.get_instance_id()
	if draw_enabled:
		_debug_cameras[camera_id] = camera
	else:
		_debug_cameras.erase(camera_id)
	queue_redraw()


func forget_camera(camera: Node2D) -> void:
	if not is_instance_valid(camera):
		return
	var camera_id: int = camera.get_instance_id()
	if _inside_cameras.has(camera_id):
		_inside_cameras.erase(camera_id)
		_on_camera_exited(camera)
	_debug_cameras.erase(camera_id)
	queue_redraw()


func _on_camera_entered(_camera: Node2D) -> void:
	pass


func _on_camera_exited(_camera: Node2D) -> void:
	pass


func _draw_influence_debug() -> void:
	pass
