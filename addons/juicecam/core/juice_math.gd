class_name JuiceMath
extends RefCounted

## JuiceMath
## Pure, highly-optimized mathematical foundations for AAA camera motion.
## Provides framerate-independent critically damped springs, harmonic oscillators,
## and exponential decays without per-frame memory allocations.

# --- Smooth Damp (Critically Damped Spring) ---

## Smoothly dampens a scalar value towards a target using a critically damped spring.
## Returns PackedFloat32Array([new_position, new_velocity])
static func smooth_damp_scalar(
	current: float,
	target: float,
	current_velocity: float,
	smooth_time: float,
	max_speed: float,
	delta: float
) -> Array[float]:
	smooth_time = maxf(0.0001, smooth_time)
	var omega: float = 2.0 / smooth_time
	var x: float = omega * delta
	var exp_factor: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	
	var change: float = current - target
	var original_target: float = target
	
	# Clamp maximum speed
	var max_change: float = max_speed * smooth_time
	change = clampf(change, -max_change, max_change)
	target = current - change
	
	var temp: float = (current_velocity + omega * change) * delta
	var new_velocity: float = (current_velocity - omega * temp) * exp_factor
	var new_position: float = target + (change + temp) * exp_factor
	
	# Prevent overshooting target
	if (original_target - current > 0.0) == (new_position > original_target):
		new_position = original_target
		new_velocity = (new_position - original_target) / maxf(0.00001, delta)
		
	return [new_position, new_velocity]


## Smoothly dampens a Vector2 towards a target using critically damped springs per axis.
## Returns Array[Vector2]([new_position, new_velocity])
static func smooth_damp_2d(
	current: Vector2,
	target: Vector2,
	current_velocity: Vector2,
	smooth_time: float,
	max_speed: float,
	delta: float
) -> Array[Vector2]:
	var rx: Array[float] = smooth_damp_scalar(current.x, target.x, current_velocity.x, smooth_time, max_speed, delta)
	var ry: Array[float] = smooth_damp_scalar(current.y, target.y, current_velocity.y, smooth_time, max_speed, delta)
	return [Vector2(rx[0], ry[0]), Vector2(rx[1], ry[1])]


## Smoothly dampens a Vector3 towards a target using critically damped springs per axis.
## Fully reusable for JuiceCam3D.
## Returns Array[Vector3]([new_position, new_velocity])
static func smooth_damp_3d(
	current: Vector3,
	target: Vector3,
	current_velocity: Vector3,
	smooth_time: float,
	max_speed: float,
	delta: float
) -> Array[Vector3]:
	var rx: Array[float] = smooth_damp_scalar(current.x, target.x, current_velocity.x, smooth_time, max_speed, delta)
	var ry: Array[float] = smooth_damp_scalar(current.y, target.y, current_velocity.y, smooth_time, max_speed, delta)
	var rz: Array[float] = smooth_damp_scalar(current.z, target.z, current_velocity.z, smooth_time, max_speed, delta)
	return [Vector3(rx[0], ry[0], rz[0]), Vector3(rx[1], ry[1], rz[1])]


# --- Spring Damper (Exact Analytic Harmonic Oscillator) ---

