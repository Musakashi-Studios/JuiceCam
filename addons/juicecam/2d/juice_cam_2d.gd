@tool
@icon("res://addons/juicecam/icons/juice_cam_2d.png")
class_name JuiceCam2D
extends Node2D

## Target-following Camera2D controller with weighted targets, smoothing, and group framing.

const JuiceCamTargetSet2DScript: GDScript = preload("res://addons/juicecam/2d/juice_cam_target_set_2d.gd")
const JuiceCamAddonFrame2DScript: GDScript = preload("res://addons/juicecam/2d/addons/juice_cam_addon_frame_2d.gd")
const JuiceMathScript: GDScript = preload("res://addons/juicecam/core/juice_math.gd")
const JuiceFraming: GDScript = preload("res://addons/juicecam/core/juice_framing.gd")
const JuiceCamInfluenceRegistry2DScript: GDScript = preload(
	"res://addons/juicecam/2d/juice_cam_influence_registry_2d.gd"
)
const JuiceCamCinematicPlayer2DScript: GDScript = preload(
	"res://addons/juicecam/2d/juice_cam_cinematic_player_2d.gd"
)
const JuiceCamCinematicBars2DScript: GDScript = preload(
	"res://addons/juicecam/2d/juice_cam_cinematic_bars_2d.gd"
)
const DEBUG_CAMERA_MARKER_RADIUS: float = 12.0
const DEBUG_DESTINATION_MARKER_RADIUS: float = 8.0
const DEBUG_LOOKAHEAD_SQUARE_SCALE: float = 0.5
const DEBUG_STROKE_WIDTH: float = -1.0
## Search radius for nearby room, magnet, and zoom influences, in world units.
const INFLUENCE_SEARCH_RADIUS: float = 2000.0
const DEBUG_DRAW_COLOR: Color = JuiceCamDebugPalette2D.CAMERA

signal cinematic_started(sequence_name: StringName)
signal cinematic_stopped(sequence_name: StringName)
signal cinematic_completed(sequence_name: StringName)
signal cinematic_not_found(sequence_name: StringName)
signal cinematic_point_started(sequence_name: StringName, point: JuiceCamCinematic2D)
signal cinematic_point_arrived(sequence_name: StringName, point: JuiceCamCinematic2D)
signal cinematic_point_completed(sequence_name: StringName, point: JuiceCamCinematic2D)

# --- Enums ---

enum DampingType {
	SMOOTH_DAMP,         ## Critically damped spring (zero overshoot, smooth arrival)
	SPRING_DAMP,         ## Physical harmonic oscillator (supports bounce & oscillations)
	EXPONENTIAL_DECAY,   ## Framerate-independent exponential smoothing
}

enum ProcessCallback {
	IDLE,        ## Updates in _process (best for standard animations and smooth display)
	PHYSICS,     ## Updates in _physics_process (best for physics bodies to avoid jitter)
}

@export_group("Motion")

## Whether camera motion is smoothed using math damping or snaps instantly to target.
@export var smooth_motion: bool = true

## Mathematical smoothing algorithm used when smooth_motion is enabled.
@export var damping_type: DampingType = DampingType.SMOOTH_DAMP:
	set(value):
		if damping_type == value:
			return
		damping_type = value
		notify_property_list_changed()

## Smooth arrival duration in seconds for SMOOTH_DAMP (smaller = faster, larger = smoother).
@export_range(0.001, 2.0, 0.01, "suffix:s") var smooth_time: float = 0.2

## Oscillation frequency in Hz for SPRING_DAMP.
@export_range(0.1, 30.0, 0.1, "suffix:Hz") var spring_frequency: float = 5.0

## Damping ratio for SPRING_DAMP (1.0 = critically damped, <1.0 = bouncy, >1.0 = sluggish).
@export_range(0.1, 3.0, 0.05) var spring_damping: float = 1.0

## Speed rate for EXPONENTIAL_DECAY.
@export_range(0.1, 50.0, 0.5) var decay_rate: float = 8.0

## Maximum camera movement speed limit in pixels per second (INF = unlimited).
@export var max_speed: float = INF

@export_group("Rotation")

## Whether the camera rotates to match the target's rotation.
@export var allow_rotation: bool = false

## Whether camera rotation interpolates smoothly or snaps instantly.
@export var smooth_rotation: bool = true

## Duration in seconds for smooth rotation arrival along the shortest circular path.
@export_range(0.001, 2.0, 0.01, "suffix:s") var smooth_rotation_time: float = 0.2

## Additional rotation offset added to the camera angle in degrees.
@export_range(-180.0, 180.0, 0.1, "suffix:deg") var rotation_offset_degrees: float = 0.0

@export_group("Zoom")

## Minimum allowable zoom scale per axis to prevent projection matrix singularity and divide-by-zero errors.
const MIN_ZOOM: float = 0.001

## Target zoom scale (1.0 = normal, 2.0 = 2x zoomed in, 0.5 = 2x zoomed out).
## Clamped to never be (0, 0) to prevent division by zero or projection matrix collapse.
@export_custom(PROPERTY_HINT_LINK, "") var zoom: Vector2 = Vector2.ONE:
	set(value):
		if not (value is Vector2) or value == null:
			zoom = Vector2.ONE
		else:
			zoom = clamp_zoom(value as Vector2)

## Whether camera zoom interpolates smoothly or snaps instantly.
@export var smooth_zoom: bool = true

## Duration in seconds for smooth zoom arrival.
@export_range(0.001, 2.0, 0.01, "suffix:s") var smooth_zoom_time: float = 0.2

@export_group("Cinematic Presentation")

## Slides screen-space letterbox bars in for active cinematics and out when playback ends.
@export var cinematic_bars_enabled: bool = true:
	set(value):
		cinematic_bars_enabled = value
		_update_cinematic_bars()

## Height of each bar as a percentage of its camera viewport's height.
@export_range(0.0, 25.0, 0.5, "suffix:%") var cinematic_bar_height: float = 10.0:
	set(value):
		cinematic_bar_height = clampf(value, 0.0, 25.0)
		_update_cinematic_bars()

## Time taken for the bars to slide in or out.
@export_range(0.0, 2.0, 0.01, "suffix:s") var cinematic_bar_transition_time: float = 0.35:
	set(value):
		cinematic_bar_transition_time = maxf(value, 0.0)
		_update_cinematic_bars()

@export_group("Auto Framing")

## Whether camera automatically adjusts zoom to keep all targets framed inside the viewport.
@export var auto_framing: bool = true

## Viewport safety margin ratio (e.g. 0.8 = uses 80% of screen, leaving 10% margin on all sides).
@export_range(0.2, 0.98, 0.02) var framing_margin: float = 0.8

## Minimum camera zoom allowed during auto-framing (furthest zoomed out).
@export_range(0.01, 2.0, 0.01) var min_framing_zoom: float = 0.2

## Maximum camera zoom allowed during auto-framing (closest zoomed in).
@export_range(0.5, 10.0, 0.1) var max_framing_zoom: float = 1.0

## Adds framing clearance to targets whose weight is above 1.0.
@export_range(0.0, 5.0, 0.1) var weight_space_factor: float = 1.0

@export_group("Limits")

## Keeps the camera's entire visible area inside the configured world bounds.
@export var limits_enabled: bool = false

## Clamps the desired destination to the bounds before smoothing, while a final hard clamp always applies.
@export var smooth_limits: bool = true

@export_subgroup("World Bounds", "limit_")
## Left edge of the permitted world area.
@export var limit_left: float = -10000000.0

## Right edge of the permitted world area.
@export var limit_right: float = 10000000.0

## Top edge of the permitted world area.
@export var limit_top: float = -10000000.0

## Bottom edge of the permitted world area.
@export var limit_bottom: float = 10000000.0

@export_group("Dead Zone")

## Keeps one influential target inside horizontal camera-local deadzone margins.
@export var horizontal_deadzone_enabled: bool = false

## Keeps one influential target inside vertical camera-local deadzone margins.
@export var vertical_deadzone_enabled: bool = false

## Left deadzone edge as a fraction of half the visible viewport width.
@export_range(0.0, 1.0, 0.01) var deadzone_left_margin: float = 0.3:
	set(value):
		deadzone_left_margin = clampf(value, 0.0, 1.0)

## Right deadzone edge as a fraction of half the visible viewport width.
@export_range(0.0, 1.0, 0.01) var deadzone_right_margin: float = 0.3:
	set(value):
		deadzone_right_margin = clampf(value, 0.0, 1.0)

## Top deadzone edge as a fraction of half the visible viewport height.
@export_range(0.0, 1.0, 0.01) var deadzone_top_margin: float = 0.3:
	set(value):
		deadzone_top_margin = clampf(value, 0.0, 1.0)

## Bottom deadzone edge as a fraction of half the visible viewport height.
@export_range(0.0, 1.0, 0.01) var deadzone_bottom_margin: float = 0.3:
	set(value):
		deadzone_bottom_margin = clampf(value, 0.0, 1.0)

