@tool
@icon("res://addons/juicecam/icons/juice_cam_magnet_2d.png")
class_name JuiceCamMagnet2D
extends "res://addons/juicecam/2d/juice_cam_influence_2d.gd"

## World-space region that attracts or repels a camera's tracking focus.

enum MagnetShape {
	CIRCLE,
	RECTANGLE,
}

enum AttractRepel {
	ATTRACT,
	REPEL,
}

const DEBUG_COLOR: Color = JuiceCamDebugPalette2D.MAGNET

signal magnet_entered(camera: Node2D)
signal magnet_exited(camera: Node2D)

@export_group("Magnet Area")
## Shape used to decide when the camera's tracking focus is inside this region.
@export var magnet_shape: MagnetShape = MagnetShape.CIRCLE:
	set(value):
		if magnet_shape == value:
			return
		magnet_shape = value
		notify_property_list_changed()
		_influence_shape_changed()
## Whether the magnet attracts the focus to its center or pushes it to the region edge.
@export var attract_repel: AttractRepel = AttractRepel.ATTRACT

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

@export_group("Force")
## Snap directly to the center or boundary instead of applying a falloff-scaled pull.
@export var use_full_force: bool = true:
	set(value):
		if use_full_force == value:
			return
		use_full_force = value
		notify_property_list_changed()

## Maximum local-space offset per axis. Falloff scales it each update; movement is not accumulated.
@export var force: Vector2 = Vector2(100.0, 100.0)

## Falloff from the center (1) to the edge (0) of the region.
@export var falloff_curve: Curve


func _init() -> void:
	falloff_curve = Curve.new()
	falloff_curve.add_point(Vector2(0.0, 1.0))
	falloff_curve.add_point(Vector2(1.0, 0.0))


func _validate_property(property: Dictionary) -> void:
	if property.name == &"radius" and magnet_shape != MagnetShape.CIRCLE:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif property.name == &"rectangle_size" and magnet_shape != MagnetShape.RECTANGLE:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif property.name in [&"force", &"falloff_curve"] and use_full_force:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func get_influence_local_rect() -> Rect2:
	if magnet_shape == MagnetShape.CIRCLE:
		return Rect2(Vector2(-radius, -radius), Vector2.ONE * radius * 2.0)
	return Rect2(-rectangle_size * 0.5, rectangle_size)


func contains_world_point(world_position: Vector2) -> bool:
	var local_position: Vector2 = to_local(world_position)
	if magnet_shape == MagnetShape.CIRCLE:
		return local_position.length_squared() <= radius * radius
	var half_size: Vector2 = rectangle_size * 0.5
	return absf(local_position.x) <= half_size.x and absf(local_position.y) <= half_size.y


## Applies this magnet's force to a camera focus already tested for overlap.
func apply_magnet(camera: Node2D, world_position: Vector2) -> Vector2:
	if not is_camera_inside(camera):
		return world_position
	var local_position: Vector2 = to_local(world_position)
	if magnet_shape == MagnetShape.CIRCLE:
		return _apply_circle_force(world_position, local_position)
	return _apply_rectangle_force(local_position)


func _apply_circle_force(world_position: Vector2, local_position: Vector2) -> Vector2:
	var distance: float = local_position.length()
	if attract_repel == AttractRepel.ATTRACT and use_full_force:
		return global_position
	if attract_repel == AttractRepel.REPEL and use_full_force:
		var direction: Vector2 = local_position / distance if distance > 0.00001 else Vector2.RIGHT
		return to_global(direction * radius)

	var normalized_distance: float = clampf(distance / radius, 0.0, 1.0)
	var step_scale: float = _sample_falloff(normalized_distance)
	var local_direction: Vector2
	if attract_repel == AttractRepel.ATTRACT:
		local_direction = -local_position
	else:
		local_direction = local_position
		if distance <= 0.00001:
			local_direction = Vector2.RIGHT if absf(force.x) >= absf(force.y) else Vector2.DOWN
	var max_step: Vector2 = Vector2(absf(force.x), absf(force.y)) * step_scale
	var axis_step: Vector2 = Vector2(
		signf(local_direction.x) * minf(max_step.x, absf(local_position.x)),
		signf(local_direction.y) * minf(max_step.y, absf(local_position.y))
	)
	if attract_repel == AttractRepel.REPEL and distance <= 0.00001:
		axis_step = local_direction.normalized() * max_step
	var next_position: Vector2 = local_position + axis_step
	if attract_repel == AttractRepel.REPEL and next_position.length() > radius:
		next_position = next_position.normalized() * radius
	if axis_step.is_zero_approx():
		return world_position
	return to_global(next_position)


