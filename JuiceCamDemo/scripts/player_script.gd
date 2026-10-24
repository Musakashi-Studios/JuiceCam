extends CharacterBody2D


@export_group("Movement")
@export var max_speed: float = 500.0
@export var ground_start_smoothing: float = 12.0
@export var ground_stop_smoothing: float = 12.0
@export var air_start_smoothing: float = 12.0
@export var air_stop_smoothing: float = 12.0

@export_group("Jump")
@export var jump_velocity: float = -500.0
@export_range(0.1, 4.0, 0.05) var ascent_gravity_multiplier: float = 1.6
@export var fall_gravity_multiplier: float = 1.6
@export var max_fall_speed: float = 1200.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

@onready var _player_sprite: Sprite2D = $PlayerSprite

var _jump_requested: bool = false
var _coyote_time_remaining: float = 0.0
var _jump_buffer_remaining: float = 0.0


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event: InputEventKey = event as InputEventKey
	var gameplay_key: bool = key_event.physical_keycode in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE]
	for action: StringName in [&"ui_left", &"ui_right", &"ui_up", &"ui_down", &"ui_accept"]:
		if InputMap.event_is_action(key_event, action):
			gameplay_key = true
			break
	if gameplay_key:
		# Keep gameplay keys from activating focused HUD controls. Input's global
		# action state remains available to _physics_process for movement and jump.
		get_viewport().set_input_as_handled()

	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode in [KEY_W, KEY_SPACE]:
		_jump_requested = true
	elif key_event.physical_keycode == KEY_F:
		var camera: JuiceCam2D = get_tree().current_scene.get_node_or_null("JuiceCam2D") as JuiceCam2D
		if is_instance_valid(camera):
			var shake: JuiceCamScreenShake2D = camera.get_addon("screen_shake") as JuiceCamScreenShake2D
			if is_instance_valid(shake):
				shake.shake()


func _physics_process(delta: float) -> void:
	var grounded: bool = is_on_floor()
	if not grounded:
		var gravity: Vector2 = get_gravity()
		if velocity.y < 0.0:
			gravity *= ascent_gravity_multiplier
		elif velocity.y > 0.0:
			gravity *= fall_gravity_multiplier
		velocity += gravity * delta
		velocity.y = minf(velocity.y, max_fall_speed)

	var jump_pressed: bool = (
		_jump_requested
		or Input.is_action_just_pressed("ui_up")
		or Input.is_action_just_pressed("ui_accept")
	)
	_jump_requested = false
	if jump_pressed:
		_jump_buffer_remaining = jump_buffer_time
	else:
		_jump_buffer_remaining = maxf(_jump_buffer_remaining - delta, 0.0)

	if grounded:
		_coyote_time_remaining = coyote_time
	else:
		_coyote_time_remaining = maxf(_coyote_time_remaining - delta, 0.0)

	var jump_is_buffered: bool = jump_pressed or _jump_buffer_remaining > 0.0
	var can_jump: bool = grounded or _coyote_time_remaining > 0.0
	if jump_is_buffered and can_jump:
		# Increase launch speed with gravity so the apex height stays constant.
		velocity.y = jump_velocity * sqrt(ascent_gravity_multiplier)
		_jump_buffer_remaining = 0.0
		_coyote_time_remaining = 0.0

	var direction: float = Input.get_axis("ui_left", "ui_right")
	if Input.is_physical_key_pressed(KEY_D):
		direction += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		direction -= 1.0
	direction = clampf(direction, -1.0, 1.0)
	
	var has_movement_input: bool = not is_zero_approx(direction)
	var target_horizontal_speed: float = direction * max_speed if has_movement_input else 0.0
	var smoothing_rate: float
	if grounded:
		smoothing_rate = ground_start_smoothing if has_movement_input else ground_stop_smoothing
	else:
		smoothing_rate = air_start_smoothing if has_movement_input else air_stop_smoothing
	var smoothing_weight: float = 1.0 - exp(-smoothing_rate * delta)
	velocity.x = lerpf(velocity.x, target_horizontal_speed, smoothing_weight)
	if velocity.x < 0.0:
		_player_sprite.flip_h = true
	elif velocity.x > 0.0:
		_player_sprite.flip_h = false

	move_and_slide()
