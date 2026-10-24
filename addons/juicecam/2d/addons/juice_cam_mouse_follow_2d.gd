@tool
class_name JuiceCamMouseFollow2D
extends JuiceCamOutputModifier2D

## Adds a bounded mouse-position offset to the rendered camera position.

var _smoothed_offset: Vector2 = Vector2.ZERO

@export_group("Mouse Follow")
## Maximum radial offset in camera-local world units from the solved camera position.
@export_range(0.0, 2000.0, 1.0, "or_greater", "suffix:px") var look_radius: float = 300.0:
	set(value):
		var new_value: float = maxf(0.0, value)
		if is_equal_approx(look_radius, new_value):
			return
		look_radius = new_value
		emit_changed()
## Scales the offset without changing the configured look radius.
@export_range(0.0, 1.0, 0.01) var influence: float = 1.0:
	set(value):
		var new_value: float = clampf(value, 0.0, 1.0)
		if is_equal_approx(influence, new_value):
			return
		influence = new_value
		emit_changed()
## Higher values smooth the mouse offset more. Zero follows the mouse immediately.
@export_range(0.0, 1.0, 0.01) var smoothing: float = 0.2:
	set(value):
		var new_value: float = clampf(value, 0.0, 1.0)
		if is_equal_approx(smoothing, new_value):
			return
		smoothing = new_value
		emit_changed()
## Time in seconds to blend the effective look radius when enabled changes.
@export_range(0.0, 1.0, 0.01, "suffix:s") var activation_transition_time: float = 0.3:
	set(value):
		var new_value: float = maxf(0.0, value)
		if is_equal_approx(activation_transition_time, new_value):
			return
		activation_transition_time = new_value
		emit_changed()

var _activation_weight: float = 0.0
var _transition_start_weight: float = 0.0
var _transition_target_weight: float = 0.0
var _transition_elapsed: float = 0.0
var _activation_transition_active: bool = false


func _init() -> void:
	if addon_id.is_empty():
		addon_id = "mouse_follow"


func runs_during_cinematics() -> bool:
	return false


func bypasses_room_clamp() -> bool:
	return true


func setup(_camera: Node2D) -> void:
	_smoothed_offset = Vector2.ZERO
	_activation_weight = 1.0 if enabled else 0.0
	_transition_start_weight = _activation_weight
	_transition_target_weight = _activation_weight
	_transition_elapsed = 0.0
	_activation_transition_active = false

func _on_enabled_changed(is_enabled: bool) -> void:
	var target_weight: float = 1.0 if is_enabled else 0.0
	if (
		_activation_transition_active
		and is_equal_approx(_transition_target_weight, target_weight)
	):
		return
	if is_equal_approx(_activation_weight, target_weight):
		_activation_transition_active = false
		_transition_target_weight = target_weight
		return
	if activation_transition_time <= 0.0:
		_activation_weight = target_weight
		_activation_transition_active = false
		if not is_enabled:
			_smoothed_offset = Vector2.ZERO
		return
	_transition_start_weight = _activation_weight
	_transition_target_weight = target_weight
	_transition_elapsed = 0.0
	_activation_transition_active = true


func is_active_for_processing() -> bool:
	return enabled or _activation_transition_active


func modify_output(frame: JuiceCamAddonFrame2D) -> void:
	var activation_weight: float = _advance_activation_transition(frame.delta)
	if frame.is_cinematic:
		_smoothed_offset = Vector2.ZERO
		return

	var desired_offset: Vector2 = Vector2.ZERO
	if (
		influence > 0.0
		and is_instance_valid(frame.camera)
		and frame.viewport_size.x > 0.0
		and frame.viewport_size.y > 0.0
	):
		var viewport: Viewport = frame.camera.get_viewport()
		if is_instance_valid(viewport):
			var half_viewport: Vector2 = frame.viewport_size * 0.5
			var mouse_from_center: Vector2 = viewport.get_mouse_position() - half_viewport
			var normalized_mouse: Vector2 = Vector2(
				mouse_from_center.x / half_viewport.x,
				mouse_from_center.y / half_viewport.y
			)
			var normalized_distance: float = normalized_mouse.length()
			if normalized_distance > 1.0:
				normalized_mouse /= normalized_distance
			desired_offset = normalized_mouse * look_radius * influence

	_smoothed_offset = JuiceCamOutputModifier2D.smooth_vector(
		_smoothed_offset,
		desired_offset,
		smoothing,
		frame.delta
	)

	# Blend after cursor smoothing so its residual offset cannot jump when the fade ends.
	frame.output_position_offset += _smoothed_offset * activation_weight


func _advance_activation_transition(delta: float) -> float:
	if not _activation_transition_active:
		return 1.0 if enabled else 0.0
	if activation_transition_time <= 0.0:
		_activation_weight = _transition_target_weight
		_activation_transition_active = false
		if is_zero_approx(_activation_weight):
			_smoothed_offset = Vector2.ZERO
			enabled = false
		return _activation_weight
	_transition_elapsed += maxf(delta, 0.0)
	var progress: float = clampf(_transition_elapsed / activation_transition_time, 0.0, 1.0)
	var eased_progress: float = progress * progress * (3.0 - 2.0 * progress)
	_activation_weight = lerpf(_transition_start_weight, _transition_target_weight, eased_progress)
	if progress >= 1.0:
		_activation_weight = _transition_target_weight
		_activation_transition_active = false
		if is_zero_approx(_activation_weight):
			_smoothed_offset = Vector2.ZERO
	return _activation_weight
