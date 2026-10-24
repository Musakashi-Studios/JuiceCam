extends RefCounted

const JuiceCamScript: GDScript = preload("res://addons/juicecam/2d/juice_cam_2d.gd")
const RoomScript: GDScript = preload("res://addons/juicecam/2d/juice_cam_room_2d.gd")
const MagnetScript: GDScript = preload("res://addons/juicecam/2d/juice_cam_magnet_2d.gd")
const ZoomScript: GDScript = preload("res://addons/juicecam/2d/juice_cam_zoom_2d.gd")
const PathScript: GDScript = preload("res://addons/juicecam/2d/juice_cam_path_2d.gd")
const CinematicScript: GDScript = preload("res://addons/juicecam/2d/juice_cam_cinematic_2d.gd")
const LifecycleAddonScript: GDScript = preload("res://test/fixtures/scene_lifecycle_probe_addon.gd")
const TRACKER_GROUP: StringName = &"juicecam_scene_lifecycle_tracker"

var _room_enter_count: int = 0
var _room_exit_count: int = 0
var _magnet_enter_count: int = 0
var _magnet_exit_count: int = 0
var _zoom_enter_count: int = 0
var _zoom_exit_count: int = 0
var _cinematic_stop_count: int = 0


func run(scene_tree: SceneTree) -> String:
	_room_enter_count = 0
	_room_exit_count = 0
	_magnet_enter_count = 0
	_magnet_exit_count = 0
	_zoom_enter_count = 0
	_zoom_exit_count = 0
	_cinematic_stop_count = 0
	await scene_tree.process_frame

	var tracker: Node = Node.new()
	tracker.add_to_group(TRACKER_GROUP)
	tracker.set_meta("addon_setup_count", 0)
	tracker.set_meta("addon_exit_count", 0)
	scene_tree.root.add_child(tracker)

	var error_message: String = await _change_scene(
		scene_tree,
		_load_scene("res://test/fixtures/scene_lifecycle_loading.tscn")
	)
	if not error_message.is_empty():
		return _finish(scene_tree, tracker, error_message)
	if not _registry_is_empty(scene_tree):
		return _finish(scene_tree, tracker, "Influence registry was not empty on the loading screen")

	var game_a: PackedScene = await _load_scene_threaded(
		scene_tree,
		"res://test/fixtures/scene_lifecycle_game_a.tscn"
	)
	if game_a == null:
		return _finish(scene_tree, tracker, "Could not threaded-load GameA from the loading screen")
	error_message = await _change_scene(scene_tree, game_a)
	if not error_message.is_empty():
		return _finish(scene_tree, tracker, error_message)
	var first_camera: JuiceCam2D = _populate_game_scene(scene_tree.current_scene)
	if first_camera == null:
		return _finish(scene_tree, tracker, "Could not create the first camera scene")
	first_camera.update_camera_motion(1.0 / 60.0)
	if not _scene_is_registered(scene_tree, 4):
		return _finish(scene_tree, tracker, "Initial camera or its four influence nodes were not registered")
	if _room_enter_count != 1 or _magnet_enter_count != 1 or _zoom_enter_count != 1:
		return _finish(scene_tree, tracker, "Room, magnet, and zoom enter signals did not fire for the first camera")
	if not first_camera.start_cinematic("lifecycle"):
		return _finish(scene_tree, tracker, "Camera could not start a cinematic before scene replacement")
	var first_internal_camera: Camera2D = first_camera.get_internal_camera()

	error_message = await _change_scene(
		scene_tree,
		_load_scene("res://test/fixtures/scene_lifecycle_game_b.tscn")
	)
	if not error_message.is_empty():
		return _finish(scene_tree, tracker, error_message)
	if is_instance_valid(first_camera) or is_instance_valid(first_internal_camera):
		return _finish(scene_tree, tracker, "Camera nodes remained alive after a direct scene change")
	if int(tracker.get_meta("addon_exit_count")) != 1 or _cinematic_stop_count != 1:
		return _finish(scene_tree, tracker, "Direct scene change did not stop the cinematic and exit the camera add-on")
	if _room_exit_count != 1 or _magnet_exit_count != 1 or _zoom_exit_count != 1:
		return _finish(scene_tree, tracker, "Direct scene change did not emit every active influence exit signal")
	if not _registry_is_empty(scene_tree):
		return _finish(scene_tree, tracker, "Old scene influences or camera debug state remained registered")

	var second_camera: JuiceCam2D = _populate_game_scene(scene_tree.current_scene)
	if second_camera == null:
		return _finish(scene_tree, tracker, "Could not create the second camera scene")
	second_camera.update_camera_motion(1.0 / 60.0)
	if not _scene_is_registered(scene_tree, 4):
		return _finish(scene_tree, tracker, "Second scene camera or influences were not registered")
	if not second_camera.start_cinematic("lifecycle"):
		return _finish(scene_tree, tracker, "Second camera could not start its cinematic")

	error_message = await _change_scene(
		scene_tree,
		_load_scene("res://test/fixtures/scene_lifecycle_loading.tscn")
	)
	if not error_message.is_empty():
		return _finish(scene_tree, tracker, error_message)
	if int(tracker.get_meta("addon_exit_count")) != 2 or _cinematic_stop_count != 2:
		return _finish(scene_tree, tracker, "Loading-screen transition did not clean up the second camera")
	if _room_exit_count != 2 or _magnet_exit_count != 2 or _zoom_exit_count != 2:
		return _finish(scene_tree, tracker, "Loading-screen transition did not emit all influence exit signals")
	if not _registry_is_empty(scene_tree):
		return _finish(scene_tree, tracker, "Influences or camera debug state remained while the loading screen was active")

	var game_c: PackedScene = await _load_scene_threaded(
		scene_tree,
		"res://test/fixtures/scene_lifecycle_game_c.tscn"
	)
	if game_c == null:
		return _finish(scene_tree, tracker, "Could not threaded-load GameC after the loading screen")
	error_message = await _change_scene(scene_tree, game_c)
	if not error_message.is_empty():
		return _finish(scene_tree, tracker, error_message)
	var third_camera: JuiceCam2D = _populate_game_scene(scene_tree.current_scene)
	if third_camera == null:
		return _finish(scene_tree, tracker, "Could not create a camera after loading-screen scene load")
	third_camera.update_camera_motion(1.0 / 60.0)
	if not _scene_is_registered(scene_tree, 4):
		return _finish(scene_tree, tracker, "Camera and influences did not register after loading-screen scene load")

	error_message = await _change_scene(
		scene_tree,
		_load_scene("res://test/fixtures/scene_lifecycle_game_d.tscn")
	)
	if not error_message.is_empty():
		return _finish(scene_tree, tracker, error_message)
	if int(tracker.get_meta("addon_exit_count")) != 3:
		return _finish(scene_tree, tracker, "Switching to a different scene did not exit the third camera add-on")
	if not _registry_is_empty(scene_tree):
		return _finish(scene_tree, tracker, "Third scene left stale camera or influence registrations")

	return _finish(scene_tree, tracker, "")


