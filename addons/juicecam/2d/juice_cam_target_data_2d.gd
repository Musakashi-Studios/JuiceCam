@tool
class_name JuiceCamTargetData
extends RefCounted

## Runtime state for a single Node2D camera target.

const JuiceMath: GDScript = preload("res://addons/juicecam/core/juice_math.gd")
const MAX_LOOKAHEAD_DISTANCE: float = 1000.0

var _node: Node2D = null
var node: Node2D:
	get:
		return _node
	set(value):
		if not is_instance_valid(value) or value.is_queued_for_deletion():
			return
		if _node == value:
			return
		_node = value
		_reset_lookahead_state()


var weight: float = 1.0:
	set(value):
		weight = maxf(0.0, value)
var radius: float = 32.0:
	set(value):
		radius = maxf(0.0, value)
## Offset from the target origin in target-local axes; it rotates with the target.
var offset: Vector2 = Vector2.ZERO:
	set(value):
		if offset == value:
			return
		offset = value
		_reset_lookahead_state()
var use_lookahead: bool = true
var lookahead_factor: float = 0.0:
	set(value):
		lookahead_factor = maxf(0.0, value)

var _last_focus_position: Vector2 = Vector2.ZERO
var _last_node_position: Vector2 = Vector2.ZERO
var _filtered_lookahead: Vector2 = Vector2.ZERO
var _tracking_world_position: Vector2 = Vector2.ZERO
var _world_velocity: Vector2 = Vector2.ZERO
var _lookahead_initialized: bool = false


func _init(
	p_node: Node2D = null,
	p_weight: float = 1.0,
	p_radius: float = 32.0,
	p_offset: Vector2 = Vector2.ZERO,
	p_use_lookahead: bool = true,
	p_lookahead_factor: float = 0.0
) -> void:
	node = p_node
	weight = p_weight
	radius = p_radius
	offset = p_offset
	use_lookahead = p_use_lookahead
	lookahead_factor = p_lookahead_factor


func is_valid() -> bool:
	return is_instance_valid(_node) and not _node.is_queued_for_deletion()


## Returns the target's focus point in world space.
func get_world_position() -> Vector2:
	if is_valid():
		return _node.global_position + offset.rotated(_node.global_rotation)
	return Vector2.ZERO


## Updates this target's filtered predictive focus. Call once per camera frame.
func update_tracking_position(delta: float, lookahead_damping_rate: float) -> void:
	if not is_valid():
		_reset_lookahead_state()
		return

	var focus_position: Vector2 = get_world_position()
	if not _lookahead_initialized:
		_last_focus_position = focus_position
		_last_node_position = _node.global_position
		_tracking_world_position = focus_position
		_lookahead_initialized = true
		return

	var target_velocity: Vector2 = Vector2.ZERO
	var focus_velocity: Vector2 = Vector2.ZERO
	if delta > 0.000001:
		target_velocity = (_node.global_position - _last_node_position) / delta
		focus_velocity = (focus_position - _last_focus_position) / delta
	_world_velocity = target_velocity
	_last_node_position = _node.global_position
	_last_focus_position = focus_position

	if not use_lookahead or delta <= 0.000001 or lookahead_factor <= 0.0:
		_filtered_lookahead = Vector2.ZERO
	else:
		_filtered_lookahead = JuiceMath.filtered_lookahead_2d(
			_filtered_lookahead,
			focus_velocity,
			MAX_LOOKAHEAD_DISTANCE,
			lookahead_damping_rate,
			delta
		)
	_tracking_world_position = focus_position + _filtered_lookahead * lookahead_factor


## Returns the focus position including this target's current lookahead offset.
func get_tracking_world_position() -> Vector2:
	if not is_valid():
		return Vector2.ZERO
	return _tracking_world_position if _lookahead_initialized else get_world_position()


## Returns the target node origin's measured world-space speed, excluding its rotating offset.
func get_world_speed() -> float:
	return _world_velocity.length()


func _reset_lookahead_state() -> void:
	_last_focus_position = Vector2.ZERO
	_last_node_position = Vector2.ZERO
	_filtered_lookahead = Vector2.ZERO
	_tracking_world_position = get_world_position() if is_valid() else Vector2.ZERO
	_world_velocity = Vector2.ZERO
	_lookahead_initialized = false