## Exact analytic solution to damped harmonic oscillator:
## Handles underdamped (zeta < 1.0), critically damped (zeta == 1.0), and overdamped (zeta > 1.0)
## Unconditionally stable at any timestep delta with full zero-division and negative delta guards.
## Returns Array[float]([new_position, new_velocity])
static func spring_damper_scalar(
	current: float,
	target: float,
	velocity: float,
	frequency: float,
	damping_ratio: float,
	delta: float
) -> Array[float]:
	if delta <= 0.0 or frequency <= 0.0001:
		return [current, velocity]
		
	var omega: float = maxf(0.0001, frequency * TAU)
	var delta_x: float = current - target
	
	if damping_ratio < 0.9999: # Underdamped (bouncy)
		var discriminant: float = maxf(0.00001, 1.0 - damping_ratio * damping_ratio)
		var omega_d: float = maxf(0.00001, omega * sqrt(discriminant))
		var decay: float = exp(-damping_ratio * omega * delta)
		var c1: float = delta_x
		var c2: float = (velocity + damping_ratio * omega * delta_x) / omega_d
		var cos_term: float = cos(omega_d * delta)
		var sin_term: float = sin(omega_d * delta)
		
		var new_delta: float = decay * (c1 * cos_term + c2 * sin_term)
		var new_vel: float = decay * ((-damping_ratio * omega * c1 + omega_d * c2) * cos_term + (-damping_ratio * omega * c2 - omega_d * c1) * sin_term)
		return [target + new_delta, new_vel]
		
	elif damping_ratio > 1.0001: # Overdamped (sluggish)
		var z2: float = sqrt(maxf(0.00001, damping_ratio * damping_ratio - 1.0))
		var s1: float = -omega * (damping_ratio - z2)
		var s2: float = -omega * (damping_ratio + z2)
		var denom: float = s1 - s2
		if absf(denom) < 0.00001:
			denom = 0.00001 if denom >= 0.0 else -0.00001
			
		var c1: float = (velocity - s2 * delta_x) / denom
		var c2: float = delta_x - c1
		var exp1: float = exp(s1 * delta)
		var exp2: float = exp(s2 * delta)
		
		var new_delta: float = c1 * exp1 + c2 * exp2
		var new_vel: float = c1 * s1 * exp1 + c2 * s2 * exp2
		return [target + new_delta, new_vel]
		
	else: # Critically damped (zeta == 1.0)
		var decay: float = exp(-omega * delta)
		var c1: float = delta_x
		var c2: float = velocity + omega * delta_x
		var new_delta: float = (c1 + c2 * delta) * decay
		var new_vel: float = (velocity - omega * (c1 + c2 * delta)) * decay + c2 * decay
		return [target + new_delta, new_vel]


## Vector2 spring damper using exact analytic solution.
## Returns Array[Vector2]([new_position, new_velocity])
static func spring_damper_2d(
	current: Vector2,
	target: Vector2,
	velocity: Vector2,
	frequency: float,
	damping_ratio: float,
	delta: float
) -> Array[Vector2]:
	var rx: Array[float] = spring_damper_scalar(current.x, target.x, velocity.x, frequency, damping_ratio, delta)
	var ry: Array[float] = spring_damper_scalar(current.y, target.y, velocity.y, frequency, damping_ratio, delta)
	return [Vector2(rx[0], ry[0]), Vector2(rx[1], ry[1])]


## Vector3 spring damper using exact analytic solution.
## Fully reusable for JuiceCam3D.
## Returns Array[Vector3]([new_position, new_velocity])
static func spring_damper_3d(
	current: Vector3,
	target: Vector3,
	velocity: Vector3,
	frequency: float,
	damping_ratio: float,
	delta: float
) -> Array[Vector3]:
	var rx: Array[float] = spring_damper_scalar(current.x, target.x, velocity.x, frequency, damping_ratio, delta)
	var ry: Array[float] = spring_damper_scalar(current.y, target.y, velocity.y, frequency, damping_ratio, delta)
	var rz: Array[float] = spring_damper_scalar(current.z, target.z, velocity.z, frequency, damping_ratio, delta)
	return [Vector3(rx[0], ry[0], rz[0]), Vector3(rx[1], ry[1], rz[1])]


# --- Framerate-Independent Exponential Decay ---

## Exponential decay towards target: exact solution to dx/dt = -decay_rate * (x - target).
## Guarantees identical outcome regardless of delta-time steps.
static func decay_scalar(current: float, target: float, decay_rate: float, delta: float) -> float:
	return target + (current - target) * exp(-decay_rate * delta)


## Exponential decay for Vector2.
static func decay_2d(current: Vector2, target: Vector2, decay_rate: float, delta: float) -> Vector2:
	var factor: float = exp(-decay_rate * delta)
	return target + (current - target) * factor


## Exponential decay for Vector3.
## Fully reusable for JuiceCam3D.
static func decay_3d(current: Vector3, target: Vector3, decay_rate: float, delta: float) -> Vector3:
	var factor: float = exp(-decay_rate * delta)
	return target + (current - target) * factor


## Exponential decay for 3D orientation (Quaternion).
## Uses spherical linear interpolation (slerp) with exact framerate-independent decay.
static func decay_quaternion(current: Quaternion, target: Quaternion, decay_rate: float, delta: float) -> Quaternion:
	var factor: float = 1.0 - exp(-decay_rate * delta)
	return current.slerp(target, factor)