@export_group("Add-ons")

## Optional per-camera add-on resources. Each camera gets its own runtime copy.
@export var addons: Array[JuiceCamAddon2D] = []:
	set(value):
		_disconnect_addon_configs()
		addons = value.duplicate()
		_connect_addon_configs()
		_addons_initialized = false
		if is_inside_tree():
			_rebuild_runtime_addons()

@export_group("Debug")

## Enables live motion tracking preview while in the Godot Editor.
@export var editor_preview: bool = true

## Update in IDLE for smooth rendered motion, or PHYSICS to sync with physics-driven targets.
@export var process_callback: ProcessCallback = ProcessCallback.IDLE:
	set(value):
		process_callback = value
		_update_process_mode()

## Enables camera and influence diagnostics at runtime. Editor diagnostics are always visible.
@export var debug_draw_enabled: bool = false:
	set(value):
		if debug_draw_enabled == value:
			return
		debug_draw_enabled = value
		if is_inside_tree():
			queue_redraw()
			if _influence_registry != null:
				_influence_registry.set_camera_debug(
					self,
					value and not Engine.is_editor_hint()
				)
			_update_cinematic_debug_nodes(value and not Engine.is_editor_hint())

# --- Target State ---
var _target_set: JuiceCamTargetSet2D = null

# --- Motion State ---
var _current_velocity: Vector2 = Vector2.ZERO
var _current_rotation_velocity: float = 0.0
var _current_zoom: Vector2 = Vector2.ONE
var _current_zoom_velocity: Vector2 = Vector2.ZERO
var _deadzone_anchor_position: Vector2 = Vector2.ZERO
var _deadzone_active: bool = false
var _debug_unclamped_target_position: Vector2 = Vector2.ZERO
var _invalid_limits_warning_issued: bool = false

# --- Internal Camera Reference ---
var _camera: Camera2D = null

# --- Shared World Influence Registry ---
var _influence_registry: JuiceCamInfluenceRegistry2D = null
var _influence_candidates: Array[Node2D] = []
var _path_candidates: Array[Node2D] = []
var _influence_candidate_ids: Dictionary[int, bool] = {}
var _stale_influence_ids: Array[int] = []
var _active_influences: Dictionary[int, Node2D] = {}
var _active_room: JuiceCamRoom2D = null
var _active_path: JuiceCamPath2D = null
var _room_final_clamp_room: JuiceCamRoom2D = null
var _room_final_clamp_active: bool = false
var _room_final_clamp_allowed_this_frame: bool = true
var _room_independent_output_position_offset: Vector2 = Vector2.ZERO
var _influence_query_bounds: Rect2 = Rect2()

# --- Per-camera Add-on Runtime ---
var _addon_frame: JuiceCamAddonFrame2D
var _runtime_addons: Array[JuiceCamAddon2D] = []
var _target_modifiers: Array[JuiceCamTargetModifier2D] = []
var _output_modifiers: Array[JuiceCamOutputModifier2D] = []
var _addons_by_id: Dictionary = {}
var _addons_initialized: bool = false
var _setup_addons: Array[JuiceCamAddon2D] = []
var _cinematic_player: JuiceCamCinematicPlayer2D
var _cinematic_bars: CanvasLayer


func _init() -> void:
	_current_zoom = clamp_zoom(zoom)
	_target_set = JuiceCamTargetSet2DScript.new() as JuiceCamTargetSet2D
	_addon_frame = JuiceCamAddonFrame2DScript.new() as JuiceCamAddonFrame2D
	_cinematic_player = JuiceCamCinematicPlayer2DScript.new() as JuiceCamCinematicPlayer2D
	_cinematic_player.cinematic_started.connect(_on_cinematic_started)
	_cinematic_player.cinematic_stopped.connect(_on_cinematic_stopped)
	_cinematic_player.cinematic_completed.connect(_on_cinematic_completed)
	_cinematic_player.cinematic_not_found.connect(_on_cinematic_not_found)
	_cinematic_player.cinematic_point_started.connect(_on_cinematic_point_started)
	_cinematic_player.cinematic_point_arrived.connect(_on_cinematic_point_arrived)
	_cinematic_player.cinematic_point_completed.connect(_on_cinematic_point_completed)


## Clamps a zoom vector so neither component can be zero or within (-MIN_ZOOM, MIN_ZOOM).
static func clamp_zoom(val: Vector2) -> Vector2:
	var zx: float = val.x
	var zy: float = val.y
	if absf(zx) < MIN_ZOOM:
		zx = MIN_ZOOM if zx >= 0.0 else -MIN_ZOOM
	if absf(zy) < MIN_ZOOM:
		zy = MIN_ZOOM if zy >= 0.0 else -MIN_ZOOM
	return Vector2(zx, zy)


func _enter_tree() -> void:
	add_to_group(JuiceCamCinematic2D.CAMERA_GROUP_NAME)
	_isolate_transform_from_parent()
	get_all_targets()
	_influence_registry = JuiceCamInfluenceRegistry2DScript.get_for_tree(get_tree())
	_influence_registry.set_camera_debug(
		self,
		debug_draw_enabled and not Engine.is_editor_hint()
	)
	_update_cinematic_debug_nodes(debug_draw_enabled and not Engine.is_editor_hint())
	_ensure_internal_camera()
	_ensure_cinematic_bars()
	_connect_addon_configs()
	_rebuild_runtime_addons()
	_update_process_mode()
	if Engine.is_editor_hint() or debug_draw_enabled:
		queue_redraw()


func _isolate_transform_from_parent() -> void:
	if is_set_as_top_level():
		return
	if not get_parent() is CanvasItem:
		return

	var world_transform: Transform2D = global_transform
	set_as_top_level(true)
	global_transform = world_transform


func _exit_tree() -> void:
	_cinematic_player.stop()
	_disconnect_addon_configs()
	_forget_cinematic_debug_nodes()
	if _influence_registry != null:
		_influence_registry.forget_camera(self)
	_influence_registry = null
	_influence_candidates.clear()
	_path_candidates.clear()
	_influence_candidate_ids.clear()
	_stale_influence_ids.clear()
	_active_influences.clear()
	_active_room = null
	_active_path = null
	_room_final_clamp_room = null
	_room_final_clamp_active = false
	_room_final_clamp_allowed_this_frame = true
	_influence_query_bounds = Rect2()
	_clear_runtime_addons()
	_addons_initialized = false
	_cleanup_cinematic_bars()
	_cleanup_internal_camera()


func _update_cinematic_debug_nodes(draw_enabled: bool) -> void:
	if not is_inside_tree():
		return
	var camera_viewport: Viewport = get_viewport()
	for candidate: Node in get_tree().get_nodes_in_group(JuiceCamCinematic2D.GROUP_NAME):
		if not candidate is JuiceCamCinematic2D:
			continue
		var point: JuiceCamCinematic2D = candidate as JuiceCamCinematic2D
		if point.get_viewport() == camera_viewport:
			point.set_camera_debug(self, draw_enabled)


func _forget_cinematic_debug_nodes() -> void:
	if not is_inside_tree():
		return
	for candidate: Node in get_tree().get_nodes_in_group(JuiceCamCinematic2D.GROUP_NAME):
		if candidate is JuiceCamCinematic2D:
			(candidate as JuiceCamCinematic2D).forget_camera(self)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or process_callback == ProcessCallback.IDLE:
		_tick(delta)


func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint() and process_callback == ProcessCallback.PHYSICS:
		_tick(delta)


func _tick(delta: float) -> void:
	if Engine.is_editor_hint() and not editor_preview:
		queue_redraw()
		return
	update_camera_motion(delta)


