extends CanvasLayer

## Runtime controls and short lessons for the JuiceCam Camera Lab demo.

const PANEL_COLOR: Color = Color("#102237")
const PANEL_EDGE: Color = Color("#36516a")
const TEXT_COLOR: Color = Color("#e7f1f6")
const MUTED_COLOR: Color = Color("#a9bac7")
const ACCENT_COLOR: Color = Color("#bd5cbd")
const FLOOR_Y: float = 768.0
const DAMPING_LABELS: Array[String] = ["Smooth Damp", "Spring Damp", "Exponential Decay"]

const ZONES: Array[Dictionary] = [
	{
		"id": "tracking",
		"title": "TRACKING",
		"button": "Tracking",
		"x": 400.0,
		"lesson": "Move through the platforms. JuiceCam follows the target while lookahead predicts motion and the camera-local dead zone lets the player move before the view catches up.",
		"hint": "Add the companion to see group framing. Tune lookahead, target radius and offset, damping, zoom and rotation here.",
	},
	{
		"id": "room",
		"title": "ROOMS & LIMITS",
		"button": "Rooms",
		"x": 2480.0,
		"lesson": "Enter the framed room. Its closed edges keep the view inside the space, even while the player moves around.",
		"hint": "World limits are the outer guard rails. Room snap is optional and only acts when the camera enters the room.",
	},
	{
		"id": "influences",
		"title": "MAGNETS & ZOOM",
		"button": "Influences",
		"x": 4380.0,
		"lesson": "Cross the marked zones. The magnet shifts the camera's tracking focus; the zoom field changes how much of the level is visible.",
		"hint": "The camera still follows the player. These regions shape its destination while the player is inside them.",
	},
	{
		"id": "path",
		"title": "PATHS",
		"button": "Paths",
		"x": 6300.0,
		"lesson": "Follow the raised route. The active path constrains the camera to its curve on one axis while leaving the other axis free.",
		"hint": "Toggle the path or change its axis to compare horizontal and vertical-scroller behavior.",
	},
	{
		"id": "addons",
		"title": "ADD-ONS",
		"button": "Add-ons",
		"x": 8040.0,
		"lesson": "Try camera effects independently. These add-ons modify the rendered camera output and remain private to this camera.",
		"hint": "Use the preset menu, then trigger a shake. Mouse look and grid snap are easy to compare from this open runway.",
	},
	{
		"id": "cinematics",
		"title": "CINEMATICS",
		"button": "Cinematics",
		"x": 9680.0,
		"lesson": "A named sequence moves the camera through authored points, each with its own hold and zoom. Letterbox bars slide in for the shot and out when playback ends.",
		"hint": "Start the tour, trigger a shake during a shot, then stop playback to return to the player.",
	},
]

const SHAKE_PRESETS: Array[Dictionary] = [
	{"name": "Gunshot", "id": 1},
	{"name": "Earthquake", "id": 2},
	{"name": "Handheld", "id": 3},
	{"name": "Explosion", "id": 4},
	{"name": "Impact", "id": 5},
	{"name": "Rumble", "id": 6},
	{"name": "Vibration", "id": 7},
	{"name": "Wobbly", "id": 8},
]

var _game: Node2D
var _camera: JuiceCam2D
var _player: CharacterBody2D
var _companion: Node2D
var _room: JuiceCamRoom2D
var _magnet: JuiceCamMagnet2D
var _zoom_zone: JuiceCamZoom2D
var _path: JuiceCamPath2D
var _shake: JuiceCamScreenShake2D
var _mouse_follow: JuiceCamMouseFollow2D
var _grid_snap: JuiceCamGridSnap2D
var _velocity_zoom: JuiceCamVelocityZoom2D

var _root: Control
var _zone_title: Label
var _lesson_label: Label
var _hint_label: Label
var _controls_box: VBoxContainer
var _event_label: Label
var _nav_buttons: Array[Button] = []
var _active_zone: int = -1
var _cinematic_status: Label


