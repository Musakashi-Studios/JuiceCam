@tool
extends RefCounted

## Editor-only resize controls for JuiceCam's 2D room, magnet, and zoom regions.

const ROOM_SCRIPT: GDScript = preload("res://addons/juicecam/2d/juice_cam_room_2d.gd")
const MAGNET_SCRIPT: GDScript = preload("res://addons/juicecam/2d/juice_cam_magnet_2d.gd")
const ZOOM_SCRIPT: GDScript = preload("res://addons/juicecam/2d/juice_cam_zoom_2d.gd")
const DEBUG_PALETTE: GDScript = preload("res://addons/juicecam/core/juice_cam_debug_palette_2d.gd")
const SNAP_SCRIPT: GDScript = preload("res://addons/juicecam/editor/juice_cam_editor_snap_2d.gd")

const HANDLE_RADIUS: float = 6.0
const HANDLE_HIT_RADIUS: float = 12.0
const MIN_SHAPE_SIZE: float = 0.01

var _plugin: EditorPlugin
var _selected: Node2D
var _drag_node: Node2D
var _drag_property: StringName = &""
var _drag_initial_value: Variant
var _drag_active: bool = false
var _snap: Variant = SNAP_SCRIPT.new()


func initialize(plugin: EditorPlugin) -> void:
	_plugin = plugin


func handles(object: Object) -> bool:
	if object == null:
		return false
	var script: Variant = object.get_script()
	return script == ROOM_SCRIPT or script == MAGNET_SCRIPT or script == ZOOM_SCRIPT


func edit(object: Object) -> void:
	if _drag_active:
		_cancel_drag()
	_selected = object as Node2D if handles(object) else null
	_plugin.update_overlays()


func draw_handles(overlay: Control) -> void:
	if not is_instance_valid(_selected) or not _selected.is_inside_tree():
		return
	var viewport: Viewport = EditorInterface.get_editor_viewport_2d()
	if viewport == null:
		return
	var screen_transform: Transform2D = _get_canvas_to_overlay_transform(viewport)
	var screen_position: Vector2 = screen_transform * _selected.to_global(_get_handle_local_position(_selected))
	var color: Color = _get_handle_color(_selected)
	overlay.draw_circle(screen_position, HANDLE_RADIUS + 1.5, Color(0.05, 0.05, 0.08, 0.95))
	overlay.draw_circle(screen_position, HANDLE_RADIUS, color)
	overlay.draw_arc(screen_position, HANDLE_RADIUS, 0.0, TAU, 24, Color.WHITE, 1.0, true)


func handle_input(event: InputEvent) -> bool:
	if _drag_active:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_cancel_drag()
			return true
		if event is InputEventMouseMotion:
			_update_drag(event.position)
			return true
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				_finish_drag()
			return true
		return false

	if not is_instance_valid(_selected) or not _selected.is_inside_tree():
		return false
	if not event is InputEventMouseButton:
		return false
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return false
	if _is_pointer_on_handle(mouse_event.position):
		_begin_drag()
		return true
	return false


func _is_pointer_on_handle(pointer_position: Vector2) -> bool:
	var viewport: Viewport = EditorInterface.get_editor_viewport_2d()
	if viewport == null:
		return false
	var transform: Transform2D = _get_canvas_to_overlay_transform(viewport)
	var handle_position: Vector2 = transform * _selected.to_global(_get_handle_local_position(_selected))
	return pointer_position.distance_squared_to(handle_position) <= HANDLE_HIT_RADIUS * HANDLE_HIT_RADIUS


func _begin_drag() -> void:
	_drag_node = _selected
	_drag_property = _get_resize_property(_drag_node)
	_drag_initial_value = _drag_node.get(_drag_property)
	_snap.capture(_drag_node)
	_drag_active = true


func _update_drag(pointer_position: Vector2) -> void:
	if not is_instance_valid(_drag_node) or not _drag_node.is_inside_tree():
		_cancel_drag()
		return
	var viewport: Viewport = EditorInterface.get_editor_viewport_2d()
	if viewport == null:
		return
	var canvas_transform: Transform2D = _get_canvas_to_overlay_transform(viewport)
	var world_position: Vector2 = canvas_transform.affine_inverse() * pointer_position
	world_position = _snap.snap_world_position(world_position)
	var local_position: Vector2 = _drag_node.to_local(world_position)
	if _drag_property == &"radius":
		_drag_node.set(_drag_property, maxf(MIN_SHAPE_SIZE, local_position.length()))
	else:
		_drag_node.set(
			_drag_property,
			Vector2(
				maxf(MIN_SHAPE_SIZE, absf(local_position.x) * 2.0),
				maxf(MIN_SHAPE_SIZE, absf(local_position.y) * 2.0)
			)
		)
	_plugin.update_overlays()


func _finish_drag() -> void:
	if not is_instance_valid(_drag_node):
		_reset_drag()
		return
	var final_value: Variant = _drag_node.get(_drag_property)
	if final_value != _drag_initial_value:
		var undo_redo: EditorUndoRedoManager = _plugin.get_undo_redo()
		undo_redo.create_action("Resize JuiceCam Region", UndoRedo.MERGE_DISABLE, _drag_node)
		undo_redo.add_do_property(_drag_node, _drag_property, final_value)
		undo_redo.add_undo_property(_drag_node, _drag_property, _drag_initial_value)
		undo_redo.commit_action()
	_reset_drag()
	_plugin.update_overlays()


func _cancel_drag() -> void:
	if _drag_active and is_instance_valid(_drag_node) and not _drag_property.is_empty():
		_drag_node.set(_drag_property, _drag_initial_value)
	_reset_drag()
	if is_instance_valid(_plugin):
		_plugin.update_overlays()


func _reset_drag() -> void:
	_drag_node = null
	_drag_property = &""
	_drag_initial_value = null
	_drag_active = false


func _get_resize_property(node: Node2D) -> StringName:
	if node.get_script() == ROOM_SCRIPT:
		return &"room_size"
	if node.get_script() == MAGNET_SCRIPT:
		return &"radius" if node.get("magnet_shape") == 0 else &"rectangle_size"
	return &"radius" if node.get("zoom_shape") == 0 else &"rectangle_size"


func _get_handle_local_position(node: Node2D) -> Vector2:
	if node.get_script() == ROOM_SCRIPT:
		return node.get("room_size") * 0.5
	var is_circle: bool = (
		int(node.get("magnet_shape")) == 0
		if node.get_script() == MAGNET_SCRIPT
		else int(node.get("zoom_shape")) == 0
	)
	if is_circle:
		return Vector2(float(node.get("radius")), 0.0)
	return node.get("rectangle_size") * 0.5


func _get_handle_color(node: Node2D) -> Color:
	if node.get_script() == ROOM_SCRIPT:
		return DEBUG_PALETTE.ROOM
	if node.get_script() == MAGNET_SCRIPT:
		return DEBUG_PALETTE.MAGNET
	return DEBUG_PALETTE.ZOOM


func _get_canvas_to_overlay_transform(viewport: Viewport) -> Transform2D:
	return viewport.get_global_canvas_transform() * viewport.get_canvas_transform()