func _load_scene(scene_path: String) -> PackedScene:
	return ResourceLoader.load(scene_path) as PackedScene


func _load_scene_threaded(scene_tree: SceneTree, scene_path: String) -> PackedScene:
	var request_error: Error = ResourceLoader.load_threaded_request(scene_path)
	if request_error != OK:
		return null
	var frames_remaining: int = 600
	var load_status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(scene_path)
	while load_status == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS and frames_remaining > 0:
		await scene_tree.process_frame
		frames_remaining -= 1
		load_status = ResourceLoader.load_threaded_get_status(scene_path)
	if load_status != ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
		return null
	return ResourceLoader.load_threaded_get(scene_path) as PackedScene


func _change_scene(scene_tree: SceneTree, packed_scene: PackedScene) -> String:
	if packed_scene == null:
		return "Could not pack an in-memory scene for the transition test"
	var change_error: Error = scene_tree.change_scene_to_packed(packed_scene)
	if change_error != OK:
		return "change_scene_to_packed() returned %s" % error_string(change_error)
	await scene_tree.scene_changed
	await scene_tree.process_frame
	await scene_tree.process_frame
	return ""


func _populate_game_scene(scene_root: Node) -> JuiceCam2D:
	if scene_root == null:
		return null
	var room: JuiceCamRoom2D = RoomScript.new() as JuiceCamRoom2D
	room.room_size = Vector2(8000.0, 6000.0)
	room.room_entered.connect(_on_room_entered)
	room.room_exited.connect(_on_room_exited)
	scene_root.add_child(room)

	var magnet: JuiceCamMagnet2D = MagnetScript.new() as JuiceCamMagnet2D
	magnet.magnet_entered.connect(_on_magnet_entered)
	magnet.magnet_exited.connect(_on_magnet_exited)
	scene_root.add_child(magnet)

	var zoom_area: JuiceCamZoom2D = ZoomScript.new() as JuiceCamZoom2D
	zoom_area.zoom_area_entered.connect(_on_zoom_entered)
	zoom_area.zoom_area_exited.connect(_on_zoom_exited)
	scene_root.add_child(zoom_area)

	var path_region: JuiceCamPath2D = PathScript.new() as JuiceCamPath2D
	path_region.add_path_point(Vector2(-200.0, 0.0))
	path_region.add_path_point(Vector2(200.0, 0.0))
	scene_root.add_child(path_region)

	var cinematic: JuiceCamCinematic2D = CinematicScript.new() as JuiceCamCinematic2D
	cinematic.sequence_name = "lifecycle"
	cinematic.sequence_position = 0
	cinematic.hold_time = 10.0
	scene_root.add_child(cinematic)

	var camera: JuiceCam2D = JuiceCamScript.new() as JuiceCam2D
	camera.debug_draw_enabled = true
	var lifecycle_addon: JuiceCamAddon2D = LifecycleAddonScript.new() as JuiceCamAddon2D
	lifecycle_addon.addon_id = "lifecycle_probe"
	camera.addons = [lifecycle_addon]
	camera.cinematic_stopped.connect(_on_cinematic_stopped)
	scene_root.add_child(camera)
	return camera


