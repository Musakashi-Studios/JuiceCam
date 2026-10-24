extends SceneTree

# JuiceCam Automated Test Runner

const SceneLifecycleTest: GDScript = preload("res://test/integration/test_scene_lifecycle.gd")

func _init() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	print("========================================")
	print("       JuiceCam Automated Test Suite    ")
	print("========================================")
	
	var test_files: Array[String] = [
		"res://test/unit/test_juice_math.gd",
		"res://test/unit/test_juice_framing.gd",
		"res://test/unit/test_juice_cam_2d.gd",
	]
	
	var total_passed: int = 0
	var total_failed: int = 0
	
	for path: String in test_files:
		if not ResourceLoader.exists(path):
			print("[SKIP] Test file not found: %s" % path)
			continue
		
		print("\n--- Running: %s ---" % path.get_file())
		var script: GDScript = load(path) as GDScript
		if script == null:
			print("[ERROR] Failed to load script: %s" % path)
			total_failed += 1
			continue
			
		var test_instance: Object = script.new()
		if test_instance == null:
			print("[ERROR] Failed to instantiate script: %s" % path)
			total_failed += 1
			continue
			
		var method_list: Array[Dictionary] = test_instance.get_method_list()
		for method: Dictionary in method_list:
			var m_name: String = method["name"]
			if m_name.begins_with("test_"):
				if test_instance.has_method("before_each"):
					test_instance.call("before_each")
				
				var err_msg: Variant = test_instance.call(m_name)
				if err_msg != null and err_msg is String and (err_msg as String) != "":
					print("  [FAIL] %s: %s" % [m_name, err_msg as String])
					total_failed += 1
				else:
					print("  [PASS] %s" % m_name)
					total_passed += 1
					
				if test_instance.has_method("after_each"):
					test_instance.call("after_each")
					
		if not (test_instance is RefCounted):
			test_instance.free()

	print("\n--- Running: scene lifecycle integration ---")
	var lifecycle_test: Object = SceneLifecycleTest.new()
	var lifecycle_error: String = await lifecycle_test.call("run", self)
	if lifecycle_error.is_empty():
		print("  [PASS] direct scene changes and loading-screen transitions clean up cameras and influences")
		total_passed += 1
	else:
		print("  [FAIL] scene lifecycle: %s" % lifecycle_error)
		total_failed += 1
			
	print("\n========================================")
	print(" Results: %d Passed, %d Failed" % [total_passed, total_failed])
	print("========================================")
	
	if total_failed > 0:
		quit(1)
	else:
		quit(0)
