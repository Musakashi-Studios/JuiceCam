class_name TestJuiceMath
extends RefCounted

const JuiceMath = preload("res://addons/juicecam/core/juice_math.gd")

# --- Smooth Damp Tests ---

func test_smooth_damp_scalar_convergence() -> String:
	var current: float = 0.0
	var target: float = 100.0
	var vel: float = 0.0
	var smooth_time: float = 0.2
	var delta: float = 1.0 / 60.0
	
	for i in range(60):
		var res: Array[float] = JuiceMath.smooth_damp_scalar(current, target, vel, smooth_time, INF, delta)
		current = res[0]
		vel = res[1]
		if current > target + 0.001:
			return "Overshot target: current=%f, target=%f" % [current, target]
			
	if current < 98.0:
		return "Failed to converge near target: got %f" % current
	return ""

func test_smooth_damp_scalar_speed_limit() -> String:
	var current: float = 0.0
	var target: float = 1000.0
	var vel: float = 0.0
	var smooth_time: float = 0.1
	var max_speed: float = 50.0 # limit speed to 50 units/sec
	var delta: float = 0.1
	
	var res: Array[float] = JuiceMath.smooth_damp_scalar(current, target, vel, smooth_time, max_speed, delta)
	var change: float = res[0] - current
	# At max speed 50 for 0.1s, maximum allowed change cannot exceed max_speed * delta * buffer
	if change > 55.0:
		return "Speed limit failed: moved %f in 0.1s with max_speed 50" % change
	return ""

func test_smooth_damp_scalar_zero_delta() -> String:
	var res: Array[float] = JuiceMath.smooth_damp_scalar(10.0, 50.0, 5.0, 0.2, INF, 0.0)
	if res[0] != 10.0 or res[1] != 5.0:
		return "Zero delta modified position or velocity: %s" % str(res)
	return ""

func test_smooth_damp_2d() -> String:
	var current: Vector2 = Vector2.ZERO
	var target: Vector2 = Vector2(200.0, -100.0)
	var vel: Vector2 = Vector2.ZERO
	var smooth_time: float = 0.15
	var delta: float = 1.0 / 60.0
	
	for i in range(60):
		var res: Array[Vector2] = JuiceMath.smooth_damp_2d(current, target, vel, smooth_time, INF, delta)
		current = res[0]
		vel = res[1]
		
	if current.distance_to(target) > 1.0:
		return "Vector2 smooth damp failed to reach target, distance: %f" % current.distance_to(target)
	return ""

func test_smooth_damp_3d() -> String:
	var current: Vector3 = Vector3.ZERO
	var target: Vector3 = Vector3(10.0, 20.0, -15.0)
	var vel: Vector3 = Vector3.ZERO
	var smooth_time: float = 0.2
	var delta: float = 1.0 / 60.0
	
	for i in range(60):
		var res: Array[Vector3] = JuiceMath.smooth_damp_3d(current, target, vel, smooth_time, INF, delta)
		current = res[0]
		vel = res[1]
		
	if current.distance_to(target) > 0.2:
		return "Vector3 smooth damp failed to reach target, distance: %f" % current.distance_to(target)
	return ""

# --- Spring Damper Tests ---

func test_spring_damper_scalar_modes() -> String:
	var target: float = 100.0
	var delta: float = 1.0 / 60.0
	
	# 1. Underdamped (zeta = 0.5) - should oscillate and settle
	var p_under: float = 0.0
	var v_under: float = 0.0
	var max_overshoot: float = 0.0
	for i in range(120):
		var res_u: Array[float] = JuiceMath.spring_damper_scalar(p_under, target, v_under, 4.0, 0.5, delta)
		p_under = res_u[0]
		v_under = res_u[1]
		if p_under > target:
			max_overshoot = maxf(max_overshoot, p_under - target)
			
	if max_overshoot <= 0.01:
		return "Underdamped spring did not exhibit characteristic bounce overshoot"
	if absf(p_under - target) > 0.1:
		return "Underdamped spring did not converge after 2s: got %f" % p_under
		
	# 2. Critically damped (zeta = 1.0) - fast convergence, no overshoot
	var p_crit: float = 0.0
	var v_crit: float = 0.0
	for i in range(60):
		var res_c: Array[float] = JuiceMath.spring_damper_scalar(p_crit, target, v_crit, 8.0, 1.0, delta)
		p_crit = res_c[0]
		v_crit = res_c[1]
	if absf(p_crit - target) > 0.1:
		return "Critically damped spring did not converge: got %f" % p_crit
		
	# 3. Overdamped (zeta = 1.6) - slower, no overshoot
	var p_over: float = 0.0
	var v_over: float = 0.0
	for i in range(60):
		var res_o: Array[float] = JuiceMath.spring_damper_scalar(p_over, target, v_over, 4.0, 1.6, delta)
		p_over = res_o[0]
		v_over = res_o[1]
		if p_over > target + 0.001:
			return "Overdamped spring overshot target!"
	if p_over < 80.0:
		return "Overdamped spring was too sluggish: got %f" % p_over
		
	return ""