## Exponential decay for angle (handles circular wrapping).
static func decay_angle(current: float, target: float, decay_rate: float, delta: float) -> float:
	var diff: float = wrapf(target - current, -PI, PI)
	var factor: float = 1.0 - exp(-decay_rate * delta)
	return current + diff * factor


# --- Angular Smooth Damp ---

## Smoothly dampens an angle towards a target angle along the shortest circular path.
## Handles wraparound at [-PI, PI] without discontinuity.
## Returns Array[float]([new_angle, new_velocity])
static func smooth_damp_angle(
	current: float,
	target: float,
	current_velocity: float,
	smooth_time: float,
	max_speed: float,
	delta: float
) -> Array[float]:
	var diff: float = wrapf(target - current, -PI, PI)
	var unwrapped_target: float = current + diff
	var res: Array[float] = smooth_damp_scalar(current, unwrapped_target, current_velocity, smooth_time, max_speed, delta)
	var new_angle: float = wrapf(res[0], -PI, PI)
	return [new_angle, res[1]]


# --- Filtered Predictive Look-Ahead ---

## Calculates a smooth, jitter-free lookahead offset based on target velocity.
## Employs exponential low-pass damping so sudden direction reversals or stops
## glide smoothly rather than jerking or snapping.
static func filtered_lookahead_2d(
	current_lookahead: Vector2,
	target_velocity: Vector2,
	max_lead_distance: float,
	damping: float,
	delta: float
) -> Vector2:
	var target_lookahead: Vector2 = Vector2.ZERO
	var speed: float = target_velocity.length()
	if speed > 1.0:
		var dir: Vector2 = target_velocity / speed
		# Scale lead distance with speed up to max_lead_distance
		var lead_mag: float = minf(max_lead_distance, speed * 0.5)
		target_lookahead = dir * lead_mag
		
	return decay_2d(current_lookahead, target_lookahead, damping, delta)


## 3D filtered predictive look-ahead based on target velocity.
## Fully reusable for JuiceCam3D.
static func filtered_lookahead_3d(
	current_lookahead: Vector3,
	target_velocity: Vector3,
	max_lead_distance: float,
	damping: float,
	delta: float
) -> Vector3:
	var target_lookahead: Vector3 = Vector3.ZERO
	var speed: float = target_velocity.length()
	if speed > 1.0:
		var dir: Vector3 = target_velocity / speed
		var lead_mag: float = minf(max_lead_distance, speed * 0.5)
		target_lookahead = dir * lead_mag
		
	return decay_3d(current_lookahead, target_lookahead, damping, delta)


# --- Adaptive Dual-Speed Smooth Damp ---

## Dynamically tightens smooth time when the target moves farther away or at high speeds.
## Ensures smooth camera tracking at low speeds while preventing high-speed targets
## from escaping the viewport.
static func adaptive_smooth_damp_2d(
	current: Vector2,
	target: Vector2,
	current_velocity: Vector2,
	base_smooth_time: float,
	min_smooth_time: float,
	breakaway_distance: float,
	max_speed: float,
	delta: float
) -> Array[Vector2]:
	var dist: float = current.distance_to(target)
	var factor: float = clampf(dist / maxf(1.0, breakaway_distance), 0.0, 1.0)
	var effective_smooth_time: float = lerpf(base_smooth_time, min_smooth_time, factor)
	return smooth_damp_2d(current, target, current_velocity, effective_smooth_time, max_speed, delta)


## 3D adaptive dual-speed smooth damp.
## Fully reusable for JuiceCam3D.
static func adaptive_smooth_damp_3d(
	current: Vector3,
	target: Vector3,
	current_velocity: Vector3,
	base_smooth_time: float,
	min_smooth_time: float,
	breakaway_distance: float,
	max_speed: float,
	delta: float
) -> Array[Vector3]:
	var dist: float = current.distance_to(target)
	var factor: float = clampf(dist / maxf(1.0, breakaway_distance), 0.0, 1.0)
	var effective_smooth_time: float = lerpf(base_smooth_time, min_smooth_time, factor)
	return smooth_damp_3d(current, target, current_velocity, effective_smooth_time, max_speed, delta)
