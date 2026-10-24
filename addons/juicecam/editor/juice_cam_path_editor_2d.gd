@tool
extends RefCounted

## Edits JuiceCamPath2D points directly in the 2D canvas.

const DEBUG_COLOR: Color = JuiceCamDebugPalette2D.PATH
const PATH_HIT_RADIUS: float = 11.0
const POINT_DRAG_THRESHOLD: float = 4.0
const POINT_HANDLE_RADIUS: float = 4.5
const ENDPOINT_HANDLE_SIZE: Vector2 = Vector2(10.0, 10.0)
const SNAP_SCRIPT: GDScript = preload("res://addons/juicecam/editor/juice_cam_editor_snap_2d.gd")

enum ToolMode {
	EDIT,
	DRAW,
	DELETE,
}

const TOOL_ICONS: Array[StringName] = [&"CurveEdit", &"CurveCreate", &"CurveDelete"]
const TOOL_TOOLTIPS: Array[String] = [
	"Move path points; click a point to toggle sharp or smooth",
	"Draw smooth path points",
	"Delete path points",
]

var _plugin: EditorPlugin
var _selected_path: JuiceCamPath2D
var _tool_mode: int = ToolMode.EDIT
var _toolbar_buttons: Array[Button] = []
var _button_group: ButtonGroup
var _snap: Variant = SNAP_SCRIPT.new()
var _hovered_point_index: int = -1
var _interaction_active: bool = false
var _drag_active: bool = false
var _drag_point_index: int = -1
var _drag_start_position: Vector2 = Vector2.ZERO
var _drag_start_screen_position: Vector2 = Vector2.ZERO
var _drag_axis: Vector2i = Vector2i.ZERO
var _drag_curve: Curve2D


func initialize(plugin: EditorPlugin) -> void:
	_plugin = plugin
	_button_group = ButtonGroup.new()
	_button_group.allow_unpress = false
	for tool_index: int in range(TOOL_ICONS.size()):
		var button: Button = Button.new()
		button.flat = true
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.button_group = _button_group
		button.tooltip_text = TOOL_TOOLTIPS[tool_index]
		button.icon = EditorInterface.get_editor_theme().get_icon(TOOL_ICONS[tool_index], "EditorIcons")
		button.pressed.connect(_set_tool_mode.bind(tool_index))
		button.set_pressed_no_signal(tool_index == _tool_mode)
		button.disabled = true
		_plugin.add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, button)
		_toolbar_buttons.append(button)


func terminate() -> void:
	_cancel_interaction()
	if is_instance_valid(_plugin):
		for button: Button in _toolbar_buttons:
			_plugin.remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, button)
			button.queue_free()
	_toolbar_buttons.clear()
	_selected_path = null
	_plugin = null


func handles(object: Object) -> bool:
	return object is JuiceCamPath2D


func edit(object: Object) -> void:
	var path: JuiceCamPath2D = null
	if handles(object):
		path = object as JuiceCamPath2D
	if path == _selected_path:
		return
	_cancel_interaction()
	_selected_path = path
	_hovered_point_index = -1
	_update_toolbar_state()
	_update_overlays()


func draw_handles(overlay: Control) -> void:
	if not _is_selected_path_valid():
		return
	var viewport: Viewport = EditorInterface.get_editor_viewport_2d()
	if viewport == null:
		return
	var screen_transform: Transform2D = _get_canvas_to_overlay_transform(viewport)
	var path_curve: Curve2D = _selected_path.curve
	if path_curve == null:
		return
	for point_index: int in range(path_curve.get_point_count()):
		var screen_position: Vector2 = screen_transform * _selected_path.to_global(
			path_curve.get_point_position(point_index)
		)
		var marker_color: Color = Color.WHITE if point_index == _hovered_point_index else DEBUG_COLOR
		if point_index == 0 or point_index == path_curve.get_point_count() - 1:
			var endpoint_rect: Rect2 = Rect2(
				screen_position - ENDPOINT_HANDLE_SIZE * 0.5,
				ENDPOINT_HANDLE_SIZE
			)
			overlay.draw_rect(endpoint_rect, Color(0.05, 0.05, 0.08, 0.95), true)
			overlay.draw_rect(endpoint_rect, marker_color, false, 1.0, false)
			if _selected_path.get_path_point_smooth(point_index):
				overlay.draw_circle(screen_position, 2.0, marker_color)
		elif _selected_path.get_path_point_smooth(point_index):
			overlay.draw_circle(screen_position, POINT_HANDLE_RADIUS, marker_color)
		else:
			var point_rect: Rect2 = Rect2(
				screen_position - Vector2.ONE * POINT_HANDLE_RADIUS,
				Vector2.ONE * POINT_HANDLE_RADIUS * 2.0
			)
			overlay.draw_rect(point_rect, Color(0.05, 0.05, 0.08, 0.95), true)
			overlay.draw_rect(point_rect, marker_color, false, 1.0, false)