func _ready() -> void:
	_game = get_parent() as Node2D
	_camera = _game.get_node("JuiceCam2D") as JuiceCam2D
	_player = _game.get_node("Player") as CharacterBody2D
	_companion = _game.get_node("Companion") as Node2D
	_room = _game.get_node("Influences/Room") as JuiceCamRoom2D
	_magnet = _game.get_node("Influences/Magnet") as JuiceCamMagnet2D
	_zoom_zone = _game.get_node("Influences/Zoom") as JuiceCamZoom2D
	_path = _game.get_node("Influences/Path") as JuiceCamPath2D
	_shake = _camera.get_addon("screen_shake") as JuiceCamScreenShake2D
	_mouse_follow = _camera.get_addon("mouse_follow") as JuiceCamMouseFollow2D
	_grid_snap = _camera.get_addon("grid_snap") as JuiceCamGridSnap2D
	_velocity_zoom = _camera.get_addon("velocity_zoom") as JuiceCamVelocityZoom2D
	_build_ui()
	_connect_cinematic_signals()
	_select_zone(0)
func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 28)
	margins.add_theme_constant_override("margin_top", 24)
	margins.add_theme_constant_override("margin_right", 28)
	margins.add_theme_constant_override("margin_bottom", 24)
	_root.add_child(margins)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	margins.add_child(layout)
	layout.add_child(_build_top_bar())

	var lower_row := HBoxContainer.new()
	lower_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower_row.add_theme_constant_override("separation", 0)
	layout.add_child(lower_row)
	var card := _build_info_card()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower_row.add_child(card)
	var stretch := Control.new()
	stretch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stretch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower_row.add_child(stretch)
	var footer := _build_footer()
	layout.add_child(footer)


func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#102237"), ACCENT_COLOR, 16, 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)

	var branding := VBoxContainer.new()
	branding.custom_minimum_size = Vector2(250.0, 0.0)
	branding.add_theme_constant_override("separation", 0)
	row.add_child(branding)
	var brand := _label("JUICECAM", 24, TEXT_COLOR, true)
	branding.add_child(brand)
	branding.add_child(_label("CAMERA LAB  /  2D", 12, MUTED_COLOR, true))

	var separator := VSeparator.new()
	row.add_child(separator)
	var nav := HBoxContainer.new()
	nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_theme_constant_override("separation", 8)
	row.add_child(nav)
	for index: int in range(ZONES.size()):
		var zone: Dictionary = ZONES[index]
		var button := _make_button(String(zone.button), false)
		button.custom_minimum_size = Vector2(120.0, 44.0)
		button.pressed.connect(_jump_to_zone.bind(index))
		nav.add_child(button)
		_nav_buttons.append(button)

	var tour_button := _make_button("Play tour", true)
	tour_button.custom_minimum_size = Vector2(138.0, 44.0)
	tour_button.pressed.connect(_start_cinematic)
	row.add_child(tour_button)
	return panel


func _build_info_card() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(390.0, 0.0)
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_COLOR, PANEL_EDGE, 16, 1))
	var column := VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 13)
	panel.add_child(column)
	column.add_child(_label("FIELD NOTES", 12, ACCENT_COLOR, true))
	_zone_title = _label("", 24, TEXT_COLOR, true)
	column.add_child(_zone_title)
	_lesson_label = _label("", 15, TEXT_COLOR)
	_lesson_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lesson_label.custom_minimum_size = Vector2(340.0, 82.0)
	column.add_child(_lesson_label)
	_hint_label = _label("", 13, MUTED_COLOR)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(340.0, 56.0)
	column.add_child(_hint_label)
	var line := HSeparator.new()
	column.add_child(line)
	column.add_child(_label("TRY IT", 12, ACCENT_COLOR, true))
	var controls_scroll := ScrollContainer.new()
	controls_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(controls_scroll)
	_controls_box = VBoxContainer.new()
	_controls_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls_box.add_theme_constant_override("separation", 8)
	controls_scroll.add_child(_controls_box)
	var event_rule := HSeparator.new()
	column.add_child(event_rule)
	_event_label = _label("Waiting for a room, magnet or zoom field.", 12, MUTED_COLOR)
	_event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_label.custom_minimum_size = Vector2(340.0, 28.0)
	column.add_child(_event_label)
	return panel