## Updates camera tracking towards target centroid.
func update_camera_motion(delta: float) -> void:
	_ensure_runtime_addons()
	var cinematic_point: JuiceCamCinematic2D = _cinematic_player.get_current_point()
	_room_final_clamp_allowed_this_frame = cinematic_point == null
	var target_data: Array[JuiceCamTargetData] = get_all_targets()
	_addon_frame.camera = self
	_addon_frame.delta = delta
	_addon_frame.viewport_size = _get_effective_viewport_size() if not _runtime_addons.is_empty() else Vector2.ZERO
	_addon_frame.has_target = _target_set.has_influential_targets() or cinematic_point != null
	_addon_frame.is_cinematic = cinematic_point != null
	_addon_frame.target_speed = _target_set.update_tracking_data(
		delta,
		_get_lookahead_damping_rate()
	)
	_addon_frame.current_position = global_position
	_addon_frame.current_rotation = global_rotation
	_addon_frame.current_zoom = _current_zoom

	var focus_position: Vector2 = global_position
	if cinematic_point != null:
		focus_position = cinematic_point.global_position
	elif _addon_frame.has_target:
		focus_position = _calculate_tracking_centroid(target_data)

	if cinematic_point != null:
		_update_cinematic_influence_overlaps(focus_position)
		var cinematic_rotation: float = cinematic_point.global_rotation
		var cinematic_zoom: Vector2 = clamp_zoom(cinematic_point.target_zoom)
		var cinematic_target_position: Vector2 = cinematic_point.global_position
		if limits_enabled:
			var limits_rect: Rect2 = _get_limits_rect()
			if _is_valid_limits_rect(limits_rect):
				cinematic_zoom = _fit_zoom_to_limits(cinematic_zoom, cinematic_rotation, limits_rect)
				cinematic_target_position = _clamp_position_to_limits(
					cinematic_target_position,
					cinematic_zoom,
					cinematic_rotation,
					limits_rect
				)
		_update_rotation(delta, cinematic_rotation, true, cinematic_point)
		cinematic_zoom = _update_zoom_to_target(delta, cinematic_zoom, cinematic_point)
		_addon_frame.current_rotation = global_rotation
		_addon_frame.current_zoom = _current_zoom
		cinematic_target_position = _apply_target_position(delta, cinematic_target_position, cinematic_point)
		_cinematic_player.update_progress(
			delta,
			_is_cinematic_point_reached(
				cinematic_target_position,
				cinematic_rotation,
				cinematic_zoom,
				cinematic_point.hold_time > 0.0
			)
		)
	elif not _addon_frame.has_target:
		_query_influence_candidates(focus_position)
		_apply_magnet_influences(global_position, false)
		_active_room = _select_active_room(global_position)
		_update_zoom(delta, focus_position, false)
		_deadzone_anchor_position = global_position
		_deadzone_active = false
		_reset_motion_velocity()
	else:
		_query_influence_candidates(focus_position)
		var magnetized_focus: Vector2 = _apply_magnet_influences(focus_position, true)
		var target_pos: Vector2 = _apply_deadzone(magnetized_focus)
		target_pos = _modify_target_position(target_pos)
		target_pos = _apply_path_constraint(target_pos)

		# Room membership uses the constrained destination before camera smoothing.
		var previous_room: JuiceCamRoom2D = _active_room
		_active_room = _select_active_room(target_pos)
		var snap_on_room_enter: bool = (
			_active_room != null
			and _active_room != previous_room
			and _active_room.snap_on_enter
		)
		if snap_on_room_enter:
			if allow_rotation:
				if _active_room.align_camera_rotation:
					global_rotation = _active_room.global_rotation
				else:
					global_rotation = _calculate_target_rotation() + deg_to_rad(rotation_offset_degrees)
			_current_rotation_velocity = 0.0
		elif _active_room != null and _active_room.align_camera_rotation and allow_rotation:
			_update_rotation(delta, _active_room.global_rotation, true)
		else:
			_update_rotation(delta)
		_query_influence_candidates(focus_position)
		var target_zoom: Vector2 = _update_zoom(delta, focus_position, true)
		if snap_on_room_enter:
			_current_zoom = target_zoom
			_current_zoom_velocity = Vector2.ZERO
		_addon_frame.current_rotation = global_rotation
		_addon_frame.current_zoom = _current_zoom

		if _active_room != null and _active_room.is_camera_inside(self):
			target_pos = _active_room.constrain_camera_position(
				target_pos,
				target_zoom,
				global_rotation,
				get_effective_viewport_size()
			)
		_apply_target_position(delta, target_pos, null, snap_on_room_enter, false)

	if limits_enabled:
		_apply_hard_limits_to_base_pose()
	if _room_final_clamp_allowed_this_frame:
		_update_room_final_clamp_state()
	else:
		_room_final_clamp_room = null
		_room_final_clamp_active = false

	_addon_frame.current_position = global_position
	_addon_frame.current_rotation = global_rotation
	_addon_frame.current_zoom = _current_zoom
	_addon_frame.reset_output()
	_room_independent_output_position_offset = Vector2.ZERO
	for modifier: JuiceCamOutputModifier2D in _output_modifiers:
		if modifier.is_active_for_processing():
			var position_offset_before: Vector2 = _addon_frame.output_position_offset
			var rotation_offset_before: float = _addon_frame.output_rotation_offset
			var zoom_multiplier_before: Vector2 = _addon_frame.output_zoom_multiplier
			modifier.modify_output(_addon_frame)
			if _addon_frame.is_cinematic and not modifier.runs_during_cinematics():
				_addon_frame.output_position_offset = position_offset_before
				_addon_frame.output_rotation_offset = rotation_offset_before
				_addon_frame.output_zoom_multiplier = zoom_multiplier_before
			elif modifier.bypasses_room_clamp():
				_room_independent_output_position_offset += (
					_addon_frame.output_position_offset - position_offset_before
				)

	_sync_internal_camera()
	if Engine.is_editor_hint() or debug_draw_enabled:
		queue_redraw()


func _apply_target_position(
	delta: float,
	target_position: Vector2,
	cinematic_point: JuiceCamCinematic2D = null,
	snap: bool = false,
	apply_target_modifiers: bool = true
) -> Vector2:
	if apply_target_modifiers:
		target_position = _modify_target_position(target_position, cinematic_point)
	else:
		_addon_frame.target_position = target_position
		_addon_frame.is_cinematic = cinematic_point != null
	_debug_unclamped_target_position = target_position

	if limits_enabled and (smooth_limits or cinematic_point != null):
		var limits_rect: Rect2 = _get_limits_rect()
		if _is_valid_limits_rect(limits_rect):
			target_position = _clamp_position_to_limits(
				target_position,
				_current_zoom,
				global_rotation,
				limits_rect
			)
			_addon_frame.target_position = target_position
			if _deadzone_active:
				_deadzone_anchor_position = _clamp_position_to_limits(
					_deadzone_anchor_position,
					_current_zoom,
					global_rotation,
					limits_rect
				)

	if snap:
		global_position = target_position
		_current_velocity = Vector2.ZERO
		_deadzone_anchor_position = global_position
	else:
		_apply_position_motion(delta, target_position, cinematic_point)
	return target_position


func _modify_target_position(
	target_position: Vector2,
	cinematic_point: JuiceCamCinematic2D = null
) -> Vector2:
	_addon_frame.target_position = target_position
	_addon_frame.is_cinematic = cinematic_point != null
	for modifier: JuiceCamTargetModifier2D in _target_modifiers:
		if not modifier.enabled:
			continue
		var target_position_before: Vector2 = _addon_frame.target_position
		modifier.modify_target(_addon_frame)
		if cinematic_point != null and not modifier.runs_during_cinematics():
			_addon_frame.target_position = target_position_before
	return _addon_frame.target_position


func _apply_position_motion(
	delta: float,
	target_position: Vector2,
	cinematic_point: JuiceCamCinematic2D
) -> void:
	var should_smooth: bool = smooth_motion
	var effective_damping_type: int = int(damping_type)
	var effective_smooth_time: float = smooth_time
	var effective_max_speed: float = max_speed
	var effective_spring_frequency: float = spring_frequency
	var effective_spring_damping: float = spring_damping
	var effective_decay_rate: float = decay_rate
	if cinematic_point != null and cinematic_point.override_motion_settings:
		should_smooth = true
		effective_damping_type = int(cinematic_point.damping_type)
		effective_smooth_time = cinematic_point.position_smooth_time
		effective_max_speed = INF if cinematic_point.position_max_speed <= 0.0 else cinematic_point.position_max_speed
		effective_spring_frequency = cinematic_point.spring_frequency
		effective_spring_damping = cinematic_point.spring_damping
		effective_decay_rate = cinematic_point.decay_rate

	if not should_smooth or delta <= 0.0:
		global_position = target_position
		_current_velocity = Vector2.ZERO
		return

	match effective_damping_type:
		DampingType.SMOOTH_DAMP:
			var result: Array[Vector2] = JuiceMathScript.smooth_damp_2d(
				global_position,
				target_position,
				_current_velocity,
				effective_smooth_time,
				effective_max_speed,
				delta
			)
			global_position = result[0]
			_current_velocity = result[1]
		DampingType.SPRING_DAMP:
			var result: Array[Vector2] = JuiceMathScript.spring_damper_2d(
				global_position,
				target_position,
				_current_velocity,
				effective_spring_frequency,
				effective_spring_damping,
				delta
			)
			global_position = result[0]
			_current_velocity = result[1]
		DampingType.EXPONENTIAL_DECAY:
			global_position = JuiceMathScript.decay_2d(
				global_position,
				target_position,
				effective_decay_rate,
				delta
			)
			_current_velocity = Vector2.ZERO


func _get_lookahead_damping_rate() -> float:
	if not smooth_motion:
		return INF

	match damping_type:
		DampingType.SMOOTH_DAMP:
			return 1.0 / maxf(smooth_time, 0.001)
		DampingType.SPRING_DAMP:
			var natural_frequency: float = TAU * maxf(spring_frequency, 0.1)
			var damping_ratio: float = maxf(spring_damping, 0.1)
			if is_equal_approx(damping_ratio, 1.0):
				return natural_frequency * 0.63
			if damping_ratio < 1.0:
				return natural_frequency * damping_ratio
			return natural_frequency * (
				damping_ratio - sqrt(damping_ratio * damping_ratio - 1.0)
			)
		DampingType.EXPONENTIAL_DECAY:
			return decay_rate

	return 8.0


