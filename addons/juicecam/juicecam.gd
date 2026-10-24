@tool
extends EditorPlugin

const JUICE_CAM_2D_NAME: String = "JuiceCam2D"
const JUICE_CAM_2D_BASE: String = "Node2D"
const JUICE_CAM_2D_SCRIPT: GDScript = preload("res://addons/juicecam/2d/juice_cam_2d.gd")
const JUICE_CAM_2D_ICON: Texture2D = preload("res://addons/juicecam/icons/juice_cam_2d.png")
const JUICE_CAM_ZOOM_2D_NAME: String = "JuiceCamZoom2D"
const JUICE_CAM_ZOOM_2D_SCRIPT: GDScript = preload("res://addons/juicecam/2d/juice_cam_zoom_2d.gd")
const JUICE_CAM_ZOOM_2D_ICON: Texture2D = preload("res://addons/juicecam/icons/juice_cam_zoom_2d.png")
const JUICE_CAM_MAGNET_2D_NAME: String = "JuiceCamMagnet2D"
const JUICE_CAM_MAGNET_2D_SCRIPT: GDScript = preload("res://addons/juicecam/2d/juice_cam_magnet_2d.gd")
const JUICE_CAM_MAGNET_2D_ICON: Texture2D = preload("res://addons/juicecam/icons/juice_cam_magnet_2d.png")
const JUICE_CAM_ROOM_2D_NAME: String = "JuiceCamRoom2D"
const JUICE_CAM_ROOM_2D_SCRIPT: GDScript = preload("res://addons/juicecam/2d/juice_cam_room_2d.gd")
const JUICE_CAM_ROOM_2D_ICON: Texture2D = preload("res://addons/juicecam/icons/juice_cam_room_2d.png")
const JUICE_CAM_PATH_2D_NAME: String = "JuiceCamPath2D"
const JUICE_CAM_PATH_2D_SCRIPT: GDScript = preload("res://addons/juicecam/2d/juice_cam_path_2d.gd")
const JUICE_CAM_PATH_2D_ICON: Texture2D = preload("res://addons/juicecam/icons/juice_cam_path_2d.png")
const JUICE_CAM_CINEMATIC_2D_NAME: String = "JuiceCamCinematic2D"
const JUICE_CAM_CINEMATIC_2D_SCRIPT: GDScript = preload(
	"res://addons/juicecam/2d/juice_cam_cinematic_2d.gd"
)
const JUICE_CAM_CINEMATIC_2D_ICON: Texture2D = preload(
	"res://addons/juicecam/icons/juice_cam_cinematic_2d.png"
)
const JUICE_INSPECTOR_PLUGIN_SCRIPT: GDScript = preload("res://addons/juicecam/editor/juice_cam_inspector_plugin.gd")
const JUICE_CAM_INFLUENCE_GIZMO_SCRIPT: GDScript = preload(
	"res://addons/juicecam/editor/juice_cam_influence_gizmo_2d.gd"
)
const JUICE_CAM_PATH_EDITOR_SCRIPT: GDScript = preload(
	"res://addons/juicecam/editor/juice_cam_path_editor_2d.gd"
)
var _inspector_plugin: EditorInspectorPlugin = null
var _influence_gizmo: Variant = null
var _path_editor: Variant = null


func _enter_tree() -> void:
	add_custom_type(JUICE_CAM_2D_NAME, JUICE_CAM_2D_BASE, JUICE_CAM_2D_SCRIPT, JUICE_CAM_2D_ICON)
	add_custom_type(JUICE_CAM_ZOOM_2D_NAME, "Node2D", JUICE_CAM_ZOOM_2D_SCRIPT, JUICE_CAM_ZOOM_2D_ICON)
	add_custom_type(JUICE_CAM_MAGNET_2D_NAME, "Node2D", JUICE_CAM_MAGNET_2D_SCRIPT, JUICE_CAM_MAGNET_2D_ICON)
	add_custom_type(JUICE_CAM_ROOM_2D_NAME, "Node2D", JUICE_CAM_ROOM_2D_SCRIPT, JUICE_CAM_ROOM_2D_ICON)
	add_custom_type(JUICE_CAM_PATH_2D_NAME, "Node2D", JUICE_CAM_PATH_2D_SCRIPT, JUICE_CAM_PATH_2D_ICON)
	add_custom_type(
		JUICE_CAM_CINEMATIC_2D_NAME,
		"Node2D",
		JUICE_CAM_CINEMATIC_2D_SCRIPT,
		JUICE_CAM_CINEMATIC_2D_ICON
	)
	
	_inspector_plugin = JUICE_INSPECTOR_PLUGIN_SCRIPT.new() as EditorInspectorPlugin
	add_inspector_plugin(_inspector_plugin)
	_influence_gizmo = JUICE_CAM_INFLUENCE_GIZMO_SCRIPT.new()
	_influence_gizmo.initialize(self)
	_path_editor = JUICE_CAM_PATH_EDITOR_SCRIPT.new()
	_path_editor.initialize(self)


func _exit_tree() -> void:
	if _path_editor != null:
		_path_editor.terminate()
		_path_editor = null
	remove_custom_type(JUICE_CAM_2D_NAME)
	remove_custom_type(JUICE_CAM_ZOOM_2D_NAME)
	remove_custom_type(JUICE_CAM_MAGNET_2D_NAME)
	remove_custom_type(JUICE_CAM_ROOM_2D_NAME)
	remove_custom_type(JUICE_CAM_PATH_2D_NAME)
	remove_custom_type(JUICE_CAM_CINEMATIC_2D_NAME)
	
	if _inspector_plugin != null:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null
	_influence_gizmo = null


func _handles(object: Object) -> bool:
	return (
		(_path_editor != null and _path_editor.handles(object))
		or (_influence_gizmo != null and _influence_gizmo.handles(object))
	)


func _edit(object: Object) -> void:
	if _path_editor != null:
		_path_editor.edit(object)
	if _influence_gizmo != null:
		_influence_gizmo.edit(object)


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if _path_editor != null:
		_path_editor.draw_handles(overlay)
	if _influence_gizmo != null:
		_influence_gizmo.draw_handles(overlay)


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	return (
		(_path_editor != null and _path_editor.handle_input(event))
		or (_influence_gizmo != null and _influence_gizmo.handle_input(event))
	)
