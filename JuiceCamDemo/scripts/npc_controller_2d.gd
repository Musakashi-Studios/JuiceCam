extends CharacterBody2D

@export_group("Wander Bounds")
@export var wander_bounds: CollisionShape2D
@export_range(0.0, 256.0, 1.0) var body_half_width: float = 41.0
@export_range(0.0, 256.0, 1.0) var body_half_height: float = 42.0

@export_group("Movement")
@export_range(0.0, 1000.0, 1.0) var move_speed: float = 180.0
@export_range(1.0, 4000.0, 1.0) var move_acceleration: float = 900.0
@export_range(0.0, 1.0, 0.05) var jump_chance: float = 0.4
@export_range(0.0, 1.0, 0.05) var pause_chance: float = 0.25
@export_range(1.0, 1200.0, 1.0) var jump_speed: float = 420.0
@export_range(0.1, 3.0, 0.05) var gravity_multiplier: float = 1.0

@export_group("Timing")
@export_range(0.1, 10.0, 0.1) var min_walk_duration: float = 0.8
@export_range(0.1, 10.0, 0.1) var max_walk_duration: float = 2.4
@export_range(0.1, 10.0, 0.1) var min_pause_duration: float = 0.2
@export_range(0.1, 10.0, 0.1) var max_pause_duration: float = 1.2

@onready var _sprite: Sprite2D = $NpcSprite

var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _rectangle: RectangleShape2D
var _cached_bounds_transform: Transform2D = Transform2D.IDENTITY
var _cached_bounds_size: Vector2 = Vector2.ZERO
var _bounds_min: Vector2 = Vector2.ZERO
var _bounds_max: Vector2 = Vector2.ZERO
var _target_x: float = 0.0
var _action_time_remaining: float = 0.0
var _is_walking: bool = false
var _jump_pending: bool = false
var _area_floor_contact: bool = false


func _ready() -> void:
	if not _validate_configuration():
		set_physics_process(false)
		return

	_random.randomize()
	_rectangle = wander_bounds.shape as RectangleShape2D
	if not _refresh_bounds():
		return
	global_position.x = clampf(global_position.x, _min_x(), _max_x())
	global_position.y = clampf(global_position.y, _min_y(), _floor_y())
	_choose_next_action()


func _physics_process(delta: float) -> void:
	if not _refresh_bounds():
		return
	var grounded: bool = is_on_floor() or _area_floor_contact
	if _action_time_remaining <= 0.0 and grounded:
		_choose_next_action()

	if grounded:
		if velocity.y > 0.0:
			velocity.y = 0.0
	else:
		velocity.y += get_gravity().y * gravity_multiplier * delta

	if _jump_pending and grounded:
		velocity.y = -jump_speed
		_jump_pending = false
		_area_floor_contact = false

	var direction: float = signf(_target_x - global_position.x) if _is_walking else 0.0
	velocity.x = move_toward(velocity.x, direction * move_speed, move_acceleration * delta)
	_action_time_remaining = maxf(_action_time_remaining - delta, 0.0)
	if _is_walking and absf(_target_x - global_position.x) <= 12.0:
		_action_time_remaining = 0.0

	move_and_slide()
	_handle_wall_collisions()
	_constrain_to_bounds()
	_update_facing()


func _validate_configuration() -> bool:
	if not is_instance_valid(wander_bounds):
		push_error("NpcController2D requires a CollisionShape2D assigned to Wander Bounds.")
		return false
	if not wander_bounds.shape is RectangleShape2D:
		push_error("NpcController2D Wander Bounds must use a RectangleShape2D.")
		return false
	if body_half_width <= 0.0 or body_half_height <= 0.0:
		push_error("NpcController2D body half-size values must be greater than zero.")
		return false
	if min_walk_duration > max_walk_duration or min_pause_duration > max_pause_duration:
		push_error("NpcController2D minimum durations cannot exceed their maximum durations.")
		return false
	return true


func _refresh_bounds() -> bool:
	var bounds_transform: Transform2D = wander_bounds.global_transform
	var bounds_size: Vector2 = _rectangle.size
	if bounds_transform == _cached_bounds_transform and bounds_size == _cached_bounds_size:
		return true

	_cached_bounds_transform = bounds_transform
	_cached_bounds_size = bounds_size
	var half_size: Vector2 = bounds_size * 0.5
	var corners: Array[Vector2] = [
		bounds_transform * Vector2(-half_size.x, -half_size.y),
		bounds_transform * Vector2(half_size.x, -half_size.y),
		bounds_transform * Vector2(half_size.x, half_size.y),
		bounds_transform * Vector2(-half_size.x, half_size.y),
	]
	_bounds_min = corners[0]
	_bounds_max = corners[0]
	for corner: Vector2 in corners:
		_bounds_min.x = minf(_bounds_min.x, corner.x)
		_bounds_min.y = minf(_bounds_min.y, corner.y)
		_bounds_max.x = maxf(_bounds_max.x, corner.x)
		_bounds_max.y = maxf(_bounds_max.y, corner.y)

	if _min_x() > _max_x() or _min_y() > _floor_y():
		push_error("NpcController2D bounds are too small for the configured body size.")
		set_physics_process(false)
		return false
	return true


func _choose_next_action() -> void:
	_jump_pending = false
	if _random.randf() < pause_chance:
		_is_walking = false
		_action_time_remaining = _random.randf_range(min_pause_duration, max_pause_duration)
		return

	_is_walking = true
	_target_x = _random.randf_range(_min_x(), _max_x())
	_action_time_remaining = _random.randf_range(min_walk_duration, max_walk_duration)
	_jump_pending = _random.randf() < jump_chance


func _handle_wall_collisions() -> void:
	for collision_index: int in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if absf(collision.get_normal().x) > 0.5:
			_action_time_remaining = 0.0
			return


func _constrain_to_bounds() -> void:
	var min_x: float = _min_x()
	var max_x: float = _max_x()
	var min_y: float = _min_y()
	var floor_y: float = _floor_y()
	if global_position.x < min_x:
		global_position.x = min_x
		velocity.x = maxf(velocity.x, 0.0)
		_action_time_remaining = 0.0
	elif global_position.x > max_x:
		global_position.x = max_x
		velocity.x = minf(velocity.x, 0.0)
		_action_time_remaining = 0.0

	if global_position.y < min_y:
		global_position.y = min_y
		velocity.y = maxf(velocity.y, 0.0)
	elif global_position.y >= floor_y and velocity.y >= 0.0:
		global_position.y = floor_y
		velocity.y = 0.0
		_area_floor_contact = true
	else:
		_area_floor_contact = false


func _update_facing() -> void:
	if velocity.x < -0.1:
		_sprite.flip_h = true
	elif velocity.x > 0.1:
		_sprite.flip_h = false


func _min_x() -> float:
	return _bounds_min.x + body_half_width


func _max_x() -> float:
	return _bounds_max.x - body_half_width


func _min_y() -> float:
	return _bounds_min.y + body_half_height


func _floor_y() -> float:
	return _bounds_max.y - body_half_height
