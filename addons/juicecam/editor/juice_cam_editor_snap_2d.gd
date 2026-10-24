@tool
extends RefCounted

## Reads the active CanvasItemEditor snap settings and applies them to world positions.

var _grid_snap_enabled: bool = false
var _pixel_snap_enabled: bool = false
var _snap_relative: bool = false
var _grid_step: Vector2 = Vector2(8.0, 8.0)
var _grid_offset: Vector2 = Vector2.ZERO
var _relative_origin: Vector2 = Vector2.ZERO


func capture(reference_node: Node2D) -> void:
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	var editor_root: Control = EditorInterface.get_base_control()
	_grid_snap_enabled = _get_shortcut_button_state(
		editor_root,
		editor_settings.get_shortcut("canvas_item_editor/use_grid_snap")
	)
	_pixel_snap_enabled = _get_shortcut_menu_state(
		editor_root,
		editor_settings.get_shortcut("canvas_item_editor/use_pixel_snap"),
		false
	)
	_snap_relative = _get_shortcut_menu_state(
		editor_root,
		editor_settings.get_shortcut("canvas_item_editor/snap_relative"),
		false
	)
	_grid_step = editor_settings.get_project_metadata("2d_editor", "grid_step", Vector2(8.0, 8.0))
	_grid_offset = editor_settings.get_project_metadata("2d_editor", "grid_offset", Vector2.ZERO)
	_relative_origin = reference_node.global_position


func snap_world_position(world_position: Vector2) -> Vector2:
	if _grid_snap_enabled:
		var offset: Vector2 = _relative_origin if _snap_relative else _grid_offset
		if _grid_step.x > 0.0:
			world_position.x = snappedf(world_position.x - offset.x, _grid_step.x) + offset.x
		if _grid_step.y > 0.0:
			world_position.y = snappedf(world_position.y - offset.y, _grid_step.y) + offset.y
	if _pixel_snap_enabled:
		world_position = world_position.snapped(Vector2.ONE)
	return world_position


func _get_shortcut_button_state(root: Node, shortcut: Shortcut) -> bool:
	if shortcut == null:
		return false
	if root is BaseButton and (root as BaseButton).shortcut == shortcut:
		return (root as BaseButton).button_pressed
	for child: Node in root.get_children(true):
		var state: Variant = _find_shortcut_button_state(child, shortcut)
		if state != null:
			return state
	return false


func _find_shortcut_button_state(root: Node, shortcut: Shortcut) -> Variant:
	if root is BaseButton and (root as BaseButton).shortcut == shortcut:
		return (root as BaseButton).button_pressed
	for child: Node in root.get_children(true):
		var state: Variant = _find_shortcut_button_state(child, shortcut)
		if state != null:
			return state
	return null


func _get_shortcut_menu_state(root: Node, shortcut: Shortcut, fallback: bool) -> bool:
	if shortcut == null:
		return fallback
	if root is PopupMenu:
		var popup: PopupMenu = root as PopupMenu
		for item_index: int in range(popup.get_item_count()):
			if popup.get_item_shortcut(item_index) == shortcut:
				return popup.is_item_checked(item_index)
	for child: Node in root.get_children(true):
		var state: Variant = _find_shortcut_menu_state(child, shortcut)
		if state != null:
			return state
	return fallback


func _find_shortcut_menu_state(root: Node, shortcut: Shortcut) -> Variant:
	if root is PopupMenu:
		var popup: PopupMenu = root as PopupMenu
		for item_index: int in range(popup.get_item_count()):
			if popup.get_item_shortcut(item_index) == shortcut:
				return popup.is_item_checked(item_index)
	for child: Node in root.get_children(true):
		var state: Variant = _find_shortcut_menu_state(child, shortcut)
		if state != null:
			return state
	return null
