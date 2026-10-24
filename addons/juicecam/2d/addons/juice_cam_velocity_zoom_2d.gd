@tool
class_name JuiceCamVelocityZoom2D
extends JuiceCamOutputModifier2D

## Smoothly zooms out as the camera's weighted target speed increases.

@export_group("Velocity Zoom")
## Speed at which the zoom-out response begins, in world units per second.
@export_range(0.0, 100000.0, 10.0, "or_greater", "suffix:px/s") var start_speed: float = 300.0:
	set(value):
		var new_value: float = maxf(0.0, value)
		if is_equal_approx(start_speed, new_value):
			return
		start_speed = new_value
		if full_zoom_speed <= start_speed:
			full_zoom_speed = start_speed + 1.0
		emit_changed()

## Speed at which the maximum zoom-out amount is reached, in world units per second.
@export_range(1.0, 100000.0, 10.0, "or_greater", "suffix:px/s") var full_zoom_speed: float = 1200.0:
	set(value):
		var new_value: float = maxf(start_speed + 1.0, value)
		if is_equal_approx(full_zoom_speed, new_value):
			return
		full_zoom_speed = new_value
		emit_changed()

## Maximum amount to zoom out. 1.5x shows 1.5 times as much world width and height at full effect.
@export_range(1.0, 4.0, 0.05, "or_greater", "suffix:x") var maximum_zoom_out: float = 1.5:
	set(value):
		var new_value: float = maxf(1.0, value)
		if is_equal_approx(maximum_zoom_out, new_value):
			return
		maximum_zoom_out = new_value
		emit_changed()

## Time for the zoom-out effect to approach its requested amount.
@export_range(0.0, 3.0, 0.01, "suffix:s") var zoom_out_time: float = 0.25:
	set(value):
		var new_value: float = maxf(0.0, value)
		if is_equal_approx(zoom_out_time, new_value):
			return
		zoom_out_time = new_value
		emit_changed()

## Time for the camera to return toward its normal zoom as the target slows down.
@export_range(0.0, 3.0, 0.01, "suffix:s") var zoom_in_time: float = 0.6:
	set(value):
		var new_value: float = maxf(0.0, value)
		if is_equal_approx(zoom_in_time, new_value):
			return
		zoom_in_time = new_value
		emit_changed()

var _current_zoom_multiplier: float = 1.0


func _init() -> void:
	if addon_id.is_empty():
		addon_id = "velocity_zoom"


func setup(_camera: Node2D) -> void:
	_current_zoom_multiplier = 1.0


func exit(_camera: Node2D) -> void:
	_current_zoom_multiplier = 1.0


func runs_during_cinematics() -> bool:
	return false


func modify_output(frame: JuiceCamAddonFrame2D) -> void:
	if frame.is_cinematic:
		_current_zoom_multiplier = 1.0
		return

	var target_speed: float = frame.target_speed if frame.has_target else 0.0
	var speed_span: float = maxf(1.0, full_zoom_speed - start_speed)
	var speed_ratio: float = clampf((target_speed - start_speed) / speed_span, 0.0, 1.0)
	var eased_ratio: float = speed_ratio * speed_ratio * (3.0 - 2.0 * speed_ratio)
	var target_multiplier: float = lerpf(1.0, 1.0 / maximum_zoom_out, eased_ratio)
	var response_time: float = zoom_out_time if target_multiplier < _current_zoom_multiplier else zoom_in_time

	if frame.delta <= 0.0:
		frame.output_zoom_multiplier *= Vector2.ONE * _current_zoom_multiplier
		return
	if response_time <= 0.0:
		_current_zoom_multiplier = target_multiplier
	else:
		var blend: float = 1.0 - exp(-frame.delta / response_time)
		_current_zoom_multiplier = lerpf(_current_zoom_multiplier, target_multiplier, blend)

	frame.output_zoom_multiplier *= Vector2.ONE * _current_zoom_multiplier
