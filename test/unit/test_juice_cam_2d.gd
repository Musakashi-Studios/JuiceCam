class_name TestJuiceCam2D
extends RefCounted

const JuiceCam2DScript = preload("res://addons/juicecam/2d/juice_cam_2d.gd")
const ScreenShakeAddonScript = preload("res://addons/juicecam/2d/addons/juice_cam_screen_shake_2d.gd")

func test_instantiation() -> String:
	var cam: JuiceCam2D = JuiceCam2DScript.new()
	if cam == null:
		return "Failed to instantiate JuiceCam2D"
		
	if not (cam is Node2D):
		cam.free()
		return "JuiceCam2D must inherit from Node2D"
		
	cam.free()
	return ""

func test_internal_camera_creation_and_ownership() -> String:
	var root: Node2D = Node2D.new()
	var cam: JuiceCam2D = JuiceCam2DScript.new()
	root.add_child(cam)
	
	var internal_cam: Camera2D = cam.get_internal_camera()
	if internal_cam == null:
		root.free()
		return "Internal Camera2D was not created"
		
	if internal_cam.owner != null:
		root.free()
		return "Internal Camera2D owner must remain null so it is not saved into scene files"
		
	if internal_cam.get_parent() != cam:
		root.free()
		return "Internal Camera2D must be a child of JuiceCam2D"
		
	root.remove_child(cam)
	cam.free()
	root.free()
	
	if is_instance_valid(internal_cam):
		return "Internal Camera2D was not properly freed when JuiceCam2D was removed"
		
	return ""

func test_subviewport_cameras_keep_independent_targets() -> String:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return "Test requires an active SceneTree"
	var root: Node = Node.new()
	var left_viewport: SubViewport = SubViewport.new()
	var right_viewport: SubViewport = SubViewport.new()
	var left_camera: JuiceCam2D = JuiceCam2DScript.new()
	var right_camera: JuiceCam2D = JuiceCam2DScript.new()
	var left_target: Node2D = Node2D.new()
	var right_target: Node2D = Node2D.new()
	scene_tree.root.add_child(root)
	root.add_child(left_viewport)
	root.add_child(right_viewport)
	left_viewport.size = Vector2i(640, 360)
	right_viewport.size = Vector2i(640, 360)
	left_viewport.add_child(left_camera)
	right_viewport.add_child(right_camera)
	left_viewport.add_child(left_target)
	right_viewport.add_child(right_target)
	left_camera.add_target(left_target)
	right_camera.add_target(right_target)

	var left_internal_camera: Camera2D = left_camera.get_internal_camera()
	var right_internal_camera: Camera2D = right_camera.get_internal_camera()
	if left_internal_camera.get_parent() != left_camera or right_internal_camera.get_parent() != right_camera:
		root.queue_free()
		return "Each internal Camera2D must remain a child of its JuiceCam2D owner"
	if left_internal_camera.get_viewport() != left_viewport or right_internal_camera.get_viewport() != right_viewport:
		root.queue_free()
		return "Each internal Camera2D must use its nearest parent SubViewport"
	if left_camera.has_target(right_target) or right_camera.has_target(left_target):
		root.queue_free()
		return "Each JuiceCam2D must keep its own target set"
		
	root.queue_free()
	return ""


func test_addon_configuration_connections_follow_camera_tree() -> String:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return "Test requires an active SceneTree"
	var camera: JuiceCam2D = JuiceCam2DScript.new()
	var addon: JuiceCamAddon2D = ScreenShakeAddonScript.new() as JuiceCamAddon2D
	camera.addons = [addon]
	scene_tree.root.add_child(camera)
	var changed_callback := Callable(camera, "_on_addon_config_changed")
	if not addon.changed.is_connected(changed_callback):
		scene_tree.root.remove_child(camera)
		camera.free()
		return "Camera did not connect to its add-on configuration while entering the tree"

	scene_tree.root.remove_child(camera)
	if addon.changed.is_connected(changed_callback):
		camera.free()
		return "Camera retained an add-on resource connection after leaving the tree"

	scene_tree.root.add_child(camera)
	if not addon.changed.is_connected(changed_callback):
		scene_tree.root.remove_child(camera)
		camera.free()
		return "Camera did not restore its add-on configuration connection on re-entry"

	scene_tree.root.remove_child(camera)
	camera.free()
	return ""

