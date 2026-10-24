class_name TestJuiceFraming
extends RefCounted

const JuiceFraming = preload("res://addons/juicecam/core/juice_framing.gd")

func test_effective_radius() -> String:
	var r1: float = JuiceFraming.calculate_effective_radius(50.0, 1.0, 1.0)
	if absf(r1 - 50.0) > 0.001:
		return "Weight 1.0 should keep base radius: expected 50.0, got %f" % r1
		
	var r_low: float = JuiceFraming.calculate_effective_radius(50.0, 0.5, 1.0)
	if absf(r_low - 50.0) > 0.001:
		return "Weight 0.5 should not reduce radius below base radius: expected 50.0, got %f" % r_low
		
	var r_high: float = JuiceFraming.calculate_effective_radius(50.0, 3.0, 1.0)
	# 50 * (1 + (3 - 1) * 1) = 50 * 3 = 150
	if absf(r_high - 150.0) > 0.001:
		return "Weight 3.0 should expand radius to 150.0: got %f" % r_high
		
	return ""

func test_framing_extents_rotation_invariance() -> String:
	var targets: Array[Vector2] = [Vector2(-400.0, 0.0), Vector2(400.0, 0.0)]
	var radii: Array[float] = [50.0, 50.0]
	var weights: Array[float] = [1.0, 1.0]
	var centroid: Vector2 = Vector2.ZERO
	
	# 1. At 0 radians rotation
	var ext_0: Vector2 = JuiceFraming.calculate_framing_extents_2d(targets, radii, weights, centroid, 0.0, 1.0)
	if absf(ext_0.x - 450.0) > 0.01 or absf(ext_0.y - 50.0) > 0.01:
		return "Extents at 0 rad failed: expected (450, 50), got %s" % str(ext_0)
		
	# 2. At 90 degrees (PI / 2) rotation: targets map to local Y axis
	var ext_90: Vector2 = JuiceFraming.calculate_framing_extents_2d(targets, radii, weights, centroid, PI * 0.5, 1.0)
	if absf(ext_90.x - 50.0) > 0.01 or absf(ext_90.y - 450.0) > 0.01:
		return "Extents at PI/2 rad failed: expected (50, 450), got %s" % str(ext_90)
		
	# 3. At 45 degrees (PI / 4) rotation: symmetric projection
	var ext_45: Vector2 = JuiceFraming.calculate_framing_extents_2d(targets, radii, weights, centroid, PI * 0.25, 1.0)
	var expected_comp: float = 400.0 * cos(PI * 0.25) + 50.0
	if absf(ext_45.x - expected_comp) > 0.01 or absf(ext_45.y - expected_comp) > 0.01:
		return "Extents at PI/4 rad failed: expected (%f, %f), got %s" % [expected_comp, expected_comp, str(ext_45)]
		
	return ""

func test_autofit_zoom_2d() -> String:
	var targets: Array[Vector2] = [Vector2(-400.0, 0.0), Vector2(400.0, 0.0)]
	var radii: Array[float] = [50.0, 50.0]
	var weights: Array[float] = [1.0, 1.0]
	var centroid: Vector2 = Vector2.ZERO
	var vp: Vector2 = Vector2(1920.0, 1080.0)
	
	# Usable hw = 960 * 0.8 = 768. Usable hh = 540 * 0.8 = 432.
	# At 0 rad: extents = (450, 50). zoom_x = 768 / 450 = 1.7066. zoom_y = 432 / 50 = 8.64.
	# Uniform zoom = min(1.7066, 8.64) = 1.7066.
	var z_0: Vector2 = JuiceFraming.calculate_autofit_zoom_2d(targets, radii, weights, centroid, 0.0, vp, 0.8, 0.2, 5.0)
	var expected_z0: float = 768.0 / 450.0
	if absf(z_0.x - expected_z0) > 0.01:
		return "Autofit zoom at 0 rad failed: expected %f, got %f" % [expected_z0, z_0.x]
		
	# At PI / 2 rad: extents = (50, 450). zoom_x = 768 / 50 = 15.36. zoom_y = 432 / 450 = 0.96.
	# Uniform zoom = min(15.36, 0.96) = 0.96.
	var z_90: Vector2 = JuiceFraming.calculate_autofit_zoom_2d(targets, radii, weights, centroid, PI * 0.5, vp, 0.8, 0.2, 5.0)
	var expected_z90: float = 432.0 / 450.0
	if absf(z_90.x - expected_z90) > 0.01:
		return "Autofit zoom at PI/2 rad failed: expected %f, got %f" % [expected_z90, z_90.x]
		
	return ""

func test_weight_bias_framing() -> String:
	var targets: Array[Vector2] = [Vector2(-400.0, 0.0), Vector2(400.0, 0.0)]
	var radii: Array[float] = [50.0, 50.0]
	var weights: Array[float] = [3.0, 1.0] # Target 0 is 3x higher weight
	
	# Centroid shifted to -200: ((-400 * 3) + (400 * 1)) / 4 = -800 / 4 = -200
	var centroid: Vector2 = Vector2(-200.0, 0.0)
	var vp: Vector2 = Vector2(1920.0, 1080.0)
	
	var z: Vector2 = JuiceFraming.calculate_autofit_zoom_2d(targets, radii, weights, centroid, 0.0, vp, 0.8, 0.1, 5.0, 1.0)
	
	# Target 0 effective radius is 150. Distance to centroid = 200. hx0 = 350.
	# Target 1 effective radius is 50. Distance to centroid = 600. hx1 = 650.
	# Max hx = 650. Usable hw = 768. zoom_x = 768 / 650 = 1.1815.
	var expected_z: float = 768.0 / 650.0
	if absf(z.x - expected_z) > 0.01:
		return "Weight bias zoom failed: expected %f, got %f" % [expected_z, z.x]
		
	return ""

func test_framing_zero_division_guards() -> String:
	var empty_targets: Array[Vector2] = []
	var empty_radii: Array[float] = []
	var empty_weights: Array[float] = []
	
	var z_empty: Vector2 = JuiceFraming.calculate_autofit_zoom_2d(empty_targets, empty_radii, empty_weights, Vector2.ZERO, 0.0, Vector2(1920.0, 1080.0))
	if z_empty != Vector2.ONE:
		return "Empty targets should return Vector2.ONE: got %s" % str(z_empty)
		
	var z_zero_vp: Vector2 = JuiceFraming.calculate_autofit_zoom_2d([Vector2.ZERO], [10.0], [1.0], Vector2.ZERO, 0.0, Vector2.ZERO)
	if z_zero_vp != Vector2.ONE:
		return "Zero viewport size should return Vector2.ONE: got %s" % str(z_zero_vp)
		
	return ""
