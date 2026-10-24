@tool
@icon("res://addons/juicecam/icons/juice_cam_room_2d.png")
class_name JuiceCamRoom2D
extends "res://addons/juicecam/2d/juice_cam_influence_2d.gd"

## Rectangular region that constrains a JuiceCam2D while its tracking destination is inside.

const DEBUG_COLOR: Color = JuiceCamDebugPalette2D.ROOM
const OPEN_SIDE_COLOR: Color = Color("#FF3B30")

enum OpenSide {
	LEFT = 1 << 0,
	RIGHT = 1 << 1,
	TOP = 1 << 2,
	BOTTOM = 1 << 3,
}

signal room_entered(camera: Node2D)
signal room_exited(camera: Node2D)

@export_group("Room")
## Width and height of the room in this node's local coordinates.
@export var room_size: Vector2 = Vector2(1000.0, 600.0):
	set(value):
		room_size = Vector2(maxf(0.01, value.x), maxf(0.01, value.y))
		_influence_shape_changed()

## Multiplies the minimum zoom needed to fit each axis that has a closed side.
@export_range(1.0, 20.0, 0.01, "or_greater") var zoom_multiplier: float = 1.0:
	set(value):
		zoom_multiplier = maxf(1.0, value)

## Edges that allow the camera's view to extend past the room.
@export_flags("Left", "Right", "Top", "Bottom") var open_sides: int = 0:
	set(value):
		open_sides = value
		queue_redraw()

## Smoothly rotate the camera to match this room's rotation while inside.
@export var align_camera_rotation: bool = true

## Instantly snaps the camera to this room's constrained pose when the room becomes active.
@export var snap_on_enter: bool = false


func get_influence_local_rect() -> Rect2:
	return Rect2(-room_size * 0.5, room_size)


func contains_world_point(world_position: Vector2) -> bool:
	return get_influence_local_rect().has_point(to_local(world_position))


## Raises zoom as needed to keep the visible camera rectangle within closed room edges.
func constrain_zoom(camera_zoom: Vector2, camera_rotation: float, viewport_size: Vector2) -> Vector2:
	var unzoomed_half_extents: Vector2 = _get_camera_half_extents_in_room_space(
		Vector2.ONE,
		camera_rotation,
		viewport_size
	)
	var minimum_room_zoom: float = 0.0
	if _axis_has_closed_side(OpenSide.LEFT, OpenSide.RIGHT):
		minimum_room_zoom = maxf(minimum_room_zoom, unzoomed_half_extents.x / (room_size.x * 0.5))
	if _axis_has_closed_side(OpenSide.TOP, OpenSide.BOTTOM):
		minimum_room_zoom = maxf(minimum_room_zoom, unzoomed_half_extents.y / (room_size.y * 0.5))
	minimum_room_zoom *= zoom_multiplier
	var constrained_zoom := Vector2(
		signf(camera_zoom.x) * maxf(absf(camera_zoom.x), minimum_room_zoom),
		signf(camera_zoom.y) * maxf(absf(camera_zoom.y), minimum_room_zoom)
	)
	var camera_half_extents: Vector2 = _get_camera_half_extents_in_room_space(
		constrained_zoom,
		camera_rotation,
		viewport_size
	)
	var required_scale: float = 1.0
	if _axis_has_closed_side(OpenSide.LEFT, OpenSide.RIGHT):
		required_scale = maxf(required_scale, camera_half_extents.x / (room_size.x * 0.5))
	if _axis_has_closed_side(OpenSide.TOP, OpenSide.BOTTOM):
		required_scale = maxf(required_scale, camera_half_extents.y / (room_size.y * 0.5))
	return constrained_zoom * required_scale


## Clamps the camera center against each closed room edge in room-local space.
func constrain_camera_position(
	world_position: Vector2,
	camera_zoom: Vector2,
	camera_rotation: float,
	viewport_size: Vector2
) -> Vector2:
	var room_local_half_view: Vector2 = _get_camera_half_extents_in_room_space(
		camera_zoom,
		camera_rotation,
		viewport_size
	)
	var local_position: Vector2 = to_local(world_position)
	var half_room_size: Vector2 = room_size * 0.5

	if not _has_open_side(OpenSide.LEFT) and not _has_open_side(OpenSide.RIGHT):
		var minimum_x: float = -half_room_size.x + room_local_half_view.x
		var maximum_x: float = half_room_size.x - room_local_half_view.x
		local_position.x = clampf(local_position.x, minimum_x, maximum_x)
	elif not _has_open_side(OpenSide.LEFT):
		local_position.x = maxf(local_position.x, -half_room_size.x + room_local_half_view.x)
	elif not _has_open_side(OpenSide.RIGHT):
		local_position.x = minf(local_position.x, half_room_size.x - room_local_half_view.x)

	if not _has_open_side(OpenSide.TOP) and not _has_open_side(OpenSide.BOTTOM):
		var minimum_y: float = -half_room_size.y + room_local_half_view.y
		var maximum_y: float = half_room_size.y - room_local_half_view.y
		local_position.y = clampf(local_position.y, minimum_y, maximum_y)
	elif not _has_open_side(OpenSide.TOP):
		local_position.y = maxf(local_position.y, -half_room_size.y + room_local_half_view.y)
	elif not _has_open_side(OpenSide.BOTTOM):
		local_position.y = minf(local_position.y, half_room_size.y - room_local_half_view.y)

	return to_global(local_position)