func handle_input(event: InputEvent) -> bool:
	if not _is_selected_path_valid():
		return false
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			if _interaction_active:
				_cancel_interaction()
			else:
				_set_tool_mode(ToolMode.EDIT)
			return true
	if _interaction_active:
		return _continue_point_interaction(event)
	if event is InputEventMouseMotion:
		_update_hovered_point((event as InputEventMouseMotion).position)
		return false
	if not event is InputEventMouseButton:
		return false
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return false
	match _tool_mode:
		ToolMode.DRAW:
			_add_point(mouse_event.position)
			return true
		ToolMode.DELETE:
			_delete_point(mouse_event.position)
			return true
		ToolMode.EDIT:
			var point_index: int = _find_point_at(mouse_event.position)
			if point_index < 0:
				return false
			_begin_point_interaction(point_index, mouse_event.position)
			return true
	return false


func _continue_point_interaction(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			_cancel_interaction()
			return true
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		if not _drag_active:
			if (
				motion_event.position.distance_squared_to(_drag_start_screen_position)
				< POINT_DRAG_THRESHOLD * POINT_DRAG_THRESHOLD
			):
				return true
			_drag_active = true
		_update_drag(motion_event.position, motion_event.shift_pressed)
		return true
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_finish_point_interaction()
			return true
	return true


func _begin_point_interaction(point_index: int, screen_position: Vector2) -> void:
	_drag_curve = _selected_path.curve
	_drag_point_index = point_index
	_drag_start_position = _drag_curve.get_point_position(point_index)
	_drag_start_screen_position = screen_position
	_drag_axis = Vector2i.ZERO
	_drag_active = false
	_interaction_active = true
	_snap.capture(_selected_path)
	_hovered_point_index = point_index
	_update_overlays()


func _update_drag(screen_position: Vector2, shift_pressed: bool) -> void:
	if not _is_drag_target_valid():
		_cancel_interaction()
		return
	var local_position: Vector2 = _get_path_local_position(screen_position)
	if shift_pressed:
		var delta: Vector2 = local_position - _drag_start_position
		if _drag_axis == Vector2i.ZERO:
			_drag_axis = Vector2i.RIGHT if absf(delta.x) >= absf(delta.y) else Vector2i.DOWN
		if _drag_axis == Vector2i.RIGHT:
			local_position.y = _drag_start_position.y
		else:
			local_position.x = _drag_start_position.x
	else:
		_drag_axis = Vector2i.ZERO
	_selected_path.set_path_point_position(_drag_point_index, local_position)
	_update_overlays()


func _finish_point_interaction() -> void:
	if not _interaction_active:
		return
	if not _is_drag_target_valid():
		_cancel_interaction()
		return
	if _drag_active:
		var final_position: Vector2 = _drag_curve.get_point_position(_drag_point_index)
		if not final_position.is_equal_approx(_drag_start_position):
			var undo_redo: EditorUndoRedoManager = _plugin.get_undo_redo()
			undo_redo.create_action(
				"Move JuiceCam Path Point",
				UndoRedo.MERGE_DISABLE,
				_selected_path
			)
			undo_redo.add_do_method(
				_selected_path,
				"set_path_point_position",
				_drag_point_index,
				final_position
			)
			undo_redo.add_undo_method(
				_selected_path,
				"set_path_point_position",
				_drag_point_index,
				_drag_start_position
			)
			undo_redo.commit_action()
	else:
		var was_smooth: bool = _selected_path.get_path_point_smooth(_drag_point_index)
		var undo_redo: EditorUndoRedoManager = _plugin.get_undo_redo()
		undo_redo.create_action(
			"Toggle JuiceCam Path Point Smoothing",
			UndoRedo.MERGE_DISABLE,
			_selected_path
		)
		undo_redo.add_do_method(
			_selected_path,
			"set_path_point_smooth",
			_drag_point_index,
			not was_smooth
		)
		undo_redo.add_undo_method(
			_selected_path,
			"set_path_point_smooth",
			_drag_point_index,
			was_smooth
		)
		undo_redo.commit_action()
	_reset_interaction()
	_update_overlays()


func _cancel_interaction() -> void:
	if _drag_active and _is_drag_target_valid():
		_selected_path.set_path_point_position(_drag_point_index, _drag_start_position)
	_reset_interaction()
	_update_overlays()


func _reset_interaction() -> void:
	_interaction_active = false
	_drag_active = false
	_drag_point_index = -1
	_drag_axis = Vector2i.ZERO
	_drag_curve = null


func _add_point(screen_position: Vector2) -> void:
	_snap.capture(_selected_path)
	var local_position: Vector2 = _get_path_local_position(screen_position)
	var point_index: int = _selected_path.curve.get_point_count()
	var undo_redo: EditorUndoRedoManager = _plugin.get_undo_redo()
	undo_redo.create_action("Add JuiceCam Path Point", UndoRedo.MERGE_DISABLE, _selected_path)
	undo_redo.add_do_method(_selected_path, "add_path_point", local_position, true)
	undo_redo.add_undo_method(_selected_path, "remove_path_point", point_index)
	undo_redo.commit_action()
	_hovered_point_index = point_index
	_update_overlays()


func _delete_point(screen_position: Vector2) -> void:
	var point_index: int = _find_point_at(screen_position)
	if point_index < 0:
		return
	var point_position: Vector2 = _selected_path.curve.get_point_position(point_index)
	var was_smooth: bool = _selected_path.get_path_point_smooth(point_index)
	var undo_redo: EditorUndoRedoManager = _plugin.get_undo_redo()
	undo_redo.create_action("Delete JuiceCam Path Point", UndoRedo.MERGE_DISABLE, _selected_path)
	undo_redo.add_do_method(_selected_path, "remove_path_point", point_index)
	undo_redo.add_undo_method(
		_selected_path,
		"insert_path_point",
		point_index,
		point_position,
		was_smooth
	)
	undo_redo.commit_action()
	_hovered_point_index = -1
	_update_overlays()


func _find_point_at(screen_position: Vector2) -> int:
	if not _is_selected_path_valid() or _selected_path.curve == null:
		return -1
	var viewport: Viewport = EditorInterface.get_editor_viewport_2d()
	if viewport == null:
		return -1
	var screen_transform: Transform2D = _get_canvas_to_overlay_transform(viewport)
	var best_index: int = -1
	var best_distance_squared: float = PATH_HIT_RADIUS * PATH_HIT_RADIUS
	for point_index: int in range(_selected_path.curve.get_point_count()):
		var point_screen_position: Vector2 = screen_transform * _selected_path.to_global(
			_selected_path.curve.get_point_position(point_index)
		)
		var distance_squared: float = screen_position.distance_squared_to(point_screen_position)
		if distance_squared <= best_distance_squared:
			best_distance_squared = distance_squared
			best_index = point_index
	return best_index


func _update_hovered_point(screen_position: Vector2) -> void:
	var point_index: int = _find_point_at(screen_position) if _tool_mode == ToolMode.EDIT else -1
	if point_index == _hovered_point_index:
		return
	_hovered_point_index = point_index
	_update_overlays()


func _get_path_local_position(screen_position: Vector2) -> Vector2:
	var viewport: Viewport = EditorInterface.get_editor_viewport_2d()
	var screen_transform: Transform2D = _get_canvas_to_overlay_transform(viewport)
	var world_position: Vector2 = screen_transform.affine_inverse() * screen_position
	world_position = _snap.snap_world_position(world_position)
	return _selected_path.to_local(world_position)


func _get_canvas_to_overlay_transform(viewport: Viewport) -> Transform2D:
	return viewport.get_global_canvas_transform() * viewport.get_canvas_transform()


func _is_selected_path_valid() -> bool:
	return is_instance_valid(_selected_path) and _selected_path.is_inside_tree()


func _is_drag_target_valid() -> bool:
	return (
		_is_selected_path_valid()
		and _selected_path.curve == _drag_curve
		and _drag_curve != null
		and _drag_point_index >= 0
		and _drag_point_index < _drag_curve.get_point_count()
	)


func _set_tool_mode(tool_mode: int) -> void:
	if _interaction_active:
		_cancel_interaction()
	_tool_mode = tool_mode
	for button_index: int in range(_toolbar_buttons.size()):
		_toolbar_buttons[button_index].set_pressed_no_signal(button_index == _tool_mode)
	_hovered_point_index = -1
	_update_overlays()


func _update_toolbar_state() -> void:
	var path_is_valid: bool = _is_selected_path_valid()
	for button: Button in _toolbar_buttons:
		button.disabled = not path_is_valid


func _update_overlays() -> void:
	if is_instance_valid(_plugin):
		_plugin.update_overlays()
