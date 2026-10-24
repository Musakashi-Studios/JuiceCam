@tool
extends CanvasLayer

## Screen-space letterbox bars for one JuiceCam2D cinematic.
## This node is created at runtime and follows the camera's nearest Viewport.

const CANVAS_LAYER: int = 100

var _camera: Node2D
var _bars_enabled: bool = true
var _bar_height_ratio: float = 0.1
var _transition_time: float = 0.35
var _sequence_active: bool = false
var _bars_requested: bool = false
var _progress: float = 0.0
var _transition: Tween
var _root: Control
var _top_bar: ColorRect
var _bottom_bar: ColorRect


func _ready() -> void:
	layer = CANVAS_LAYER
	_root = Control.new()
	_root.name = "Bars"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_top_bar = ColorRect.new()
	_top_bar.name = "TopBar"
	_top_bar.color = Color.BLACK
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_root.add_child(_top_bar)

	_bottom_bar = ColorRect.new()
	_bottom_bar.name = "BottomBar"
	_bottom_bar.color = Color.BLACK
	_bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_root.add_child(_bottom_bar)
	_root.visibility_changed.connect(_apply_progress)
	_apply_progress()


func configure(
	camera: Node2D,
	bars_enabled: bool,
	bar_height_percent: float,
	transition_time: float
) -> void:
	_camera = camera
	_bars_enabled = bars_enabled
	_bar_height_ratio = clampf(bar_height_percent / 100.0, 0.0, 0.25)
	_transition_time = maxf(transition_time, 0.0)
	if is_instance_valid(_camera):
		if _camera.has_signal("cinematic_started"):
			_camera.connect("cinematic_started", _on_cinematic_started)
		if _camera.has_signal("cinematic_completed"):
			_camera.connect("cinematic_completed", _on_cinematic_ended)
		if _camera.has_signal("cinematic_stopped"):
			_camera.connect("cinematic_stopped", _on_cinematic_ended)
		var viewport: Viewport = _camera.get_viewport()
		if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
			viewport.size_changed.connect(_on_viewport_size_changed)
		_sequence_active = bool(_camera.call("is_cinematic_playing"))
	set_process(_sequence_active)
	_apply_progress()
	_refresh_visibility()


func update_settings(bars_enabled: bool, bar_height_percent: float, transition_time: float) -> void:
	_bars_enabled = bars_enabled
	_bar_height_ratio = clampf(bar_height_percent / 100.0, 0.0, 0.25)
	_transition_time = maxf(transition_time, 0.0)
	_apply_progress()
	_refresh_visibility()


func _process(_delta: float) -> void:
	_refresh_visibility()


func _on_cinematic_started(_sequence_name: StringName) -> void:
	_sequence_active = true
	set_process(true)
	_refresh_visibility()


func _on_cinematic_ended(_sequence_name: StringName) -> void:
	_sequence_active = false
	set_process(false)
	_refresh_visibility()


func _on_viewport_size_changed() -> void:
	_apply_progress()


func _refresh_visibility() -> void:
	var should_show: bool = (
		_sequence_active
		and _bars_enabled
		and is_instance_valid(_camera)
		and bool(_camera.call("is_current"))
	)
	if should_show == _bars_requested:
		return
	_bars_requested = should_show
	_animate_to(1.0 if should_show else 0.0)


func _animate_to(target: float) -> void:
	if _transition != null and _transition.is_running():
		_transition.kill()
	if _transition_time <= 0.0 or is_equal_approx(_progress, target):
		_set_progress(target)
		return
	_transition = create_tween()
	_transition.set_trans(Tween.TRANS_CUBIC)
	_transition.set_ease(Tween.EASE_OUT if target > _progress else Tween.EASE_IN)
	_transition.tween_method(_set_progress, _progress, target, _transition_time)


func _set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	_apply_progress()


func _apply_progress() -> void:
	if not is_instance_valid(_root) or not is_instance_valid(_top_bar) or not is_instance_valid(_bottom_bar):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var bar_height: float = maxf(viewport_size.y * _bar_height_ratio, 0.0)
	var top_offset: float = -bar_height * (1.0 - _progress)
	_top_bar.offset_top = top_offset
	_top_bar.offset_bottom = top_offset + bar_height
	var bottom_offset: float = -bar_height * _progress
	_bottom_bar.offset_top = bottom_offset
	_bottom_bar.offset_bottom = bottom_offset + bar_height