func test_instant_and_smooth_motion() -> String:
	var root: Node2D = Node2D.new()
	var target_node: Node2D = Node2D.new()
	target_node.global_position = Vector2(200.0, 100.0)
	var cam: JuiceCam2D = JuiceCam2DScript.new()
	cam.global_position = Vector2.ZERO
	root.add_child(target_node)
	root.add_child(cam)
	
	cam.set_primary_target(target_node)
	
	# 1. Instant tracking (smooth_motion = false)
	cam.smooth_motion = false
	cam.update_camera_motion(1.0 / 60.0)
	if cam.global_position != target_node.global_position:
		root.free()
		return "Instant tracking failed: expected %s, got %s" % [str(target_node.global_position), str(cam.global_position)]
		
	# Reset position
	cam.global_position = Vector2.ZERO
	
	# 2. Smooth tracking (smooth_motion = true)
	cam.smooth_motion = true
	cam.damping_type = JuiceCam2D.DampingType.SMOOTH_DAMP
	cam.smooth_time = 0.2
	cam.update_camera_motion(1.0 / 60.0)
	
	# In 1 frame (1/60s) of smooth damping, camera should move partially towards target
	if cam.global_position.x <= 0.0 or cam.global_position.x >= target_node.global_position.x:
		root.free()
		return "Smooth tracking failed: position did not interpolate correctly: %s" % str(cam.global_position)
		
	root.free()
	return ""

func test_smooth_and_instant_rotation() -> String:
	var root: Node2D = Node2D.new()
	var target_node: Node2D = Node2D.new()
	target_node.global_rotation = deg_to_rad(90.0)
	var cam: JuiceCam2D = JuiceCam2DScript.new()
	cam.global_rotation = 0.0
	root.add_child(target_node)
	root.add_child(cam)
	
	cam.set_primary_target(target_node)
	cam.allow_rotation = true
	
	# 1. Instant rotation
	cam.smooth_rotation = false
	cam.update_camera_motion(1.0 / 60.0)
	if absf(cam.global_rotation - deg_to_rad(90.0)) > 0.01:
		root.free()
		return "Instant rotation failed: expected PI/2, got %f" % cam.global_rotation
		
	# Reset rotation
	cam.global_rotation = 0.0
	
	# 2. Smooth rotation
	cam.smooth_rotation = true
	cam.smooth_rotation_time = 0.2
	cam.update_camera_motion(1.0 / 60.0)
	
	if cam.global_rotation <= 0.0 or cam.global_rotation >= deg_to_rad(90.0):
		root.free()
		return "Smooth rotation did not interpolate correctly: %f" % cam.global_rotation
		
	root.free()
	return ""

func test_smooth_and_instant_zoom() -> String:
	var root: Node2D = Node2D.new()
	var cam: JuiceCam2D = JuiceCam2DScript.new()
	root.add_child(cam)
	var target_node: Node2D = Node2D.new()
	root.add_child(target_node)
	cam.add_target(target_node)
	
	cam.zoom = Vector2(2.0, 2.0)
	
	# 1. Instant zoom
	cam.smooth_zoom = false
	cam.update_camera_motion(1.0 / 60.0)
	if cam.get_current_zoom() != Vector2(2.0, 2.0):
		root.free()
		return "Instant zoom failed: expected (2, 2), got %s" % str(cam.get_current_zoom())
		
	# Reset zoom
	cam.teleport_to_target() # resets to 2.0
	cam.zoom = Vector2(1.0, 1.0)
	
	# 2. Smooth zoom
	cam.smooth_zoom = true
	cam.smooth_zoom_time = 0.2
	cam.update_camera_motion(1.0 / 60.0)
	
	var cur_z: Vector2 = cam.get_current_zoom()
	if cur_z.x >= 2.0 or cur_z.x <= 1.0:
		root.free()
		return "Smooth zoom did not interpolate correctly: %s" % str(cur_z)
		
	root.free()
	return ""

func test_zoom_zero_clamping_and_nil_guard() -> String:
	var root: Node2D = Node2D.new()
	var cam: JuiceCam2D = JuiceCam2DScript.new()
	root.add_child(cam)
	
	# 1. Clamping Vector2.ZERO
	cam.zoom = Vector2.ZERO
	var z1: Vector2 = cam.zoom
	if z1.x < JuiceCam2D.MIN_ZOOM or z1.y < JuiceCam2D.MIN_ZOOM:
		root.free()
		return "Zoom did not clamp Vector2.ZERO to at least MIN_ZOOM: got %s" % str(z1)
		
	# 2. Clamping near-zero and negative values
	cam.zoom = Vector2(-0.00001, 0.00001)
	var z2: Vector2 = cam.zoom
	if absf(z2.x) < JuiceCam2D.MIN_ZOOM or absf(z2.y) < JuiceCam2D.MIN_ZOOM:
		root.free()
		return "Near-zero zoom was not clamped to MIN_ZOOM: got %s" % str(z2)
		
	# 3. Static helper clamp_zoom
	var clamped_zero: Vector2 = JuiceCam2D.clamp_zoom(Vector2.ZERO)
	if clamped_zero.x < JuiceCam2D.MIN_ZOOM or clamped_zero.y < JuiceCam2D.MIN_ZOOM:
		root.free()
		return "JuiceCam2D.clamp_zoom(Vector2.ZERO) failed: got %s" % str(clamped_zero)
		
	# 4. Internal camera sync verification
	cam.update_camera_motion(0.1)
	var int_cam: Camera2D = cam.get_internal_camera()
	var z_cam: Vector2 = int_cam.zoom
	if z_cam.x == 0.0 or z_cam.y == 0.0:
		root.free()
		return "Internal Camera2D zoom was synced to zero: %s" % str(z_cam)
		
	root.free()
	return ""

