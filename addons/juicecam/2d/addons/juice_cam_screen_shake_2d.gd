@tool
class_name JuiceCamScreenShake2D
extends JuiceCamOutputModifier2D

## Camera-local trauma shake. Runtime state belongs to this camera's private add-on copy.

signal shake_started
signal shake_finished

enum ShakeType {
	VERTICAL,
	HORIZONTAL,
	RANDOM,
	PERLIN,
	ROTATE,
	CIRCULAR,
	ZOOM,
}

enum Preset {
	CUSTOM,
	GUNSHOT,
	EARTHQUAKE,
	HANDHELD,
	EXPLOSION,
	IMPACT,
	RUMBLE,
	VIBRATION,
	WOBBLY,
}

var _suspend_changed_notification: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _noise: FastNoiseLite = FastNoiseLite.new()
var _is_shaking: bool = false
var _elapsed: float = 0.0
var _active_trauma: float = 0.0

@export_group("Preset")
@export var preset: Preset = Preset.CUSTOM:
	set(value):
		if preset == value:
			return
		preset = value
		if preset != Preset.CUSTOM:
			_suspend_changed_notification = true
			_apply_preset_values(preset)
			_suspend_changed_notification = false
		_notify_configuration_changed()

@export_group("Shake")
## Controls how quickly the shake pattern changes.
@export_range(0.0, 100.0, 0.1, "or_greater") var speed: float = 15.0:
	set(value):
		var new_value: float = maxf(0.0, value)
		if is_equal_approx(speed, new_value):
			return
		speed = new_value
		_notify_configuration_changed()
## Position amplitude in world pixels before trauma falloff.
@export_range(0.0, 1000.0, 0.1, "or_greater", "suffix:px") var intensity: float = 10.0:
	set(value):
		var new_value: float = maxf(0.0, value)
		if is_equal_approx(intensity, new_value):
			return
		intensity = new_value
		_notify_configuration_changed()
## Selects the shake channels that contribute to this effect.
@export_flags("Vertical", "Horizontal", "Random", "Perlin", "Rotate", "Circular", "Zoom")
var shake_type: int = (1 << ShakeType.VERTICAL) | (1 << ShakeType.HORIZONTAL) | (1 << ShakeType.PERLIN):
	set(value):
		if shake_type == value:
			return
		shake_type = value
		_notify_configuration_changed()

@export_group("Timing")
## Initial trauma strength. Runtime calls can override or add to this value.
@export_range(0.0, 1.0, 0.01) var trauma: float = 1.0:
	set(value):
		var new_value: float = clampf(value, 0.0, 1.0)
		if is_equal_approx(trauma, new_value):
			return
		trauma = new_value
		_notify_configuration_changed()
## Time to reach full strength after shake() is called.
@export_range(0.0, 10.0, 0.01, "suffix:s") var trauma_attack: float = 0.0:
	set(value):
		var new_value: float = maxf(0.0, value)
		if is_equal_approx(trauma_attack, new_value):
			return
		trauma_attack = new_value
		_notify_configuration_changed()
## Full-strength duration before fading out. Ignored when endless is enabled.
@export_range(0.0, 60.0, 0.01, "suffix:s") var duration: float = 0.5:
	set(value):
		var new_value: float = maxf(0.0, value)
		if is_equal_approx(duration, new_value):
			return
		duration = new_value
		_notify_configuration_changed()
## Time to fade from full trauma to zero after duration.
@export_range(0.0, 60.0, 0.01, "suffix:s") var trauma_decay: float = 0.8:
	set(value):
		var new_value: float = maxf(0.0, value)
		if is_equal_approx(trauma_decay, new_value):
			return
		trauma_decay = new_value
		_notify_configuration_changed()
## Keeps the shake at full strength after its attack until stop() is called.
@export var endless: bool = false:
	set(value):
		if endless == value:
			return
		endless = value
		_notify_configuration_changed()


func _init() -> void:
	if addon_id.is_empty():
		addon_id = "screen_shake"


func setup(_camera: Node2D) -> void:
	_rng.randomize()
	_noise.seed = _rng.randi()
	_noise.frequency = 0.05
	_noise.fractal_octaves = 2
	_noise.fractal_gain = 0.8
	_noise.fractal_lacunarity = 2.0
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN


func runs_during_cinematics() -> bool:
	return true


func exit(_camera: Node2D) -> void:
	_is_shaking = false
	_elapsed = 0.0
	_active_trauma = 0.0


func modify_output(frame: JuiceCamAddonFrame2D) -> void:
	if not _is_shaking:
		return

	if frame.delta > 0.0:
		_elapsed += frame.delta

	var total_duration: float = trauma_attack + duration + trauma_decay
	if not endless and (total_duration <= 0.0 or _elapsed >= total_duration):
		_finish_shake()
		return

	var current_trauma: float = _get_current_trauma()
	var shake_amount: float = current_trauma * current_trauma
	if shake_amount <= 0.0:
		return

	var position_offset: Vector2 = Vector2.ZERO
	var rotation_offset: float = 0.0
	var zoom_offset: float = 0.0
	var time_sample: float = _elapsed * speed

	if shake_type & (1 << ShakeType.VERTICAL):
		position_offset.y += sin(time_sample) * intensity * shake_amount
	if shake_type & (1 << ShakeType.HORIZONTAL):
		position_offset.x += sin(time_sample + 1000.0) * intensity * shake_amount
	if shake_type & (1 << ShakeType.RANDOM):
		position_offset += Vector2(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0)
		) * intensity * shake_amount
	if shake_type & (1 << ShakeType.PERLIN):
		position_offset += Vector2(
			_noise.get_noise_1d(_elapsed * speed * 100.0),
			_noise.get_noise_1d((_elapsed + 1000.0) * speed * 100.0)
		) * intensity * shake_amount
	if shake_type & (1 << ShakeType.ROTATE):
		rotation_offset = sin(time_sample) * intensity * 0.002 * shake_amount
	if shake_type & (1 << ShakeType.CIRCULAR):
		var angle: float = time_sample
		position_offset += Vector2(cos(angle), sin(angle)) * intensity * 0.5 * shake_amount
	if shake_type & (1 << ShakeType.ZOOM):
		zoom_offset = sin(time_sample * 10.0) * intensity * 0.0005 * shake_amount

	frame.output_position_offset += position_offset
	frame.output_rotation_offset += rotation_offset
	frame.output_zoom_multiplier *= Vector2.ONE * (1.0 + zoom_offset)


