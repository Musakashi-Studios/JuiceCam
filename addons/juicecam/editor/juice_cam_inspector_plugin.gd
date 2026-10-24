@tool
class_name JuiceCamInspectorPlugin
extends EditorInspectorPlugin

## Adds the camera's custom target stack before its ordinary Inspector properties.

const TargetsInspectorControl: GDScript = preload(
	"res://addons/juicecam/editor/juice_cam_targets_inspector_control.gd"
)

var _targets_control_added: bool = false


func _can_handle(object: Object) -> bool:
	return object is JuiceCam2D


func _parse_begin(object: Object) -> void:
	if object is JuiceCam2D:
		_targets_control_added = false


func _parse_category(object: Object, _category: String) -> void:
	if not (object is JuiceCam2D) or _targets_control_added:
		return

	# Unlike _parse_begin(), the first category is below the Inspector's node header.
	_targets_control_added = true
	add_custom_control(TargetsInspectorControl.new(object as JuiceCam2D))


func _parse_property(
	object: Object,
	_type: Variant.Type,
	name: String,
	_hint_type: PropertyHint,
	_hint_string: String,
	_usage_flags: int,
	_wide: bool
) -> bool:
	if not (object is JuiceCam2D):
		return false

	# Target properties are rendered inside the target cards above.
	return (
		name == "target_count"
		or name.begins_with("target_")
	)