func _build_footer() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#102237"), PANEL_EDGE, 12, 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	row.add_child(_label("MOVE  A / D  or  ← / →", 13, TEXT_COLOR, true))
	row.add_child(_label("JUMP  W / ↑ / SPACE", 13, TEXT_COLOR, true))
	row.add_child(_label("SHAKE  F", 13, TEXT_COLOR, true))
	row.add_child(_label("Use the district buttons to jump straight to a feature.", 13, MUTED_COLOR))
	return panel


func _select_zone(index: int) -> void:
	_active_zone = clampi(index, 0, ZONES.size() - 1)
	var zone: Dictionary = ZONES[_active_zone]
	_zone_title.text = String(zone.title)
	_lesson_label.text = String(zone.lesson)
	_hint_label.text = String(zone.hint)
	for button_index: int in range(_nav_buttons.size()):
		_nav_buttons[button_index].add_theme_stylebox_override(
			"normal",
			_button_style(button_index == _active_zone)
		)
		_nav_buttons[button_index].add_theme_stylebox_override(
			"hover",
			_button_style(true)
		)
	_clear_controls()
	match String(zone.id):
		"tracking":
			_add_toggle("Pair target", _camera.get_all_targets().size() > 1, _set_pair_target)
			_add_toggle("Auto framing", _camera.auto_framing, _set_auto_framing)
			_add_toggle("Target lookahead", _get_primary_target_data().use_lookahead, _set_target_lookahead)
			_add_slider("Lookahead strength", 0.0, 2.0, _get_primary_target_data().lookahead_factor, _set_lookahead_factor, "×")
			_add_slider("Target frame radius", 0.0, 192.0, _get_primary_target_data().radius, _set_target_radius, " px")
			_add_slider("Target vertical offset", -120.0, 120.0, _get_primary_target_data().offset.y, _set_target_vertical_offset, " px")
			_add_toggle("Camera debug", _camera.debug_draw_enabled, _set_camera_debug)
			_add_slider("Base zoom", 0.5, 1.5, _camera.zoom.x, _set_base_zoom, "×")
			_add_toggle("Smooth motion", _camera.smooth_motion, _set_smooth_motion)
			_add_toggle("Smooth zoom", _camera.smooth_zoom, _set_smooth_zoom)
			_add_choice("Damping", DAMPING_LABELS, int(_camera.damping_type), _set_damping_type)
			_add_toggle("Horizontal dead zone", _camera.horizontal_deadzone_enabled, _set_horizontal_deadzone)
			_add_toggle("Vertical dead zone", _camera.vertical_deadzone_enabled, _set_vertical_deadzone)
			_add_toggle("Follow target rotation", _camera.allow_rotation, _set_rotation_enabled)
			_add_slider("Rotation offset", -30.0, 30.0, _camera.rotation_offset_degrees, _set_rotation_offset, "°")
			if _camera.get_all_targets().size() > 1:
				_add_slider("Companion weight", 0.0, 2.0, _camera.get_all_targets()[1].weight, _set_companion_weight, "×")
		"room":
			_add_toggle("World limits", _camera.limits_enabled, _set_limits_enabled)
			_add_toggle("Smooth limits", _camera.smooth_limits, _set_smooth_limits)
			_add_action("Visit the west limit", _test_west_limit)
			_add_toggle("Snap on room entry", _room.snap_on_enter, _set_room_snap)
			_add_action("Start outside room", _reset_room_approach)
			_add_toggle("Camera debug", _camera.debug_draw_enabled, _set_camera_debug)
		"influences":
			_add_toggle("Magnet field", _magnet.enabled, _set_magnet_enabled)
			_add_toggle("Zoom field", _zoom_zone.enabled, _set_zoom_enabled)
			_add_toggle("Camera debug", _camera.debug_draw_enabled, _set_camera_debug)
		"path":
			_add_toggle("Path constraint", _path.enabled, _set_path_enabled)
			_add_choice("Constrain axis", ["Vertical follow (Y)", "Horizontal follow (X)"], int(_path.constraint_axis), _set_path_axis)
			_add_toggle("Camera debug", _camera.debug_draw_enabled, _set_camera_debug)
		"addons":
			_add_toggle("Mouse look", _mouse_follow.enabled, _set_mouse_follow)
			_add_slider("Mouse look radius", 0.0, 500.0, _mouse_follow.look_radius, _set_mouse_radius, " px")
			_add_toggle("Grid snap", _grid_snap.enabled, _set_grid_snap)
			_add_slider("Grid smoothing", 0.0, 1.0, _grid_snap.smoothing, _set_grid_smoothing, "")
			_add_toggle("Velocity zoom", _velocity_zoom.enabled, _set_velocity_zoom)
			_add_shake_controls()
		"cinematics":
			_add_action("Start camera tour", _start_cinematic, true)
			_add_action("Stop cinematic", _stop_cinematic)
			_add_action("Trigger shake", _trigger_shake)
			_add_toggle("Cinematic letterbox bars", _camera.cinematic_bars_enabled, _set_cinematic_bars_enabled)
			_add_slider("Bar height per edge", 0.0, 20.0, _camera.cinematic_bar_height, _set_cinematic_bar_height, "%")
			_add_slider("Bar slide time", 0.0, 1.5, _camera.cinematic_bar_transition_time, _set_cinematic_bar_transition_time, " s")
			var initial_status: String = "Tour is playing." if _camera.is_cinematic_playing() else "Ready for the camera tour."
			_cinematic_status = _label(initial_status, 12, MUTED_COLOR)
			_cinematic_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_controls_box.add_child(_cinematic_status)
			_add_toggle("Camera debug", _camera.debug_draw_enabled, _set_camera_debug)