## Returns true when the current camera pose already fits inside all closed sides.
## JuiceCam2D uses this to engage final hard clamping after a smooth room entry,
## avoiding an unsolicited snap to the room's nearest valid center.
func is_camera_pose_contained(
	world_position: Vector2,
	camera_zoom: Vector2,
	camera_rotation: float,
	viewport_size: Vector2
) -> bool:
	var fitted_zoom: Vector2 = constrain_zoom(camera_zoom, camera_rotation, viewport_size)
	if not fitted_zoom.is_equal_approx(camera_zoom):
		return false
	var clamped_position: Vector2 = constrain_camera_position(
		world_position,
		camera_zoom,
		camera_rotation,
		viewport_size
	)
	return clamped_position.is_equal_approx(world_position)


func _has_open_side(side: OpenSide) -> bool:
	return (open_sides & side) != 0


func _axis_has_closed_side(first_side: OpenSide, second_side: OpenSide) -> bool:
	return not (_has_open_side(first_side) and _has_open_side(second_side))


func _get_camera_half_extents_in_room_space(
	camera_zoom: Vector2,
	camera_rotation: float,
	viewport_size: Vector2
) -> Vector2:
	var safe_zoom := Vector2(
		maxf(absf(camera_zoom.x), 0.000001),
		maxf(absf(camera_zoom.y), 0.000001)
	)
	var screen_half_size: Vector2 = viewport_size / (safe_zoom * 2.0)
	var camera_right: Vector2 = Vector2.RIGHT.rotated(camera_rotation) * screen_half_size.x
	var camera_down: Vector2 = Vector2.DOWN.rotated(camera_rotation) * screen_half_size.y
	var world_to_room: Transform2D = global_transform.affine_inverse()
	var room_right: Vector2 = world_to_room.basis_xform(camera_right)
	var room_down: Vector2 = world_to_room.basis_xform(camera_down)
	return Vector2(
		absf(room_right.x) + absf(room_down.x),
		absf(room_right.y) + absf(room_down.y)
	)


func _on_camera_entered(camera: Node2D) -> void:
	emit_signal("room_entered", camera)


func _on_camera_exited(camera: Node2D) -> void:
	emit_signal("room_exited", camera)


func _draw_influence_debug() -> void:
	var half_size: Vector2 = room_size * 0.5
	var top_left: Vector2 = -half_size
	var top_right := Vector2(half_size.x, -half_size.y)
	var bottom_right: Vector2 = half_size
	var bottom_left := Vector2(-half_size.x, half_size.y)
	_draw_room_edge(top_left, bottom_left, OpenSide.LEFT)
	_draw_room_edge(top_right, bottom_right, OpenSide.RIGHT)
	_draw_room_edge(top_left, top_right, OpenSide.TOP)
	_draw_room_edge(bottom_left, bottom_right, OpenSide.BOTTOM)


func _draw_room_edge(start: Vector2, end: Vector2, side: OpenSide) -> void:
	if not _has_open_side(side):
		draw_line(start, end, DEBUG_COLOR, DEBUG_STROKE_WIDTH, false)
		return

	draw_line(start, end, OPEN_SIDE_COLOR, DEBUG_STROKE_WIDTH, false)
	var edge_direction: Vector2 = (end - start).normalized()
	var outward_direction: Vector2 = Vector2.ZERO
	match side:
		OpenSide.LEFT:
			outward_direction = Vector2.LEFT
		OpenSide.RIGHT:
			outward_direction = Vector2.RIGHT
		OpenSide.TOP:
			outward_direction = Vector2.UP
		OpenSide.BOTTOM:
			outward_direction = Vector2.DOWN
	for marker_index: int in range(3):
		var edge_point: Vector2 = start.lerp(end, float(marker_index + 1) / 4.0)
		var arrow_tip: Vector2 = edge_point + outward_direction * 15.0
		var arrow_base: Vector2 = arrow_tip - outward_direction * 8.0
		draw_line(arrow_base, arrow_tip, OPEN_SIDE_COLOR, DEBUG_STROKE_WIDTH, false)
		draw_line(
			arrow_tip,
			arrow_base + edge_direction * 4.0,
			OPEN_SIDE_COLOR,
			DEBUG_STROKE_WIDTH,
			false
		)
		draw_line(
			arrow_tip,
			arrow_base - edge_direction * 4.0,
			OPEN_SIDE_COLOR,
			DEBUG_STROKE_WIDTH,
			false
		)
