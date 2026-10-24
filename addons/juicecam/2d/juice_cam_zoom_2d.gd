@tool
@icon("res://addons/juicecam/icons/juice_cam_zoom_2d.png")
class_name JuiceCamZoom2D
extends "res://addons/juicecam/2d/juice_cam_influence_2d.gd"

## World-space region that adjusts a camera's zoom while its tracking focus is inside.

enum ZoomShape {
	CIRCLE,
	RECTANGLE,
}

const DEBUG_COLOR: Color = JuiceCamDebugPalette2D.ZOOM

signal zoom_area_entered(camera: Node2D)
signal zoom_area_exited(camera: Node2D)
signal zoom_level_changed(camera: Node2D, zoom_level: Vector2)

@export_group("Zoom Area")
## Shape used to decide when the camera's tracking focus is inside this region.
@export var zoom_shape: ZoomShape = ZoomShape.CIRCLE:
	set(value):
		if zoom_shape == value:
			return
		zoom_shape = value
		notify_property_list_changed()
		_influence_shape_changed()
## Radius in this node's local coordinates when using a circle.
@export_range(0.01, 100000.0, 1.0, "or_greater", "suffix:px") var radius: float = 200.0:
	set(value):
		radius = maxf(0.01, value)
		_influence_shape_changed()
## Size in this node's local coordinates when using a rectangle.
@export var rectangle_size: Vector2 = Vector2(400.0, 200.0):
	set(value):
		rectangle_size = Vector2(maxf(0.01, value.x), maxf(0.01, value.y))
		_influence_shape_changed()

@export_group("Zoom")
## Multiplier applied to the camera's current target zoom while inside the region.
@export_range(0.01, 10.0, 0.01) var zoom_factor: float = 1.5

## Blend the zoom factor from the region center to its edge.
@export var gradual_zoom: bool = true

var _last_zoom_by_camera: Dictionary[int, Vector2] = {}


func _validate_property(property: Dictionary) -> void:
	if property.name == &"radius" and zoom_shape != ZoomShape.CIRCLE:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif property.name == &"rectangle_size" and zoom_shape != ZoomShape.RECTANGLE:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func get_influence_local_rect() -> Rect2:
	if zoom_shape == ZoomShape.CIRCLE:
		return Rect2(Vector2(-radius, -radius), Vector2.ONE * radius * 2.0)
	return Rect2(-rectangle_size * 0.5, rectangle_size)


func contains_world_point(world_position: Vector2) -> bool:
	var local_position: Vector2 = to_local(world_position)
	if zoom_shape == ZoomShape.CIRCLE:
		return local_position.length_squared() <= radius * radius
	var half_size: Vector2 = rectangle_size * 0.5
	return absf(local_position.x) <= half_size.x and absf(local_position.y) <= half_size.y


## Returns the zoom requested by this region for the supplied camera focus.
func calculate_zoom(camera: Node2D, base_zoom: Vector2, world_position: Vector2) -> Vector2:
	var requested_zoom: Vector2 = base_zoom
	if is_camera_inside(camera):
		var blend: float = 1.0
		if gradual_zoom:
			blend = 1.0 - _get_normalized_distance(world_position)
		var multiplier: float = lerpf(1.0, zoom_factor, clampf(blend, 0.0, 1.0))
		requested_zoom = base_zoom * multiplier
	var camera_id: int = camera.get_instance_id()
	var had_previous_zoom: bool = _last_zoom_by_camera.has(camera_id)
	var previous_zoom: Vector2 = _last_zoom_by_camera.get(camera_id, base_zoom)
	if not had_previous_zoom:
		_last_zoom_by_camera[camera_id] = base_zoom
	if previous_zoom.distance_to(requested_zoom) > 0.01:
		_last_zoom_by_camera[camera_id] = requested_zoom
		emit_signal("zoom_level_changed", camera, requested_zoom)
	return requested_zoom


func _get_normalized_distance(world_position: Vector2) -> float:
	var local_position: Vector2 = to_local(world_position)
	if zoom_shape == ZoomShape.CIRCLE:
		return clampf(local_position.length() / radius, 0.0, 1.0)
	var half_size: Vector2 = rectangle_size * 0.5
	return clampf(maxf(absf(local_position.x) / half_size.x, absf(local_position.y) / half_size.y), 0.0, 1.0)


func _on_camera_entered(camera: Node2D) -> void:
	emit_signal("zoom_area_entered", camera)


func _on_camera_exited(camera: Node2D) -> void:
	emit_signal("zoom_area_exited", camera)


func forget_camera(camera: Node2D) -> void:
	if is_instance_valid(camera):
		_last_zoom_by_camera.erase(camera.get_instance_id())
	super.forget_camera(camera)


func _draw_influence_debug() -> void:
	if zoom_shape == ZoomShape.CIRCLE:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, DEBUG_COLOR, DEBUG_STROKE_WIDTH, false)
	else:
		draw_rect(Rect2(-rectangle_size * 0.5, rectangle_size), DEBUG_COLOR, false, DEBUG_STROKE_WIDTH, false)
	draw_circle(Vector2.ZERO, 4.0, DEBUG_COLOR)
