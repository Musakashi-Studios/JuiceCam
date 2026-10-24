class_name JuiceFraming
extends RefCounted

## JuiceFraming
## Math engine for rotation-invariant multi-target auto-framing and dynamic zoom calculation.
## Transforms target bounding envelopes into camera local space to compute precise screen-fitting zoom.

const MIN_ZOOM: float = 0.001


## Calculates a target's effective framing radius scaled by weight.
## High-weight targets (> 1.0) receive expanded clearance beyond their base radius.
static func calculate_effective_radius(base_radius: float, weight: float, weight_space_factor: float = 1.0) -> float:
	var r: float = maxf(0.0, base_radius)
	var w: float = maxf(0.0, weight)
	var factor: float = maxf(0.0, weight_space_factor)
	if w > 1.0:
		return r * (1.0 + (w - 1.0) * factor)
	return r


## Calculates the required half-extents in camera-local space to encompass all targets.
## Positions are transformed relative to the centroid and rotated by -camera_rotation.
## Returns Vector2(half_width, half_height) in camera local units.
static func calculate_framing_extents_2d(
	target_positions: Array[Vector2],
	target_radii: Array[float],
	target_weights: Array[float],
	centroid: Vector2,
	camera_rotation: float,
	weight_space_factor: float = 1.0
) -> Vector2:
	if target_positions.is_empty():
		return Vector2(1.0, 1.0)
		
	var max_hx: float = 0.001
	var max_hy: float = 0.001
	var count: int = target_positions.size()
	
	for i: int in range(count):
		var pos: Vector2 = target_positions[i]
		var radius: float = target_radii[i] if i < target_radii.size() else 32.0
		var weight: float = target_weights[i] if i < target_weights.size() else 1.0
		
		var effective_r: float = calculate_effective_radius(radius, weight, weight_space_factor)
		var rel_pos: Vector2 = (pos - centroid).rotated(-camera_rotation)
		
		var hx: float = absf(rel_pos.x) + effective_r
		var hy: float = absf(rel_pos.y) + effective_r
		
		if hx > max_hx:
			max_hx = hx
		if hy > max_hy:
			max_hy = hy
			
	return Vector2(max_hx, max_hy)


## Computes the optimal camera zoom to frame all targets comfortably within the viewport.
## Invariant to camera rotation: accounts for screen aspect ratio and margin padding.
static func calculate_autofit_zoom_2d(
	target_positions: Array[Vector2],
	target_radii: Array[float],
	target_weights: Array[float],
	centroid: Vector2,
	camera_rotation: float,
	viewport_size: Vector2,
	margin_factor: float = 0.8,
	min_zoom: float = 0.2,
	max_zoom: float = 1.0,
	weight_space_factor: float = 1.0
) -> Vector2:
	if target_positions.is_empty() or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2.ONE
		
	var extents: Vector2 = calculate_framing_extents_2d(
		target_positions,
		target_radii,
		target_weights,
		centroid,
		camera_rotation,
		weight_space_factor
	)
	
	var margin: float = clampf(margin_factor, 0.1, 1.0)
	var usable_half_width: float = (viewport_size.x * 0.5) * margin
	var usable_half_height: float = (viewport_size.y * 0.5) * margin
	
	var zoom_x: float = usable_half_width / maxf(0.001, extents.x)
	var zoom_y: float = usable_half_height / maxf(0.001, extents.y)
	
	var target_zoom_scalar: float = minf(zoom_x, zoom_y)
	var lower_bound: float = maxf(MIN_ZOOM, min_zoom)
	var upper_bound: float = maxf(lower_bound, max_zoom)
	var clamped_scalar: float = clampf(target_zoom_scalar, lower_bound, upper_bound)
	
	return Vector2(clamped_scalar, clamped_scalar)


## 3D camera-local framing extents calculation for JuiceCam3D.
## Projects targets into camera local space using the camera's Basis.
## Returns Vector3(half_width, half_height, half_depth).
static func calculate_framing_extents_3d(
	target_positions: Array[Vector3],
	target_radii: Array[float],
	target_weights: Array[float],
	centroid: Vector3,
	camera_basis: Basis,
	weight_space_factor: float = 1.0
) -> Vector3:
	if target_positions.is_empty():
		return Vector3(1.0, 1.0, 1.0)
		
	var max_hx: float = 0.001
	var max_hy: float = 0.001
	var max_hz: float = 0.001
	var count: int = target_positions.size()
	var inv_basis: Basis = camera_basis.inverse()
	
	for i: int in range(count):
		var pos: Vector3 = target_positions[i]
		var radius: float = target_radii[i] if i < target_radii.size() else 1.0
		var weight: float = target_weights[i] if i < target_weights.size() else 1.0
		
		var effective_r: float = calculate_effective_radius(radius, weight, weight_space_factor)
		var rel_pos: Vector3 = inv_basis * (pos - centroid)
		
		var hx: float = absf(rel_pos.x) + effective_r
		var hy: float = absf(rel_pos.y) + effective_r
		var hz: float = absf(rel_pos.z) + effective_r
		
		if hx > max_hx:
			max_hx = hx
		if hy > max_hy:
			max_hy = hy
		if hz > max_hz:
			max_hz = hz
			
	return Vector3(max_hx, max_hy, max_hz)