func _apply_rectangle_force(local_position: Vector2) -> Vector2:
	var half_size: Vector2 = rectangle_size * 0.5
	var normalized_position: Vector2 = Vector2(
		local_position.x / half_size.x,
		local_position.y / half_size.y
	)
	var distance_factor: float = clampf(
		maxf(absf(normalized_position.x), absf(normalized_position.y)),
		0.0,
		1.0
	)
	if attract_repel == AttractRepel.ATTRACT and use_full_force:
		return global_position
	if attract_repel == AttractRepel.REPEL and use_full_force:
		return to_global(_closest_edge_point(local_position, half_size))

	var step_scale: float = _sample_falloff(distance_factor)
	var next_position: Vector2 = local_position
	if attract_repel == AttractRepel.ATTRACT:
		next_position.x -= signf(local_position.x) * minf(absf(force.x) * step_scale, absf(local_position.x))
		next_position.y -= signf(local_position.y) * minf(absf(force.y) * step_scale, absf(local_position.y))
	else:
		var x_ratio: float = absf(normalized_position.x)
		var y_ratio: float = absf(normalized_position.y)
		if x_ratio > y_ratio:
			var x_direction: float = signf(local_position.x)
			if is_zero_approx(x_direction):
				x_direction = 1.0
			var x_step: float = minf(absf(force.x) * step_scale, half_size.x - absf(local_position.x))
			next_position.x += x_direction * maxf(0.0, x_step)
		elif x_ratio == 0.0 and y_ratio == 0.0:
			var y_step: float = minf(absf(force.y) * step_scale, half_size.y)
			next_position.y -= maxf(0.0, y_step)
		else:
			var y_direction: float = signf(local_position.y)
			if is_zero_approx(y_direction):
				y_direction = 1.0
			var y_step: float = minf(absf(force.y) * step_scale, half_size.y - absf(local_position.y))
			next_position.y += y_direction * maxf(0.0, y_step)
	if next_position == local_position:
		return to_global(local_position)
	return to_global(next_position)


func _closest_edge_point(local_position: Vector2, half_size: Vector2) -> Vector2:
	var x_ratio: float = absf(local_position.x / half_size.x)
	var y_ratio: float = absf(local_position.y / half_size.y)
	if x_ratio == 0.0 and y_ratio == 0.0:
		return Vector2(0.0, -half_size.y)
	if x_ratio > y_ratio:
		return Vector2(
			signf(local_position.x) * half_size.x,
			clampf(local_position.y, -half_size.y, half_size.y)
	)
	return Vector2(
		clampf(local_position.x, -half_size.x, half_size.x),
		signf(local_position.y) * half_size.y
	)


func _sample_falloff(distance_factor: float) -> float:
	if falloff_curve == null:
		return 1.0 - clampf(distance_factor, 0.0, 1.0)
	return maxf(0.0, falloff_curve.sample_baked(clampf(distance_factor, 0.0, 1.0)))


func _on_camera_entered(camera: Node2D) -> void:
	emit_signal("magnet_entered", camera)


func _on_camera_exited(camera: Node2D) -> void:
	emit_signal("magnet_exited", camera)


func _draw_influence_debug() -> void:
	if magnet_shape == MagnetShape.CIRCLE:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, DEBUG_COLOR, DEBUG_STROKE_WIDTH, false)
	else:
		draw_rect(Rect2(-rectangle_size * 0.5, rectangle_size), DEBUG_COLOR, false, DEBUG_STROKE_WIDTH, false)
	draw_circle(Vector2.ZERO, 5.0, DEBUG_COLOR)