func _update_cinematic_influence_overlaps(focus_position: Vector2) -> void:
	_query_influence_candidates(focus_position)
	var selected_room: JuiceCamRoom2D = null
	for candidate: Node2D in _influence_candidates:
		if candidate is JuiceCamRoom2D:
			var room: JuiceCamRoom2D = candidate as JuiceCamRoom2D
			var room_active: bool = room.update_camera_overlap(self, focus_position)
			_set_influence_active(room, room_active)
			if room_active and (selected_room == null or room.priority > selected_room.priority):
				selected_room = room
		elif candidate is JuiceCamMagnet2D:
			var magnet: JuiceCamMagnet2D = candidate as JuiceCamMagnet2D
			var magnet_active: bool = magnet.update_camera_overlap(self, focus_position)
			_set_influence_active(magnet, magnet_active)
		elif candidate is JuiceCamZoom2D:
			var zoom_region: JuiceCamZoom2D = candidate as JuiceCamZoom2D
			var zoom_active: bool = zoom_region.update_camera_overlap(self, focus_position)
			_set_influence_active(zoom_region, zoom_active)
	_active_room = selected_room


func _is_cinematic_point_reached(
	target_position: Vector2,
	target_rotation: float,
	target_zoom: Vector2,
	wait_for_settle: bool
) -> bool:
	var pose_is_close: bool = (
		global_position.distance_squared_to(target_position) <= 1.0
		and absf(angle_difference(global_rotation, target_rotation)) <= 0.003
		and _current_zoom.distance_to(target_zoom) <= 0.002
	)
	if not pose_is_close or not wait_for_settle:
		return pose_is_close
	return (
		_current_velocity.length_squared() <= 4.0
		and absf(_current_rotation_velocity) <= 0.01
		and _current_zoom_velocity.length_squared() <= 0.0004
	)


## Draws the camera's current tracking destination and target framing radii.
func _draw() -> void:
	if not Engine.is_editor_hint() and not debug_draw_enabled:
		return

	_draw_limits_debug()
	_draw_deadzone_debug()

	var cinematic_point: JuiceCamCinematic2D = _cinematic_player.get_current_point()
	if _target_set.has_influential_targets() or cinematic_point != null:
		var tracking_position: Vector2
		if cinematic_point != null:
			tracking_position = cinematic_point.global_position
		elif Engine.is_editor_hint() and not editor_preview:
			tracking_position = calculate_target_centroid()
		elif _addon_frame.has_target:
			tracking_position = _debug_unclamped_target_position
		else:
			tracking_position = calculate_target_centroid()

		var camera_position: Vector2 = global_position
		if _camera != null and is_instance_valid(_camera):
			camera_position = _camera.global_position
		var camera_marker: Vector2 = to_local(camera_position)
		var destination_marker: Vector2 = to_local(tracking_position)
		var marker_delta: Vector2 = destination_marker - camera_marker
		var marker_distance: float = marker_delta.length()
		var direction: Vector2 = marker_delta / marker_distance if marker_distance > 0.0 else Vector2.ZERO
		if marker_distance > DEBUG_CAMERA_MARKER_RADIUS + DEBUG_DESTINATION_MARKER_RADIUS:
			draw_line(
				camera_marker + direction * DEBUG_CAMERA_MARKER_RADIUS,
				destination_marker - direction * DEBUG_DESTINATION_MARKER_RADIUS,
				DEBUG_DRAW_COLOR,
				DEBUG_STROKE_WIDTH,
				false
			)
		_draw_debug_camera_marker(camera_marker, DEBUG_CAMERA_MARKER_RADIUS)
		_draw_debug_camera_marker(destination_marker, DEBUG_DESTINATION_MARKER_RADIUS)

	var camera_right: Vector2 = Vector2.RIGHT.rotated(global_rotation)
	var camera_down: Vector2 = Vector2.DOWN.rotated(global_rotation)
	for target_data: JuiceCamTargetData in get_all_targets():
		if target_data.radius <= 0.0:
			continue
		var center: Vector2 = target_data.get_world_position()
		var lookahead_center: Vector2 = target_data.get_tracking_world_position()
		var radius: float = target_data.radius
		_draw_debug_target_square(center, radius, camera_right, camera_down)

		var lookahead_delta: Vector2 = lookahead_center - center
		if lookahead_delta.length_squared() > 0.0001:
			draw_line(
				to_local(center),
				to_local(lookahead_center),
				DEBUG_DRAW_COLOR,
				DEBUG_STROKE_WIDTH,
				false
			)
			_draw_debug_target_square(
				lookahead_center,
				radius * DEBUG_LOOKAHEAD_SQUARE_SCALE,
				camera_right,
				camera_down
			)


func _draw_debug_camera_marker(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, DEBUG_DRAW_COLOR, false, DEBUG_STROKE_WIDTH, false)
	draw_line(
		Vector2(center.x - radius, center.y),
		Vector2(center.x + radius, center.y),
		DEBUG_DRAW_COLOR,
		DEBUG_STROKE_WIDTH,
		false
	)
	draw_line(
		Vector2(center.x, center.y - radius),
		Vector2(center.x, center.y + radius),
		DEBUG_DRAW_COLOR,
		DEBUG_STROKE_WIDTH,
		false
	)


func _draw_debug_target_square(
	center: Vector2,
	radius: float,
	camera_right: Vector2,
	camera_down: Vector2
) -> void:
	var world_corners: PackedVector2Array = PackedVector2Array([
		center - camera_right * radius - camera_down * radius,
		center + camera_right * radius - camera_down * radius,
		center + camera_right * radius + camera_down * radius,
		center - camera_right * radius + camera_down * radius,
	])
	_draw_world_polygon_outline(world_corners, DEBUG_DRAW_COLOR)


func _draw_limits_debug() -> void:
	if not limits_enabled:
		return
	var limits_rect: Rect2 = _get_limits_rect()
	if limits_rect.size.x <= 0.0 or limits_rect.size.y <= 0.0:
		return
	var corners: PackedVector2Array = PackedVector2Array([
		limits_rect.position,
		Vector2(limits_rect.end.x, limits_rect.position.y),
		limits_rect.end,
		Vector2(limits_rect.position.x, limits_rect.end.y),
	])
	_draw_world_polygon_outline(corners, JuiceCamDebugPalette2D.LIMITS)


func _draw_deadzone_debug() -> void:
	if not horizontal_deadzone_enabled and not vertical_deadzone_enabled:
		return

	var deadzone_rect: Rect2 = _build_deadzone_rect(get_current_zoom())
	if not horizontal_deadzone_enabled:
		deadzone_rect.position.x = 0.0
		deadzone_rect.size.x = 0.0
	if not vertical_deadzone_enabled:
		deadzone_rect.position.y = 0.0
		deadzone_rect.size.y = 0.0

	var anchor_position: Vector2 = _deadzone_anchor_position if _deadzone_active else global_position
	var camera_basis: Transform2D = Transform2D(global_rotation, anchor_position)
	var local_corners: PackedVector2Array = PackedVector2Array([
		deadzone_rect.position,
		Vector2(deadzone_rect.end.x, deadzone_rect.position.y),
		deadzone_rect.end,
		Vector2(deadzone_rect.position.x, deadzone_rect.end.y),
	])
	var world_corners: PackedVector2Array = PackedVector2Array()
	world_corners.resize(local_corners.size())
	for corner_index: int in range(local_corners.size()):
		world_corners[corner_index] = camera_basis * local_corners[corner_index]
	_draw_world_polygon_outline(world_corners, JuiceCamDebugPalette2D.DEADZONE)


func _draw_world_polygon_outline(world_points: PackedVector2Array, color: Color) -> void:
	if world_points.size() < 2:
		return
	for point_index: int in range(world_points.size()):
		draw_line(
			to_local(world_points[point_index]),
			to_local(world_points[(point_index + 1) % world_points.size()]),
			color,
			DEBUG_STROKE_WIDTH,
			false
		)


## Updates camera rotation if allow_rotation is enabled.
func _update_rotation(
	delta: float,
	target_rotation_override: float = 0.0,
	use_target_rotation_override: bool = false,
	cinematic_point: JuiceCamCinematic2D = null
) -> void:
	if not allow_rotation and not use_target_rotation_override:
		_current_rotation_velocity = 0.0
		return

	var target_rot: float = target_rotation_override
	if not use_target_rotation_override:
		target_rot = _calculate_target_rotation() + deg_to_rad(rotation_offset_degrees)
	
	var should_smooth: bool = smooth_rotation
	var effective_smooth_time: float = smooth_rotation_time
	if cinematic_point != null and cinematic_point.override_motion_settings:
		should_smooth = true
		effective_smooth_time = cinematic_point.rotation_smooth_time

	if not should_smooth or delta <= 0.0:
		global_rotation = target_rot
		_current_rotation_velocity = 0.0
	else:
		var res: Array[float] = JuiceMathScript.smooth_damp_angle(
			global_rotation,
			target_rot,
			_current_rotation_velocity,
			effective_smooth_time,
			INF,
			delta
		)
		global_rotation = res[0]
		_current_rotation_velocity = res[1]


