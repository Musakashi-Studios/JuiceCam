@tool
@abstract
class_name JuiceCamAddon2D
extends Resource

## Base resource for an optional, per-camera JuiceCam2D add-on.

@export var addon_id: String = "":
	set(value):
		if addon_id == value:
			return
		addon_id = value
		emit_changed()

@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value
		_on_enabled_changed(value)
		emit_changed()


## Lets add-ons begin or finish transitions when their enabled state changes.
func _on_enabled_changed(_is_enabled: bool) -> void:
	pass


## Override when an add-on must keep processing briefly after it is disabled.
func is_active_for_processing() -> bool:
	return enabled

## Called on the camera-owned runtime copy when it is attached to a camera.
func setup(_camera: Node2D) -> void:
	pass


## Called when the camera-owned runtime copy is detached or rebuilt.
func exit(_camera: Node2D) -> void:
	pass


## Override in an add-on script to suppress its contribution during cinematics.
## The modifier callback still runs so time-based state can continue advancing.
func runs_during_cinematics() -> bool:
	return true