func test_spring_damper_2d() -> String:
	var current: Vector2 = Vector2.ZERO
	var target: Vector2 = Vector2(50.0, 50.0)
	var vel: Vector2 = Vector2.ZERO
	var frequency: float = 12.0
	var damping_ratio: float = 1.0
	var delta: float = 1.0 / 60.0
	
	for i in range(60):
		var res: Array[Vector2] = JuiceMath.spring_damper_2d(current, target, vel, frequency, damping_ratio, delta)
		current = res[0]
		vel = res[1]
		
	if current.distance_to(target) > 0.1:
		return "Spring damper 2d failed to settle on target, distance: %f" % current.distance_to(target)
	return ""

func test_spring_damper_3d() -> String:
	var current: Vector3 = Vector3.ZERO
	var target: Vector3 = Vector3(100.0, 50.0, -50.0)
	var vel: Vector3 = Vector3.ZERO
	var frequency: float = 10.0
	var damping_ratio: float = 1.0
	var delta: float = 1.0 / 60.0
	
	for i in range(60):
		var res: Array[Vector3] = JuiceMath.spring_damper_3d(current, target, vel, frequency, damping_ratio, delta)
		current = res[0]
		vel = res[1]
		
	if current.distance_to(target) > 0.1:
		return "Vector3 spring damper failed to settle, distance: %f" % current.distance_to(target)
	return ""

# --- Exponential Decay Tests ---

func test_decay_scalar() -> String:
	var start: float = 0.0
	var target: float = 100.0
	var rate: float = 5.0
	
	var a: float = JuiceMath.decay_scalar(start, target, rate, 0.1)
	var b: float = start
	for i in range(10):
		b = JuiceMath.decay_scalar(b, target, rate, 0.01)
		
	if absf(a - b) > 0.001:
		return "Scalar decay failed framerate invariance: diff=%f" % absf(a - b)
	return ""

func test_decay_2d_framerate_invariance() -> String:
	var start: Vector2 = Vector2(0.0, 0.0)
	var target: Vector2 = Vector2(100.0, 100.0)
	var decay_rate: float = 5.0
	
	var pos_a: Vector2 = JuiceMath.decay_2d(start, target, decay_rate, 0.1)
	var pos_b: Vector2 = start
	for i in range(10):
		pos_b = JuiceMath.decay_2d(pos_b, target, decay_rate, 0.01)
		
	if pos_a.distance_to(pos_b) > 0.001:
		return "Decay 2d is not framerate invariant! diff=%f" % pos_a.distance_to(pos_b)
	return ""

func test_decay_3d() -> String:
	var start: Vector3 = Vector3.ZERO
	var target: Vector3 = Vector3(10.0, 20.0, 30.0)
	var rate: float = 4.0
	
	var pos_a: Vector3 = JuiceMath.decay_3d(start, target, rate, 0.1)
	var pos_b: Vector3 = start
	for i in range(10):
		pos_b = JuiceMath.decay_3d(pos_b, target, rate, 0.01)
		
	if pos_a.distance_to(pos_b) > 0.001:
		return "Vector3 decay is not framerate invariant! diff: %f" % pos_a.distance_to(pos_b)
	return ""

func test_decay_angle() -> String:
	var from_angle: float = deg_to_rad(175.0)
	var to_angle: float = deg_to_rad(-175.0)
	var rate: float = 5.0
	
	var stepped: float = JuiceMath.decay_angle(from_angle, to_angle, rate, 0.1)
	var diff: float = absf(wrapf(stepped - to_angle, -PI, PI))
	var original_diff: float = absf(wrapf(from_angle - to_angle, -PI, PI))
	if diff >= original_diff:
		return "decay_angle did not move closer along shortest path: diff=%f, orig=%f" % [diff, original_diff]
	return ""

func test_decay_quaternion() -> String:
	var q_from: Quaternion = Quaternion.IDENTITY
	var q_to: Quaternion = Quaternion(Vector3.UP, deg_to_rad(90.0))
	var rate: float = 8.0
	
	var q_step: Quaternion = JuiceMath.decay_quaternion(q_from, q_to, rate, 0.5)
	var dot: float = absf(q_step.dot(q_to))
	if dot < 0.95:
		return "Quaternion decay did not converge towards target: dot=%f" % dot
	return ""