## Updates camera zoom scale and resolves the highest-priority active zoom region.
func _update_zoom(delta: float, focus_position: Vector2, has_target: bool) -> Vector2:
	var target_zoom: Vector2 = _calculate_zoom_target(focus_position, has_target)
	return _update_zoom_to_target(delta, target_zoom)


func _update_zoom_to_target(
	delta: float,
	target_zoom: Vector2,
	cinematic_point: JuiceCamCinematic2D = null
) -> Vector2:
	var should_smooth: bool = smooth_zoom
	var effective_smooth_time: float = smooth_zoom_time
	if cinematic_point != null and cinematic_point.override_motion_settings:
		should_smooth = true
		effective_smooth_time = cinematic_point.zoom_smooth_time
	if not should_smooth or delta <= 0.0:
		_current_zoom = target_zoom
		_current_zoom_velocity = Vector2.ZERO
	else:
		var res: Array[Vector2] = JuiceMathScript.smooth_damp_2d(
			_current_zoom,
			target_zoom,
			_current_zoom_velocity,
			effective_smooth_time,
			INF,
			delta
		)
		_current_zoom = clamp_zoom(res[0])
		_current_zoom_velocity = res[1]
	return target_zoom


func _calculate_zoom_target(focus_position: Vector2, has_target: bool) -> Vector2:
	var target_zoom: Vector2 = clamp_zoom(zoom)
	if auto_framing and has_target:
		var autofit: Vector2 = _calculate_auto_framing_zoom()
		if autofit != Vector2.ZERO:
			target_zoom = clamp_zoom(autofit)
	target_zoom = _apply_zoom_influences(target_zoom, focus_position)
	if _active_room != null and _active_room.is_camera_inside(self):
		target_zoom = _active_room.constrain_zoom(
			target_zoom,
			global_rotation,
			get_effective_viewport_size()
		)
	return clamp_zoom(target_zoom)


func _apply_zoom_influences(base_zoom: Vector2, focus_position: Vector2) -> Vector2:
	var selected_zoom: Vector2 = base_zoom
	var has_selected_zoom: bool = false
	for candidate: Node2D in _influence_candidates:
		if not candidate is JuiceCamZoom2D:
			continue
		var zoom_region: JuiceCamZoom2D = candidate as JuiceCamZoom2D
		var is_inside: bool = zoom_region.update_camera_overlap(self, focus_position)
		_set_influence_active(zoom_region, is_inside)
		var requested_zoom: Vector2 = zoom_region.calculate_zoom(self, base_zoom, focus_position)
		if is_inside and not has_selected_zoom and requested_zoom.distance_to(base_zoom) > 0.0001:
			selected_zoom = requested_zoom
			has_selected_zoom = true
	return clamp_zoom(selected_zoom)


func _apply_magnet_influences(start_position: Vector2, apply_force: bool) -> Vector2:
	var target_position: Vector2 = start_position
	for candidate: Node2D in _influence_candidates:
		if not candidate is JuiceCamMagnet2D:
			continue
		var magnet: JuiceCamMagnet2D = candidate as JuiceCamMagnet2D
		var is_inside: bool = magnet.update_camera_overlap(self, target_position)
		_set_influence_active(magnet, is_inside)
		if apply_force and is_inside:
			target_position = magnet.apply_magnet(self, target_position)
	return target_position


func _select_active_room(world_position: Vector2) -> JuiceCamRoom2D:
	_query_influence_candidates(world_position)
	var selected_room: JuiceCamRoom2D = null
	for candidate: Node2D in _influence_candidates:
		if not candidate is JuiceCamRoom2D:
			continue
		var room: JuiceCamRoom2D = candidate as JuiceCamRoom2D
		var is_inside: bool = room.update_camera_overlap(self, world_position)
		_set_influence_active(room, is_inside)
		if is_inside and (selected_room == null or room.priority > selected_room.priority):
			selected_room = room
	return selected_room


func _apply_path_constraint(target_position: Vector2) -> Vector2:
	if _influence_registry == null:
		if is_instance_valid(_active_path):
			_active_path.reset_camera_path_state(self)
		_active_path = null
		_path_candidates.clear()
		return target_position
	# Query every path in this World2D, then select the highest-priority path whose
	# endpoint range contains the tracking point on that path's free axis.
	_influence_registry.query_paths(get_viewport().world_2d, _path_candidates)
	var selected_path: JuiceCamPath2D = null
	for candidate: Node2D in _path_candidates:
		if not candidate is JuiceCamPath2D:
			continue
		var path: JuiceCamPath2D = candidate as JuiceCamPath2D
		if not path.enabled or not path.has_valid_path():
			continue
		if not path.contains_tracking_position_in_free_axis_range(target_position):
			continue
		if selected_path == null or path.priority > selected_path.priority:
			selected_path = path
	if selected_path != _active_path:
		if is_instance_valid(_active_path):
			_active_path.reset_camera_path_state(self)
		if is_instance_valid(selected_path):
			selected_path.reset_camera_path_state(self)
		_active_path = selected_path
	if selected_path == null:
		return target_position
	return selected_path.constrain_camera_position(self, target_position)


func _update_room_final_clamp_state() -> void:
	if _active_room != _room_final_clamp_room:
		_room_final_clamp_room = _active_room
		_room_final_clamp_active = false
	if _active_room == null or _room_final_clamp_active:
		return
	if not is_instance_valid(_active_room) or not _active_room.is_camera_inside(self):
		return
	_room_final_clamp_active = _active_room.is_camera_pose_contained(
		global_position,
		_current_zoom,
		global_rotation,
		get_effective_viewport_size()
	)


func _query_influence_candidates(world_position: Vector2) -> void:
	_influence_candidates.clear()
	_influence_candidate_ids.clear()
	_stale_influence_ids.clear()
	if _influence_registry != null:
		var search_half_size: Vector2 = Vector2.ONE * INFLUENCE_SEARCH_RADIUS
		_influence_query_bounds = Rect2(world_position - search_half_size, search_half_size * 2.0)
		_influence_registry.query_aabb(
			get_viewport().world_2d,
			_influence_query_bounds,
			_influence_candidates
		)
	else:
		_influence_query_bounds = Rect2(world_position, Vector2.ZERO)
	for candidate: Node2D in _influence_candidates:
		_influence_candidate_ids[candidate.get_instance_id()] = true
	for influence_id: int in _active_influences:
		var influence: Node2D = _active_influences[influence_id]
		if (
			not is_instance_valid(influence)
			or not influence.is_inside_tree()
			or influence.is_queued_for_deletion()
		):
			_stale_influence_ids.append(influence_id)
		elif influence.get_viewport().world_2d != get_viewport().world_2d:
			influence.call("forget_camera", self)
			_stale_influence_ids.append(influence_id)
		elif not _influence_candidate_ids.has(influence_id):
			_influence_candidates.append(influence)
			_influence_candidate_ids[influence_id] = true
	for influence_id: int in _stale_influence_ids:
		_active_influences.erase(influence_id)
	_influence_candidates.sort_custom(_sort_influence_priority)


func _set_influence_active(influence: Node2D, is_active: bool) -> void:
	var influence_id: int = influence.get_instance_id()
	if is_active:
		_active_influences[influence_id] = influence
	else:
		_active_influences.erase(influence_id)


func _sort_influence_priority(a: Node2D, b: Node2D) -> bool:
	var priority_a: int = int(a.get(&"priority"))
	var priority_b: int = int(b.get(&"priority"))
	if priority_a == priority_b:
		return a.get_instance_id() < b.get_instance_id()
	return priority_a > priority_b


## Calculates the auto-framing zoom for all valid targets.
func _calculate_auto_framing_zoom() -> Vector2:
	var targets: Array[JuiceCamTargetData] = get_all_targets()
	if targets.is_empty():
		return zoom
	if targets.size() == 1:
		return zoom

	var viewport_size: Vector2 = _get_effective_viewport_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return zoom

	var positions: Array[Vector2] = []
	var radii: Array[float] = []
	var weights: Array[float] = []

	for target_data: JuiceCamTargetData in targets:
		if target_data != null and target_data.is_valid():
			positions.append(target_data.get_tracking_world_position())
			radii.append(target_data.radius)
			weights.append(target_data.weight)

	if positions.is_empty():
		return zoom

	var centroid: Vector2 = _calculate_tracking_centroid(targets)
	var camera_rotation: float = global_rotation

	return JuiceFraming.calculate_autofit_zoom_2d(
		positions,
		radii,
		weights,
		centroid,
		camera_rotation,
		viewport_size,
		framing_margin,
		min_framing_zoom,
		max_framing_zoom,
		weight_space_factor
	)