func _jump_to_zone(index: int) -> void:
	var zone_index: int = clampi(index, 0, ZONES.size() - 1)
	_camera.stop_cinematic()
	_player.velocity = Vector2.ZERO
	_player.global_position = Vector2(float(ZONES[zone_index].x), FLOOR_Y - 42.0)
	_companion.global_position = _player.global_position + Vector2(520.0, -28.0)
	_camera.teleport_to_target()
	_select_zone(zone_index)


func _reset_room_approach() -> void:
	_camera.stop_cinematic()
	_player.velocity = Vector2.ZERO
	var room_left: float = _room.to_global(Vector2(-_room.room_size.x * 0.5, 0.0)).x
	_player.global_position = Vector2(room_left - 250.0, FLOOR_Y - 42.0)
	_camera.teleport_to_target()


func _test_west_limit() -> void:
	_camera.stop_cinematic()
	_player.velocity = Vector2.ZERO
	_player.global_position = Vector2(-250.0, FLOOR_Y - 42.0)
	_camera.teleport_to_target()


func _set_pair_target(enabled: bool) -> void:
	if enabled:
		if not _camera.has_target(_companion):
			_camera.add_target(_companion, 0.7, 36.0, Vector2.ZERO, false, 0.0)
	else:
		_camera.remove_target(_companion)
	_camera.teleport_to_target()
	call_deferred("_select_zone", _active_zone)


func _set_auto_framing(enabled: bool) -> void:
	_camera.auto_framing = enabled


func _get_primary_target_data() -> JuiceCamTargetData:
	var targets: Array[JuiceCamTargetData] = _camera.get_all_targets()
	if targets.is_empty():
		return null
	return targets[0]


func _set_target_lookahead(enabled: bool) -> void:
	var target_data: JuiceCamTargetData = _get_primary_target_data()
	if target_data != null:
		target_data.use_lookahead = enabled


func _set_lookahead_factor(value: float) -> void:
	var target_data: JuiceCamTargetData = _get_primary_target_data()
	if target_data != null:
		target_data.lookahead_factor = value


func _set_target_radius(value: float) -> void:
	var target_data: JuiceCamTargetData = _get_primary_target_data()
	if target_data != null:
		target_data.radius = value


func _set_target_vertical_offset(value: float) -> void:
	var target_data: JuiceCamTargetData = _get_primary_target_data()
	if target_data != null:
		target_data.offset = Vector2(target_data.offset.x, value)


func _set_companion_weight(value: float) -> void:
	var targets: Array[JuiceCamTargetData] = _camera.get_all_targets()
	if targets.size() > 1:
		targets[1].weight = value


