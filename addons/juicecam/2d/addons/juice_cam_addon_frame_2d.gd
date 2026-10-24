@tool
class_name JuiceCamAddonFrame2D
extends RefCounted

## Per-camera data shared with add-ons for one camera update.
## The camera reuses this object; add-ons must not retain it after their callback.

var camera: Node2D
var delta: float = 0.0
var has_target: bool = false
var is_cinematic: bool = false
var viewport_size: Vector2 = Vector2.ZERO
## Weighted mean target-node speed in world units per second, measured before camera smoothing.
## Targets with zero weight do not contribute to this value.
var target_speed: float = 0.0

## Mutable world-space destination passed through target modifiers before camera smoothing.
var target_position: Vector2 = Vector2.ZERO

## Base camera pose in world space. Target modifiers see the pose before this frame's solve;
## output modifiers see the pose after it.
var current_position: Vector2 = Vector2.ZERO
var current_rotation: float = 0.0
var current_zoom: Vector2 = Vector2.ONE

## Additive output effects applied only to the internal Camera2D. Position is camera-local.
var output_position_offset: Vector2 = Vector2.ZERO
var output_rotation_offset: float = 0.0
var output_zoom_multiplier: Vector2 = Vector2.ONE


func reset_output() -> void:
	output_position_offset = Vector2.ZERO
	output_rotation_offset = 0.0
	output_zoom_multiplier = Vector2.ONE