func test_zero_weight_targets_freeze_camera_and_freed_targets_are_ignored() -> String:
	var root: Node2D = Node2D.new()
	var cam: JuiceCam2D = JuiceCam2DScript.new()
	root.add_child(cam)
	
	# 1. Single target with 0 weight
	var t1: Node2D = Node2D.new()
	t1.global_position = Vector2(100.0, 50.0)
	root.add_child(t1)
	cam.add_target(t1, 0.0)
	
	var centroid: Vector2 = cam.calculate_target_centroid()
	var initial_camera_position: Vector2 = cam.global_position
	if centroid != initial_camera_position:
		root.free()
		return "Zero-weight target moved the camera centroid: expected %s, got %s" % [str(initial_camera_position), str(centroid)]
		
	# 2. Multiple targets with 0 total weight (division by zero guard)
	var t2: Node2D = Node2D.new()
	t2.global_position = Vector2(300.0, 150.0)
	root.add_child(t2)
	cam.add_target(t2, 0.0)
	
	var zero_weight_centroid: Vector2 = cam.calculate_target_centroid()
	if zero_weight_centroid != initial_camera_position:
		root.free()
		return "All-zero-weight targets moved the camera centroid: expected %s, got %s" % [str(initial_camera_position), str(zero_weight_centroid)]
		
	# 3. Freed node nil guard
	t1.free()
	var freed_node_centroid: Vector2 = cam.calculate_target_centroid()
	if freed_node_centroid != initial_camera_position:
		root.free()
		return "Centroid calculation failed with a freed zero-weight target: expected %s, got %s" % [str(initial_camera_position), str(freed_node_centroid)]
		
	# 4. Motion tick with freed targets
	var stationary_position: Vector2 = cam.global_position
	cam.update_camera_motion(0.1)
	if cam.global_position != stationary_position:
		root.free()
		return "All-zero-weight targets should keep the camera stationary: expected %s, got %s" % [str(stationary_position), str(cam.global_position)]
	
	root.free()
	return ""

func test_auto_framing_multi_target_zoom() -> String:
	var root: Node2D = Node2D.new()
	var cam: JuiceCam2D = JuiceCam2DScript.new()
	root.add_child(cam)
	
	var t1: Node2D = Node2D.new()
	t1.global_position = Vector2(-400.0, 0.0)
	var t2: Node2D = Node2D.new()
	t2.global_position = Vector2(400.0, 0.0)
	root.add_child(t1)
	root.add_child(t2)
	
	cam.add_target(t1, 1.0, 50.0)
	cam.add_target(t2, 1.0, 50.0)
	
	cam.auto_framing = true
	cam.smooth_zoom = false
	cam.framing_margin = 0.8
	cam.update_camera_motion(0.1)
	
	var z: Vector2 = cam.get_current_zoom()
	if z.x > 1.2 or z.x < 0.8:
		root.free()
		return "Auto framing zoom expected approx 1.024, got %s" % str(z)
		
	# Now separate targets farther apart: zoom must decrease (zoom out)
	t2.global_position = Vector2(800.0, 0.0)
	cam.update_camera_motion(0.1)
	var z_far: Vector2 = cam.get_current_zoom()
	if z_far.x >= z.x:
		root.free()
		return "Auto framing did not zoom out when targets separated: before %s, after %s" % [str(z), str(z_far)]
		
	# Test with camera rotation: rotate 90 degrees instantly
	cam.allow_rotation = true
	cam.smooth_rotation = false
	cam.rotation_offset_degrees = 90.0
	cam.update_camera_motion(0.1)
	var z_rot: Vector2 = cam.get_current_zoom()
	if z_rot.x >= z_far.x:
		root.free()
		return "Auto framing at 90 deg rotation should zoom out further to fit viewport height: got %s" % str(z_rot)
		
	root.free()
	return ""