func _set_smooth_motion(enabled: bool) -> void:
	_camera.smooth_motion = enabled


func _set_smooth_zoom(enabled: bool) -> void:
	_camera.smooth_zoom = enabled


func _set_smooth_limits(enabled: bool) -> void:
	_camera.smooth_limits = enabled


func _set_damping_type(index: int) -> void:
	_camera.set("damping_type", index)


func _set_rotation_enabled(enabled: bool) -> void:
	_camera.allow_rotation = enabled


func _set_rotation_offset(value: float) -> void:
	_camera.rotation_offset_degrees = value


func _set_camera_debug(enabled: bool) -> void:
	_camera.debug_draw_enabled = enabled


func _set_base_zoom(value: float) -> void:
	_camera.zoom = Vector2.ONE * value


func _set_horizontal_deadzone(enabled: bool) -> void:
	_camera.horizontal_deadzone_enabled = enabled


func _set_vertical_deadzone(enabled: bool) -> void:
	_camera.vertical_deadzone_enabled = enabled


func _set_limits_enabled(enabled: bool) -> void:
	_camera.limits_enabled = enabled


func _set_room_snap(enabled: bool) -> void:
	_room.snap_on_enter = enabled


func _set_magnet_enabled(enabled: bool) -> void:
	_magnet.enabled = enabled


func _set_zoom_enabled(enabled: bool) -> void:
	_zoom_zone.enabled = enabled


func _set_path_enabled(enabled: bool) -> void:
	_path.enabled = enabled


func _set_path_axis(index: int) -> void:
	_path.set("constraint_axis", index)


func _set_mouse_follow(enabled: bool) -> void:
	_mouse_follow.enabled = enabled


func _set_mouse_radius(value: float) -> void:
	_mouse_follow.look_radius = value


func _set_grid_snap(enabled: bool) -> void:
	_grid_snap.enabled = enabled


func _set_grid_smoothing(value: float) -> void:
	_grid_snap.smoothing = value


func _set_velocity_zoom(enabled: bool) -> void:
	_velocity_zoom.enabled = enabled


func _set_cinematic_bars_enabled(enabled: bool) -> void:
	_camera.cinematic_bars_enabled = enabled


func _set_cinematic_bar_height(value: float) -> void:
	_camera.cinematic_bar_height = value


func _set_cinematic_bar_transition_time(value: float) -> void:
	_camera.cinematic_bar_transition_time = value


func _set_shake_preset(index: int) -> void:
	if index < 0 or index >= SHAKE_PRESETS.size():
		return
	_shake.set("preset", int(SHAKE_PRESETS[index].id))


func _trigger_shake() -> void:
	_shake.shake()


func _start_cinematic() -> void:
	if _camera.start_cinematic("camera_lab"):
		_set_cinematic_status("Tour playing. Trigger a shake during the shot.")
	else:
		_set_cinematic_status("The camera tour could not start.")


func _stop_cinematic() -> void:
	_camera.stop_cinematic()
	_set_cinematic_status("Tour stopped. The camera is returning to the player.")


func _connect_cinematic_signals() -> void:
	_room.room_entered.connect(_on_influence_event.bind("Room entered"))
	_room.room_exited.connect(_on_influence_event.bind("Room exited"))
	_magnet.magnet_entered.connect(_on_influence_event.bind("Magnet entered"))
	_magnet.magnet_exited.connect(_on_influence_event.bind("Magnet exited"))
	_zoom_zone.zoom_area_entered.connect(_on_influence_event.bind("Zoom field entered"))
	_zoom_zone.zoom_area_exited.connect(_on_influence_event.bind("Zoom field exited"))
	_camera.cinematic_started.connect(func(sequence_name: StringName) -> void:
		_set_cinematic_status("Started: %s" % String(sequence_name)))
	_camera.cinematic_completed.connect(func(sequence_name: StringName) -> void:
		_set_cinematic_status("Completed: %s" % String(sequence_name)))
	_camera.cinematic_stopped.connect(func(sequence_name: StringName) -> void:
		_set_cinematic_status("Stopped: %s" % String(sequence_name)))
	_camera.cinematic_not_found.connect(func(sequence_name: StringName) -> void:
		_set_cinematic_status("No points found for: %s" % String(sequence_name)))
	_camera.cinematic_point_started.connect(func(sequence_name: StringName, point: JuiceCamCinematic2D) -> void:
		_set_cinematic_status("%s · shot %02d: %s" % [String(sequence_name), point.sequence_position + 1, point.name]))
	_camera.cinematic_point_completed.connect(func(sequence_name: StringName, point: JuiceCamCinematic2D) -> void:
		_set_cinematic_status("Finished shot %02d: %s" % [point.sequence_position + 1, point.name]))