func test_smooth_damp_angle_wrapping() -> String:
	var current: float = deg_to_rad(170.0)
	var target: float = deg_to_rad(-170.0)
	var vel: float = 0.0
	var smooth_time: float = 0.1
	var delta: float = 1.0 / 60.0
	
	for i in range(30):
		var res: Array[float] = JuiceMath.smooth_damp_angle(current, target, vel, smooth_time, INF, delta)
		current = res[0]
		vel = res[1]
		
	var diff: float = absf(wrapf(current - target, -PI, PI))
	if diff > 0.05:
		return "Angle smooth damp failed shortest wrap! diff: %f" % diff
	return ""

# --- Look-Ahead & Adaptive Damping Tests ---

func test_filtered_lookahead_2d() -> String:
	var lookahead: Vector2 = Vector2.ZERO
	var target_vel: Vector2 = Vector2(300.0, 0.0)
	var max_lead: float = 100.0
	var damping: float = 5.0
	var delta: float = 1.0 / 60.0
	
	for i in range(60):
		lookahead = JuiceMath.filtered_lookahead_2d(lookahead, target_vel, max_lead, damping, delta)
		
	if absf(lookahead.x - 100.0) > 2.0 or absf(lookahead.y) > 0.1:
		return "Lookahead 2D failed to converge to lead distance: got %s" % str(lookahead)
	return ""

func test_filtered_lookahead_3d() -> String:
	var lookahead: Vector3 = Vector3.ZERO
	var target_vel: Vector3 = Vector3(0.0, 0.0, -400.0)
	var max_lead: float = 80.0
	var damping: float = 5.0
	var delta: float = 1.0 / 60.0
	
	for i in range(60):
		lookahead = JuiceMath.filtered_lookahead_3d(lookahead, target_vel, max_lead, damping, delta)
		
	if absf(lookahead.z - (-80.0)) > 2.0 or absf(lookahead.x) > 0.1:
		return "Lookahead 3D failed to converge: got %s" % str(lookahead)
	return ""

func test_adaptive_smooth_damp_2d() -> String:
	var pos_near: Vector2 = Vector2(5.0, 0.0)
	var target_near: Vector2 = Vector2.ZERO
	var vel_near: Vector2 = Vector2.ZERO
	
	var pos_far: Vector2 = Vector2(500.0, 0.0)
	var target_far: Vector2 = Vector2.ZERO
	var vel_far: Vector2 = Vector2.ZERO
	
	var base_time: float = 0.4
	var min_time: float = 0.05
	var breakaway: float = 200.0
	var delta: float = 1.0 / 60.0
	
	var res_near: Array[Vector2] = JuiceMath.adaptive_smooth_damp_2d(pos_near, target_near, vel_near, base_time, min_time, breakaway, INF, delta)
	var res_far: Array[Vector2] = JuiceMath.adaptive_smooth_damp_2d(pos_far, target_far, vel_far, base_time, min_time, breakaway, INF, delta)
	
	# The far target should move a much higher percentage of its distance in the first step due to tighter damping
	var pct_near: float = (pos_near.x - res_near[0].x) / pos_near.x
	var pct_far: float = (pos_far.x - res_far[0].x) / pos_far.x
	
	if pct_far <= pct_near:
		return "Adaptive damp did not tighten smooth time for far distance! pct_near=%f, pct_far=%f" % [pct_near, pct_far]
	return ""

func test_adaptive_smooth_damp_3d() -> String:
	var pos_near: Vector3 = Vector3(5.0, 0.0, 0.0)
	var pos_far: Vector3 = Vector3(500.0, 0.0, 0.0)
	var delta: float = 1.0 / 60.0
	
	var res_near: Array[Vector3] = JuiceMath.adaptive_smooth_damp_3d(pos_near, Vector3.ZERO, Vector3.ZERO, 0.4, 0.05, 200.0, INF, delta)
	var res_far: Array[Vector3] = JuiceMath.adaptive_smooth_damp_3d(pos_far, Vector3.ZERO, Vector3.ZERO, 0.4, 0.05, 200.0, INF, delta)
	
	var pct_near: float = (pos_near.x - res_near[0].x) / pos_near.x
	var pct_far: float = (pos_far.x - res_far[0].x) / pos_far.x
	
	if pct_far <= pct_near:
		return "Adaptive damp 3D did not tighten smooth time for far distance!"
	return ""