## Applies the camera-local deadzone to the single influential target's focus point.
func _apply_deadzone(target_position: Vector2) -> Vector2:
	if not horizontal_deadzone_enabled and not vertical_deadzone_enabled:
		_deadzone_anchor_position = global_position
		_deadzone_active = false
		return target_position

	if _target_set.get_influential_target_count() != 1:
		_deadzone_anchor_position = global_position
		_deadzone_active = false
		return target_position

	if not _deadzone_active:
		_deadzone_anchor_position = global_position
		_deadzone_active = true

	var deadzone_rect: Rect2 = _calculate_deadzone_rect()
	var target_offset: Vector2 = (target_position - _deadzone_anchor_position).rotated(-global_rotation)
	var camera_motion_local: Vector2 = Vector2.ZERO

	if horizontal_deadzone_enabled:
		if target_offset.x < deadzone_rect.position.x:
			camera_motion_local.x = target_offset.x - deadzone_rect.position.x
		elif target_offset.x > deadzone_rect.end.x:
			camera_motion_local.x = target_offset.x - deadzone_rect.end.x
	else:
		camera_motion_local.x = target_offset.x

	if vertical_deadzone_enabled:
		if target_offset.y < deadzone_rect.position.y:
			camera_motion_local.y = target_offset.y - deadzone_rect.position.y
		elif target_offset.y > deadzone_rect.end.y:
			camera_motion_local.y = target_offset.y - deadzone_rect.end.y
	else:
		camera_motion_local.y = target_offset.y

	_deadzone_anchor_position += camera_motion_local.rotated(global_rotation)
	return _deadzone_anchor_position


## Builds the deadzone rectangle in camera-local world units from viewport size and zoom.
func _calculate_deadzone_rect() -> Rect2:
	return _build_deadzone_rect(_current_zoom)


func _build_deadzone_rect(zoom_value: Vector2) -> Rect2:
	var viewport_size: Vector2 = _get_effective_viewport_size()
	var zoom_abs: Vector2 = Vector2(
		maxf(absf(zoom_value.x), MIN_ZOOM),
		maxf(absf(zoom_value.y), MIN_ZOOM)
	)
	var half_size: Vector2 = (viewport_size / zoom_abs) * 0.5
	var left_edge: float = half_size.x * clampf(deadzone_left_margin, 0.0, 1.0)
	var right_edge: float = half_size.x * clampf(deadzone_right_margin, 0.0, 1.0)
	var top_edge: float = half_size.y * clampf(deadzone_top_margin, 0.0, 1.0)
	var bottom_edge: float = half_size.y * clampf(deadzone_bottom_margin, 0.0, 1.0)
	return Rect2(
		Vector2(-left_edge, -top_edge),
		Vector2(left_edge + right_edge, top_edge + bottom_edge)
	)


func _get_limits_rect() -> Rect2:
	var min_x: float = minf(limit_left, limit_right)
	var max_x: float = maxf(limit_left, limit_right)
	var min_y: float = minf(limit_top, limit_bottom)
	var max_y: float = maxf(limit_top, limit_bottom)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _is_valid_limits_rect(limits_rect: Rect2) -> bool:
	if limits_rect.size.x <= 0.0 or limits_rect.size.y <= 0.0:
		if not _invalid_limits_warning_issued:
			push_warning("JuiceCam2D '%s' limits need positive width and height." % name)
			_invalid_limits_warning_issued = true
		return false
	_invalid_limits_warning_issued = false
	return true


func _camera_view_half_extents(zoom_value: Vector2, camera_rotation: float) -> Vector2:
	var safe_zoom: Vector2 = Vector2(
		maxf(absf(zoom_value.x), MIN_ZOOM),
		maxf(absf(zoom_value.y), MIN_ZOOM)
	)
	var local_half_size: Vector2 = (_get_effective_viewport_size() / safe_zoom) * 0.5
	var abs_cos: float = absf(cos(camera_rotation))
	var abs_sin: float = absf(sin(camera_rotation))
	return Vector2(
		abs_cos * local_half_size.x + abs_sin * local_half_size.y,
		abs_sin * local_half_size.x + abs_cos * local_half_size.y
	)


func _fit_zoom_to_limits(zoom_value: Vector2, camera_rotation: float, limits_rect: Rect2) -> Vector2:
	var view_half_extents: Vector2 = _camera_view_half_extents(zoom_value, camera_rotation)
	var bounds_half_size: Vector2 = limits_rect.size * 0.5
	var fit_factor: float = maxf(
		1.0,
		maxf(
			view_half_extents.x / maxf(bounds_half_size.x, 0.000001),
			view_half_extents.y / maxf(bounds_half_size.y, 0.000001)
		)
	)
	return clamp_zoom(zoom_value * fit_factor)


func _clamp_position_to_limits(
	position: Vector2,
	zoom_value: Vector2,
	camera_rotation: float,
	limits_rect: Rect2
) -> Vector2:
	var view_half_extents: Vector2 = _camera_view_half_extents(zoom_value, camera_rotation)
	var minimum_position: Vector2 = limits_rect.position + view_half_extents
	var maximum_position: Vector2 = limits_rect.end - view_half_extents
	var bounds_center: Vector2 = limits_rect.get_center()
	if minimum_position.x > maximum_position.x:
		minimum_position.x = bounds_center.x
		maximum_position.x = bounds_center.x
	if minimum_position.y > maximum_position.y:
		minimum_position.y = bounds_center.y
		maximum_position.y = bounds_center.y
	return Vector2(
		clampf(position.x, minimum_position.x, maximum_position.x),
		clampf(position.y, minimum_position.y, maximum_position.y)
	)


func _apply_hard_limits_to_base_pose() -> void:
	var limits_rect: Rect2 = _get_limits_rect()
	if not _is_valid_limits_rect(limits_rect):
		return
	var fitted_zoom: Vector2 = _fit_zoom_to_limits(_current_zoom, global_rotation, limits_rect)
	if fitted_zoom != _current_zoom:
		_current_zoom = fitted_zoom
		_current_zoom_velocity = Vector2.ZERO
	var unclamped_position: Vector2 = global_position
	global_position = _clamp_position_to_limits(
		global_position,
		_current_zoom,
		global_rotation,
		limits_rect
	)
	if _deadzone_active:
		_deadzone_anchor_position = _clamp_position_to_limits(
			_deadzone_anchor_position,
			_current_zoom,
			global_rotation,
			limits_rect
		)
	if not is_equal_approx(unclamped_position.x, global_position.x):
		_current_velocity.x = 0.0
	if not is_equal_approx(unclamped_position.y, global_position.y):
		_current_velocity.y = 0.0


## Returns the output dimensions used for camera framing and constraints.
func _get_effective_viewport_size() -> Vector2:
	# Godot draws an edited Camera2D's editor outline using the project's base
	# viewport dimensions. Match that size for editor preview calculations.
	if Engine.is_editor_hint():
		var editor_output_size: Vector2 = Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 648))
		)
		if editor_output_size.x > 0.0 and editor_output_size.y > 0.0:
			return editor_output_size

	var active_viewport: Viewport = get_viewport()
	if active_viewport != null and is_instance_valid(active_viewport):
		var active_rect: Rect2 = active_viewport.get_visible_rect()
		if active_rect.size.x > 0.0 and active_rect.size.y > 0.0:
			return active_rect.size
		if active_viewport is SubViewport:
			var active_size: Vector2 = Vector2((active_viewport as SubViewport).size)
			if active_size.x > 0.0 and active_size.y > 0.0:
				return active_size

	return Vector2(1152.0, 648.0)


## Returns the dimensions of the viewport used by this camera, in pixels.
func get_effective_viewport_size() -> Vector2:
	return _get_effective_viewport_size()


## Calculates target rotation from the primary target node.
func _calculate_target_rotation() -> float:
	var prim: Node2D = _target_set.get_primary_influential_target()
	if prim != null and is_instance_valid(prim):
		return prim.global_rotation
	return 0.0


## Returns the currently rendered zoom scale of the camera.
func get_current_zoom() -> Vector2:
	if _camera != null and is_instance_valid(_camera):
		return _camera.get_zoom()
	return clamp_zoom(_current_zoom * _addon_frame.output_zoom_multiplier)


## Calculates the weighted centroid of all assigned targets in world coordinates.
func calculate_target_centroid() -> Vector2:
	return _target_set.calculate_weighted_centroid(global_position)


func _calculate_tracking_centroid(targets: Array[JuiceCamTargetData]) -> Vector2:
	var weighted_sum: Vector2 = Vector2.ZERO
	var total_weight: float = 0.0
	for target: JuiceCamTargetData in targets:
		if target == null or not target.is_valid():
			continue
		var target_weight: float = maxf(0.0, target.weight)
		if target_weight <= 0.0001:
			continue
		weighted_sum += target.get_tracking_world_position() * target_weight
		total_weight += target_weight
	if total_weight > 0.0001:
		return weighted_sum / total_weight
	return global_position


