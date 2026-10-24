@tool
@abstract
class_name JuiceCamOutputModifier2D
extends JuiceCamAddon2D

## Add-ons that contribute visual effects after the camera's base pose is solved.
## Output offsets do not feed back into tracking or camera smoothing state.

const MAX_SMOOTHING_TIME: float = 0.4


func modify_output(_frame: JuiceCamAddonFrame2D) -> void:
	pass


## Override to keep this add-on's position offset independent of room bounds.
## Global camera limits are still applied to the final rendered camera position.
func bypasses_room_clamp() -> bool:
	return false


## Smooths a scalar with the shared frame-rate-independent add-on slider response.
static func smooth_value(current: float, target: float, smoothing: float, delta: float) -> float:
	if smoothing <= 0.0:
		return target
	var smoothing_time: float = clampf(smoothing, 0.0, 1.0) * MAX_SMOOTHING_TIME
	var lerp_weight: float = 1.0 - exp(-maxf(delta, 0.0) / smoothing_time)
	return lerpf(current, target, lerp_weight)


static func smooth_vector(current: Vector2, target: Vector2, smoothing: float, delta: float) -> Vector2:
	return Vector2(
		smooth_value(current.x, target.x, smoothing, delta),
		smooth_value(current.y, target.y, smoothing, delta)
	)