## Starts or restarts a shake using the configured trauma, or an optional 0..1 strength.
func shake(trauma_amount: float = -1.0) -> void:
	var requested_trauma: float = trauma if trauma_amount < 0.0 else clampf(trauma_amount, 0.0, 1.0)
	if requested_trauma <= 0.0:
		stop()
		return
	_active_trauma = requested_trauma
	_elapsed = 0.0
	_is_shaking = true
	shake_started.emit()


## Adds trauma to the current shake, capped at 1.0. Starts a new shake if idle.
func add_trauma(amount: float) -> void:
	if amount <= 0.0:
		return
	if not _is_shaking:
		shake(amount)
		return
	_active_trauma = minf(1.0, _active_trauma + amount)


## Immediately stops this add-on's active shake.
func stop() -> void:
	if _is_shaking:
		_finish_shake()


func is_shaking() -> bool:
	return _is_shaking


func get_current_trauma() -> float:
	return _get_current_trauma() if _is_shaking else 0.0


## Applies one of the built-in presets to this add-on's configuration.
func apply_preset(value: Preset) -> void:
	if value == Preset.CUSTOM:
		preset = value
		return
	if preset != value:
		preset = value
		return
	_suspend_changed_notification = true
	_apply_preset_values(value)
	_suspend_changed_notification = false
	_notify_configuration_changed()


func _get_current_trauma() -> float:
	if trauma_attack > 0.0 and _elapsed < trauma_attack:
		return _active_trauma * (_elapsed / trauma_attack)
	if endless:
		return _active_trauma

	var sustain_end: float = trauma_attack + duration
	if _elapsed < sustain_end:
		return _active_trauma
	if trauma_decay <= 0.0:
		return 0.0
	var fade_progress: float = clampf((_elapsed - sustain_end) / trauma_decay, 0.0, 1.0)
	return _active_trauma * (1.0 - fade_progress)


func _finish_shake() -> void:
	var was_shaking: bool = _is_shaking
	_is_shaking = false
	_elapsed = 0.0
	_active_trauma = 0.0
	if was_shaking:
		shake_finished.emit()


func _apply_preset_values(value: Preset) -> void:
	match value:
		Preset.GUNSHOT:
			_set_properties(
				70.0, 2.0, _mask(ShakeType.HORIZONTAL, ShakeType.VERTICAL),
				1.0, 0.05, 0.1, 0.1
			)
		Preset.EARTHQUAKE:
			_set_properties(
				15.0, 5.0, _mask(ShakeType.HORIZONTAL, ShakeType.VERTICAL, ShakeType.PERLIN),
				0.7, 0.3, 5.0, 3.0
			)
		Preset.HANDHELD:
			_set_properties(
				1.0, 5.0, _mask(ShakeType.PERLIN, ShakeType.ROTATE),
				0.3, 0.1, 0.0, 0.0, true
			)
		Preset.EXPLOSION:
			_set_properties(
				30.0, 5.0, _mask(ShakeType.RANDOM, ShakeType.ZOOM),
				1.0, 0.1, 0.5, 0.5
			)
		Preset.IMPACT:
			_set_properties(
				80.0, 3.0, _mask(ShakeType.VERTICAL, ShakeType.ROTATE),
				1.0, 0.05, 0.2, 0.5
			)
		Preset.RUMBLE:
			_set_properties(
				10.0, 2.0, _mask(ShakeType.HORIZONTAL, ShakeType.VERTICAL, ShakeType.PERLIN),
				0.5, 0.2, 1.0, 0.5
			)
		Preset.VIBRATION:
			_set_properties(
				100.0, 1.0, _mask(ShakeType.HORIZONTAL, ShakeType.VERTICAL),
				0.8, 0.05, 0.1, 1.0
			)
		Preset.WOBBLY:
			_set_properties(
				5.0, 5.0, _mask(ShakeType.ROTATE, ShakeType.PERLIN),
				0.6, 0.2, 1.5, 1.0
			)


func _set_properties(
	p_speed: float,
	p_intensity: float,
	p_shake_type: int,
	p_trauma: float,
	p_attack: float,
	p_decay: float,
	p_duration: float,
	p_endless: bool = false
) -> void:
	speed = p_speed
	intensity = p_intensity
	shake_type = p_shake_type
	trauma = p_trauma
	trauma_attack = p_attack
	trauma_decay = p_decay
	duration = p_duration
	endless = p_endless


func _mask(first: ShakeType, second: ShakeType, third: int = -1) -> int:
	var result: int = (1 << first) | (1 << second)
	if third >= 0:
		result |= 1 << third
	return result


func _notify_configuration_changed() -> void:
	if not _suspend_changed_notification:
		emit_changed()