## Immediately snaps the camera to the target centroid and zeroes velocity.
func teleport_to_target() -> void:
	if _target_set.has_influential_targets():
		global_position = calculate_target_centroid()
		if allow_rotation:
			global_rotation = _calculate_target_rotation() + deg_to_rad(rotation_offset_degrees)
	_current_zoom = _calculate_zoom_target(global_position, _target_set.has_influential_targets())
	if limits_enabled:
		_apply_hard_limits_to_base_pose()
	_deadzone_anchor_position = global_position
	_deadzone_active = false
	_reset_motion_velocity()
	_addon_frame.reset_output()
	_room_independent_output_position_offset = Vector2.ZERO
	_sync_internal_camera()


func _reset_motion_velocity() -> void:
	_current_velocity = Vector2.ZERO
	_current_rotation_velocity = 0.0
	_current_zoom_velocity = Vector2.ZERO


## Starts the enabled cinematic points with this name in this camera's viewport.
## Returns false and emits cinematic_not_found when the sequence has no points.
func start_cinematic(sequence_name: String) -> bool:
	return _cinematic_player.start(self, StringName(sequence_name))


## Stops this camera's active cinematic, if one is playing.
func stop_cinematic() -> void:
	_cinematic_player.stop()


## Whether this camera currently has an active cinematic sequence.
func is_cinematic_playing() -> bool:
	return _cinematic_player.is_playing


## Name of this camera's active cinematic sequence, or an empty name when idle.
func get_active_cinematic_name() -> StringName:
	return _cinematic_player.get_active_sequence_name()


## Current cinematic point, or null when this camera is not playing one.
func get_current_cinematic_point() -> JuiceCamCinematic2D:
	return _cinematic_player.get_current_point()


func _on_cinematic_started(sequence_name: StringName) -> void:
	_reset_motion_velocity()
	_deadzone_anchor_position = global_position
	_deadzone_active = false
	cinematic_started.emit(sequence_name)


func _on_cinematic_stopped(sequence_name: StringName) -> void:
	if not _cinematic_player.is_playing:
		_reset_motion_velocity()
		_deadzone_anchor_position = global_position
		_deadzone_active = false
	cinematic_stopped.emit(sequence_name)


func _on_cinematic_completed(sequence_name: StringName) -> void:
	cinematic_completed.emit(sequence_name)


func _on_cinematic_not_found(sequence_name: StringName) -> void:
	cinematic_not_found.emit(sequence_name)


func _on_cinematic_point_started(sequence_name: StringName, point: JuiceCamCinematic2D) -> void:
	cinematic_point_started.emit(sequence_name, point)


func _on_cinematic_point_arrived(sequence_name: StringName, point: JuiceCamCinematic2D) -> void:
	cinematic_point_arrived.emit(sequence_name, point)


func _on_cinematic_point_completed(sequence_name: StringName, point: JuiceCamCinematic2D) -> void:
	cinematic_point_completed.emit(sequence_name, point)


## Synchronizes position, rotation, and zoom with the internal Camera2D.
func _sync_internal_camera() -> void:
	var cam: Camera2D = get_internal_camera()
	if cam != null and is_instance_valid(cam):
		var output_offset_world: Vector2 = _addon_frame.output_position_offset.rotated(global_rotation)
		var room_independent_offset_world: Vector2 = _room_independent_output_position_offset.rotated(global_rotation)
		var camera_position: Vector2 = global_position + output_offset_world
		var camera_rotation: float = global_rotation + _addon_frame.output_rotation_offset
		var camera_zoom: Vector2 = clamp_zoom(_current_zoom * _addon_frame.output_zoom_multiplier)
		if (
			_room_final_clamp_allowed_this_frame
			and _room_final_clamp_active
			and is_instance_valid(_active_room)
			and _active_room == _room_final_clamp_room
			and _active_room.is_camera_inside(self)
		):
			var viewport_size: Vector2 = get_effective_viewport_size()
			camera_zoom = _active_room.constrain_zoom(camera_zoom, camera_rotation, viewport_size)
			var room_constrained_position: Vector2 = _active_room.constrain_camera_position(
				camera_position - room_independent_offset_world,
				camera_zoom,
				camera_rotation,
				viewport_size
			)
			camera_position = room_constrained_position + room_independent_offset_world
		if limits_enabled:
			var limits_rect: Rect2 = _get_limits_rect()
			if _is_valid_limits_rect(limits_rect):
				camera_zoom = _fit_zoom_to_limits(camera_zoom, camera_rotation, limits_rect)
				camera_position = _clamp_position_to_limits(
					camera_position,
					camera_zoom,
					camera_rotation,
					limits_rect
				)
		_addon_frame.output_zoom_multiplier = Vector2(
			camera_zoom.x / _current_zoom.x,
			camera_zoom.y / _current_zoom.y
		)
		cam.global_position = camera_position
		cam.global_rotation = camera_rotation
		cam.set_zoom(camera_zoom)


## Returns this camera's runtime add-on with the given ID, or null when it is not found.
## Cast the result to the add-on's concrete script type to call its custom methods.
func get_addon(addon_id: String) -> JuiceCamAddon2D:
	_ensure_runtime_addons()
	return _addons_by_id.get(addon_id) as JuiceCamAddon2D


## Returns this camera's runtime add-ons. These are independent copies of the exported resources.
func get_addons() -> Array[JuiceCamAddon2D]:
	_ensure_runtime_addons()
	var result: Array[JuiceCamAddon2D] = []
	result.append_array(_runtime_addons)
	return result


## Adds a configuration resource and returns the camera-owned runtime instance.
## Empty IDs receive a camera-local addon_N ID. Duplicate IDs are rejected.
func add_addon(addon: JuiceCamAddon2D) -> JuiceCamAddon2D:
	if addon == null:
		return null
	var config: JuiceCamAddon2D = addon.duplicate(true) as JuiceCamAddon2D
	if config == null:
		return null
	var config_id: String = config.addon_id
	if config_id.is_empty():
		config_id = _generate_addon_id()
		config.addon_id = config_id
	if _has_addon_id(config_id):
		push_warning("JuiceCam2D '%s' already has an add-on with ID '%s'." % [name, config_id])
		return null
	var updated_addons: Array[JuiceCamAddon2D] = []
	updated_addons.append_array(addons)
	updated_addons.append(config)
	addons = updated_addons
	return get_addon(config_id)


## Removes the first configured add-on with this ID.
func remove_addon(addon_id: String) -> bool:
	for index: int in range(addons.size()):
		var config: JuiceCamAddon2D = addons[index]
		if config != null and config.addon_id == addon_id:
			var updated_addons: Array[JuiceCamAddon2D] = []
			updated_addons.append_array(addons)
			updated_addons.remove_at(index)
			addons = updated_addons
			return true
	return false


func _ensure_runtime_addons() -> void:
	if not _addons_initialized:
		_connect_addon_configs()
		_rebuild_runtime_addons()


func _rebuild_runtime_addons() -> void:
	_clear_runtime_addons()
	_runtime_addons.clear()
	_target_modifiers.clear()
	_output_modifiers.clear()
	_addons_by_id.clear()
	_addons_initialized = true
	for config: JuiceCamAddon2D in addons:
		if config == null:
			continue
		var runtime_addon: JuiceCamAddon2D = config.duplicate(true) as JuiceCamAddon2D
		if runtime_addon == null:
			push_warning("JuiceCam2D '%s' could not duplicate add-on '%s'." % [name, config.resource_name])
			continue
		_runtime_addons.append(runtime_addon)
		if not runtime_addon.addon_id.is_empty():
			if _addons_by_id.has(runtime_addon.addon_id):
				push_warning(
					"JuiceCam2D '%s' has duplicate add-on ID '%s'; get_addon() returns the first one."
					% [name, runtime_addon.addon_id]
				)
			else:
				_addons_by_id[runtime_addon.addon_id] = runtime_addon
		if runtime_addon is JuiceCamTargetModifier2D:
			_target_modifiers.append(runtime_addon as JuiceCamTargetModifier2D)
		elif runtime_addon is JuiceCamOutputModifier2D:
			_output_modifiers.append(runtime_addon as JuiceCamOutputModifier2D)
		if is_inside_tree():
			runtime_addon.setup(self)
			_setup_addons.append(runtime_addon)


func _clear_runtime_addons() -> void:
	for runtime_addon: JuiceCamAddon2D in _setup_addons:
		if is_instance_valid(runtime_addon):
			runtime_addon.exit(self)
	_setup_addons.clear()
	_runtime_addons.clear()
	_target_modifiers.clear()
	_output_modifiers.clear()
	_addons_by_id.clear()