func _scene_is_registered(scene_tree: SceneTree, expected_influences: int) -> bool:
	var registry: JuiceCamInfluenceRegistry2D = JuiceCamInfluenceRegistry2D.get_existing(scene_tree)
	return (
		registry != null
		and registry._nodes.size() == expected_influences
		and registry._debug_cameras.size() == 1
	)


func _registry_is_empty(scene_tree: SceneTree) -> bool:
	var registry: JuiceCamInfluenceRegistry2D = JuiceCamInfluenceRegistry2D.get_existing(scene_tree)
	return registry == null or (registry._nodes.is_empty() and registry._debug_cameras.is_empty())


func _finish(scene_tree: SceneTree, tracker: Node, error_message: String) -> String:
	if tracker.get_parent() == scene_tree.root:
		scene_tree.root.remove_child(tracker)
	tracker.free()
	return error_message


func _on_room_entered(_camera: Node2D) -> void:
	_room_enter_count += 1


func _on_room_exited(_camera: Node2D) -> void:
	_room_exit_count += 1


func _on_magnet_entered(_camera: Node2D) -> void:
	_magnet_enter_count += 1


func _on_magnet_exited(_camera: Node2D) -> void:
	_magnet_exit_count += 1


func _on_zoom_entered(_camera: Node2D) -> void:
	_zoom_enter_count += 1


func _on_zoom_exited(_camera: Node2D) -> void:
	_zoom_exit_count += 1


func _on_cinematic_stopped(_sequence_name: StringName) -> void:
	_cinematic_stop_count += 1