func _on_influence_event(camera: Node2D, event_name: String) -> void:
	if camera == _camera and is_instance_valid(_event_label):
		_event_label.text = "Signal: %s" % event_name


func _set_cinematic_status(text: String) -> void:
	if is_instance_valid(_cinematic_status):
		_cinematic_status.text = text


func _add_shake_controls() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_theme_font_size_override("font_size", 13)
	picker.add_theme_color_override("font_color", TEXT_COLOR)
	picker.add_theme_stylebox_override("normal", _button_style(false))
	picker.add_theme_stylebox_override("hover", _button_style(true))
	picker.add_theme_stylebox_override("pressed", _button_style(true))
	for entry: Dictionary in SHAKE_PRESETS:
		picker.add_item(String(entry.name), int(entry.id))
	picker.select(3)
	picker.item_selected.connect(func(index: int) -> void:
		_set_shake_preset(index))
	row.add_child(picker)
	var shake_button := _make_button("Shake", true)
	shake_button.pressed.connect(_trigger_shake)
	row.add_child(shake_button)
	_controls_box.add_child(row)


func _add_toggle(title: String, initial: bool, callback: Callable) -> void:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.button_pressed = initial
	toggle.add_theme_font_size_override("font_size", 14)
	toggle.add_theme_color_override("font_color", TEXT_COLOR)
	toggle.add_theme_color_override("font_hover_color", Color.WHITE)
	toggle.toggled.connect(callback)
	_controls_box.add_child(toggle)


func _add_action(title: String, callback: Callable, primary: bool = false) -> void:
	var button := _make_button(title, primary)
	button.pressed.connect(callback)
	_controls_box.add_child(button)


func _add_choice(title: String, options: Array[String], selected: int, callback: Callable) -> void:
	var label := _label(title, 13, MUTED_COLOR, true)
	_controls_box.add_child(label)
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_theme_font_size_override("font_size", 13)
	picker.add_theme_stylebox_override("normal", _button_style(false))
	picker.add_theme_stylebox_override("hover", _button_style(true))
	for option_index: int in range(options.size()):
		picker.add_item(options[option_index], option_index)
	picker.select(selected)
	picker.item_selected.connect(callback)
	_controls_box.add_child(picker)


func _add_slider(title: String, minimum: float, maximum: float, initial: float, callback: Callable, suffix: String) -> void:
	var header := HBoxContainer.new()
	header.add_child(_label(title, 13, TEXT_COLOR, true))
	var value_label := _label("%.2f%s" % [initial, suffix], 12, MUTED_COLOR)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(value_label)
	_controls_box.add_child(header)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.01 if maximum - minimum <= 2.0 else 1.0
	slider.value = clampf(initial, minimum, maximum)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float) -> void:
		callback.call(value)
		value_label.text = "%.2f%s" % [value, suffix] if maximum - minimum <= 2.0 else "%.0f%s" % [value, suffix])
	_controls_box.add_child(slider)


func _clear_controls() -> void:
	_cinematic_status = null
	for child: Node in _controls_box.get_children():
		_controls_box.remove_child(child)
		child.queue_free()


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.25))
	return label


func _make_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(primary))
	button.add_theme_stylebox_override("hover", _button_style(true))
	button.add_theme_stylebox_override("pressed", _button_style(true))
	button.add_theme_stylebox_override("disabled", _button_style(false))
	return button


func _button_style(highlighted: bool) -> StyleBoxFlat:
	return _panel_style(Color("#38284a") if highlighted else Color("#1a3045"), ACCENT_COLOR if highlighted else PANEL_EDGE, 10, 1)


func _panel_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(14.0)
	return style