func _connect_addon_configs() -> void:
	for config: JuiceCamAddon2D in addons:
		if config != null and not config.changed.is_connected(_on_addon_config_changed):
			config.changed.connect(_on_addon_config_changed)


func _disconnect_addon_configs() -> void:
	for config: JuiceCamAddon2D in addons:
		if config != null and config.changed.is_connected(_on_addon_config_changed):
			config.changed.disconnect(_on_addon_config_changed)


func _on_addon_config_changed() -> void:
	_addons_initialized = false
	if is_inside_tree():
		_rebuild_runtime_addons()


func _has_addon_id(addon_id: String) -> bool:
	if addon_id.is_empty():
		return false
	for config: JuiceCamAddon2D in addons:
		if config != null and config.addon_id == addon_id:
			return true
	return false


func _generate_addon_id() -> String:
	var index: int = 1
	var candidate: String = "addon_%d" % index
	while _has_addon_id(candidate):
		index += 1
		candidate = "addon_%d" % index
	return candidate


func _update_process_mode() -> void:
	var editor_preview_process: bool = Engine.is_editor_hint()
	set_process(editor_preview_process or process_callback == ProcessCallback.IDLE)
	set_physics_process(not editor_preview_process and process_callback == ProcessCallback.PHYSICS)


# --- Dynamic Target Serialization Properties ---

func _validate_property(property: Dictionary) -> void:
	if (
		property.name in [&"spring_frequency", &"spring_damping"]
		and damping_type != DampingType.SPRING_DAMP
	):
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_property_list() -> Array[Dictionary]:
	return _target_set.get_dynamic_property_list()


func _get(property: StringName) -> Variant:
	return _target_set.get_dynamic_property(property)


func _set(property: StringName, value: Variant) -> bool:
	if property == &"zoom":
		if value is Vector2:
			zoom = clamp_zoom(value as Vector2)
		else:
			zoom = Vector2.ONE
		return true
	if property == &"allow_rotation":
		allow_rotation = (value as bool) if value != null else false
		return true
	if property == &"smooth_rotation":
		smooth_rotation = (value as bool) if value != null else true
		return true
	if property == &"smooth_rotation_time":
		smooth_rotation_time = maxf(0.001, (value as float) if value != null else 0.2)
		return true
	if property == &"rotation_offset_degrees":
		rotation_offset_degrees = (value as float) if value != null else 0.0
		return true
	if property == &"smooth_zoom":
		smooth_zoom = (value as bool) if value != null else true
		return true
	if property == &"smooth_zoom_time":
		smooth_zoom_time = maxf(0.001, (value as float) if value != null else 0.2)
		return true
	if property == &"auto_framing":
		auto_framing = (value as bool) if value != null else true
		return true
	if property == &"framing_margin":
		framing_margin = clampf((value as float) if value != null else 0.8, 0.1, 1.0)
		return true
	if property == &"min_framing_zoom":
		min_framing_zoom = maxf(MIN_ZOOM, (value as float) if value != null else 0.2)
		return true
	if property == &"max_framing_zoom":
		max_framing_zoom = maxf(min_framing_zoom, (value as float) if value != null else 1.0)
		return true
	if property == &"weight_space_factor":
		weight_space_factor = maxf(0.0, (value as float) if value != null else 1.0)
		return true
	var write_result: JuiceCamTargetSet2D.PropertyWriteResult = _target_set.set_dynamic_property(property, value)
	if write_result == JuiceCamTargetSet2D.PropertyWriteResult.UNHANDLED:
		return false
	if write_result == JuiceCamTargetSet2D.PropertyWriteResult.SCHEMA_CHANGED:
		notify_property_list_changed()
	return true


# --- Target Management API ---

## Target entries in order. The returned array is a copy, but its target data objects are live.
## Use add_target() and remove_target() to change which targets belong to this camera.
var targets: Array[JuiceCamTargetData]:
	get:
		return get_all_targets()


## Primary target for single-player / single-target games.
var target: Node2D:
	get:
		return get_primary_target()
	set(value):
		set_primary_target(value)


## Sets the primary (first) target node.
func set_primary_target(node: Node2D) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	_target_set.set_primary_target(node)
	notify_property_list_changed()


## Reassigns an existing target's node while preserving its tuning.
## Null, queued-for-deletion, and duplicate node assignments are rejected.
func set_target_node(index: int, node: Node2D) -> bool:
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return false
	if not _target_set.set_node_at(index, node):
		return false
	notify_property_list_changed()
	return true


## Returns the first target node, or null when the camera has no targets.
func get_primary_target() -> Node2D:
	return _target_set.get_primary_target()


## Appends a new target with custom tuning parameters.
func add_target(
	node: Node2D,
	weight: float = 1.0,
	radius: float = 32.0,
	offset: Vector2 = Vector2.ZERO,
	use_lookahead: bool = true,
	lookahead_factor: float = 0.0
) -> JuiceCamTargetData:
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return null
	var was_registered: bool = _target_set.has_target(node)
	var previous_count: int = _target_set.get_size()
	var target_data: JuiceCamTargetData = _target_set.add_target(
		node,
		weight,
		radius,
		offset,
		use_lookahead,
		lookahead_factor
	)
	if not was_registered or previous_count != _target_set.get_size():
		notify_property_list_changed()
	return target_data


## Removes a target node from tracking.
func remove_target(node: Node2D) -> void:
	var was_registered: bool = _target_set.has_target(node)
	_target_set.remove_target(node)
	if was_registered:
		notify_property_list_changed()


## Deletes a target entry by index.
func remove_target_at(index: int) -> bool:
	if not _target_set.remove_at(index):
		return false
	notify_property_list_changed()
	return true


## Restores a deleted target entry for editor undo/redo.
func restore_target_at(index: int, target_data: JuiceCamTargetData) -> bool:
	if not _target_set.restore_at(index, target_data):
		return false
	notify_property_list_changed()
	return true


## Checks if a target node is registered.
func has_target(node: Node2D) -> bool:
	return _target_set.has_target(node)


## Deletes every target entry.
func clear_targets() -> void:
	_target_set.clear()
	notify_property_list_changed()


## Returns all target data entries with live, assigned nodes.
func get_all_targets() -> Array[JuiceCamTargetData]:
	var serialization_schema_changed: bool = _target_set._finalize_serialized_entries()
	var previous_count: int = _target_set.get_size()
	var targets: Array[JuiceCamTargetData] = _target_set.get_all_targets()
	if serialization_schema_changed or targets.size() != previous_count:
		notify_property_list_changed()
	return targets


# --- Editor Callbacks ---

func _editor_remove_target_at(idx: int) -> void:
	remove_target_at(idx)


# --- Internal Camera Lifecycle ---

## Ensures the internal Camera2D exists as an un-owned internal child node.
func _ensure_internal_camera() -> void:
	if _camera != null and is_instance_valid(_camera):
		return
	
	_camera = Camera2D.new()
	_camera.name = "__JuiceInternalCamera2D"
	_camera.position_smoothing_enabled = false
	_camera.rotation_smoothing_enabled = false
	_camera.ignore_rotation = false
	add_child(_camera, false, Node.INTERNAL_MODE_FRONT)


## Cleans up the internal camera instance.
func _cleanup_internal_camera() -> void:
	if _camera != null and is_instance_valid(_camera):
		_camera.queue_free()
		_camera = null


## Creates a per-camera, screen-space cinematic overlay at runtime.
func _ensure_cinematic_bars() -> void:
	if Engine.is_editor_hint():
		return
	if _cinematic_bars != null and is_instance_valid(_cinematic_bars):
		return
	_cinematic_bars = JuiceCamCinematicBars2DScript.new() as CanvasLayer
	_cinematic_bars.name = "__JuiceCinematicBars"
	add_child(_cinematic_bars, false, Node.INTERNAL_MODE_FRONT)
	_cinematic_bars.call(
		"configure",
		self,
		cinematic_bars_enabled,
		cinematic_bar_height,
		cinematic_bar_transition_time
	)


func _update_cinematic_bars() -> void:
	if _cinematic_bars != null and is_instance_valid(_cinematic_bars):
		_cinematic_bars.call(
			"update_settings",
			cinematic_bars_enabled,
			cinematic_bar_height,
			cinematic_bar_transition_time
		)


func _cleanup_cinematic_bars() -> void:
	if _cinematic_bars != null and is_instance_valid(_cinematic_bars):
		_cinematic_bars.queue_free()
		_cinematic_bars = null


## Returns the internally managed Camera2D instance.
func get_internal_camera() -> Camera2D:
	if _camera == null or not is_instance_valid(_camera):
		_ensure_internal_camera()
	return _camera


## Makes this camera active/current in its Viewport.
func make_current() -> void:
	var cam: Camera2D = get_internal_camera()
	if cam != null and is_instance_valid(cam):
		cam.make_current()


## Returns true if this camera is currently active in the viewport.
func is_current() -> bool:
	return _camera != null and is_instance_valid(_camera) and _camera.is_current()
