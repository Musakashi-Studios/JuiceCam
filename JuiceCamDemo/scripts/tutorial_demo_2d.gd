extends Node2D

## Controls which tutorial-specific options appear in the bottom HUD.

const WELCOME_CINEMATIC_NAME: String = "welcome_tour"
const WELCOME_CINEMATIC_CAPTIONS: Array[String] = [
	"This is a cinematic sequence. JuiceCam moves through points placed in the level.",
	"Each point can set the camera’s position, rotation, zoom, and hold time.",
	"Set a point’s hold time to zero to glide straight into the next shot.",
	"When the sequence ends, the camera returns to its targets and the letterbox bars slide away.",
]
const SCREEN_SHAKE_PRESET_NAMES: Array[String] = [
	"Gunshot",
	"Earthquake",
	"Handheld",
	"Explosion",
	"Impact",
	"Rumble",
	"Vibration",
	"Wobbly",
]

@onready var _welcome_area: Area2D = $Level/Areas/WelcomeArea
@onready var _room_area: Area2D = $Level/Areas/RoomArea
@onready var _chained_rooms_area: Area2D = $Level/Areas/OverlappingRoomsArea
@onready var _influences_area: Area2D = $Level/Areas/ZoomAndMagnets
@onready var _mouse_follow_area: Area2D = $Level/Areas/MouseFollow
@onready var _multi_target_area: Area2D = $Level/Areas/MultiTargetArea
@onready var _screen_shake_area: Area2D = $Level/Areas/ScreenShakeArea
@onready var _player: CharacterBody2D = $Player
@onready var _npc: CharacterBody2D = $Npc
@onready var _camera: JuiceCam2D = $Player/JuiceCam2D
@onready var _room: JuiceCamRoom2D = $Level/Influences/JuiceCamRoom2D
@onready var _chained_room_a: JuiceCamRoom2D = $Level/Influences/JuiceCamRoom2D2
@onready var _chained_room_b: JuiceCamRoom2D = $Level/Influences/JuiceCamRoom2D3
@onready var _magnet: JuiceCamMagnet2D = $Level/Influences/JuiceCamMagnet2D
@onready var _zoom: JuiceCamZoom2D = $Level/Influences/JuiceCamZoom2D
@onready var _welcome_tutorial: Control = $Tutorials/Welcome
@onready var _room_tutorial: Control = $Tutorials/Rooms
@onready var _chained_rooms_tutorial: Control = $Tutorials/ChainedRooms
@onready var _multi_target_tutorial: Control = $Tutorials/MultiTargetTutorial
@onready var _screen_shake_tutorial: Control = $Tutorials/ScreenShake
@onready var _welcome_controls: Control = $HUD/Controls/WelcomeControls
@onready var _debug_draw_toggle: CheckBox = $HUD/Controls/WelcomeControls/Row/DebugDrawToggle
@onready var _welcome_cinematic_button: Button = $HUD/Controls/WelcomeControls/Row/PlayCinematicButton
@onready var _cinematic_caption_panel: PanelContainer = $HUD/CinematicCaption
@onready var _cinematic_caption: Label = $HUD/CinematicCaption/Message
@onready var _room_controls: Control = $HUD/Controls/RoomControls
@onready var _room_enabled_toggle: CheckBox = $HUD/Controls/RoomControls/Row/RoomEnabledToggle
@onready var _room_snap_toggle: CheckBox = $HUD/Controls/RoomControls/Row/SnapOnEntryToggle
@onready var _room_debug_toggle: CheckBox = $HUD/Controls/RoomControls/Row/DebugDrawToggle

var _mouse_follow: JuiceCamMouseFollow2D
var _screen_shake: JuiceCamScreenShake2D
var _influence_controls: PanelContainer
var _magnet_gradual_toggle: CheckBox
var _zoom_gradual_toggle: CheckBox
var _mouse_follow_controls: PanelContainer
var _mouse_follow_toggle: CheckBox
var _mouse_radius_slider: HSlider
var _mouse_radius_value: Label
var _multi_target_controls: PanelContainer
var _auto_framing_toggle: CheckBox
var _player_weight_slider: HSlider
var _player_weight_value: Label
var _npc_weight_slider: HSlider
var _npc_weight_value: Label
var _player_target_data: JuiceCamTargetData
var _npc_target_data: JuiceCamTargetData
var _screen_shake_controls: PanelContainer
var _screen_shake_preset: OptionButton
var _screen_shake_button: Button

var _player_in_welcome_area: bool = false
var _player_in_room_area: bool = false
var _player_in_chained_rooms_area: bool = false
var _player_in_influences_area: bool = false
var _player_in_mouse_follow_area: bool = false
var _player_in_multi_target_area: bool = false
var _player_in_screen_shake_area: bool = false


func _ready() -> void:
	_ensure_mouse_follow_addon()
	_ensure_screen_shake_addon()
	# Adding an add-on rebuilds the camera's runtime copies. Reacquire both so
	# the demo controls never keep references to an add-on that was replaced.
	_mouse_follow = _camera.get_addon("mouse_follow") as JuiceCamMouseFollow2D
	_screen_shake = _camera.get_addon("screen_shake") as JuiceCamScreenShake2D
	if _mouse_follow != null:
		_mouse_follow.enabled = false
	_build_influence_controls()
	_build_mouse_follow_controls()
	_build_multi_target_controls()
	_build_screen_shake_controls()
	_welcome_tutorial.show()
	_room_tutorial.show()
	_chained_rooms_tutorial.show()
	_multi_target_tutorial.show()
	_screen_shake_tutorial.show()
	_welcome_controls.hide()
	_room_controls.hide()
	_debug_draw_toggle.focus_mode = Control.FOCUS_NONE
	_welcome_cinematic_button.focus_mode = Control.FOCUS_NONE
	_cinematic_caption_panel.hide()
	_welcome_cinematic_button.pressed.connect(_start_welcome_cinematic)
	_camera.cinematic_point_started.connect(_on_cinematic_point_started)
	_camera.cinematic_stopped.connect(_on_cinematic_stopped)
	_room_enabled_toggle.focus_mode = Control.FOCUS_NONE
	_room_snap_toggle.focus_mode = Control.FOCUS_NONE
	_room_debug_toggle.focus_mode = Control.FOCUS_NONE
	_magnet_gradual_toggle.focus_mode = Control.FOCUS_NONE
	_zoom_gradual_toggle.focus_mode = Control.FOCUS_NONE
	_mouse_follow_toggle.focus_mode = Control.FOCUS_NONE
	_mouse_radius_slider.focus_mode = Control.FOCUS_NONE
	_auto_framing_toggle.focus_mode = Control.FOCUS_NONE
	_player_weight_slider.focus_mode = Control.FOCUS_NONE
	_npc_weight_slider.focus_mode = Control.FOCUS_NONE
	_debug_draw_toggle.release_focus()
	_sync_debug_toggles()
	_sync_influence_toggles()
	_debug_draw_toggle.toggled.connect(_on_debug_draw_toggled)
	_room_debug_toggle.toggled.connect(_on_debug_draw_toggled)
	_room_enabled_toggle.toggled.connect(_on_room_enabled_toggled)
	_room_snap_toggle.toggled.connect(_on_room_snap_toggled)
	_welcome_area.body_entered.connect(_on_tutorial_area_body_entered)
	_welcome_area.body_exited.connect(_on_tutorial_area_body_exited)
	_room_area.body_entered.connect(_on_tutorial_area_body_entered)
	_room_area.body_exited.connect(_on_tutorial_area_body_exited)
	_chained_rooms_area.body_entered.connect(_on_tutorial_area_body_entered)
	_chained_rooms_area.body_exited.connect(_on_tutorial_area_body_exited)
	_influences_area.body_entered.connect(_on_tutorial_area_body_entered)
	_influences_area.body_exited.connect(_on_tutorial_area_body_exited)
	_mouse_follow_area.body_entered.connect(_on_mouse_follow_area_body_entered)
	_mouse_follow_area.body_exited.connect(_on_mouse_follow_area_body_exited)
	_multi_target_area.body_entered.connect(_on_multi_target_area_body_entered)
	_multi_target_area.body_exited.connect(_on_multi_target_area_body_exited)
	_screen_shake_area.body_entered.connect(_on_tutorial_area_body_entered)
	_screen_shake_area.body_exited.connect(_on_tutorial_area_body_exited)
	await get_tree().physics_frame
	if is_instance_valid(_player):
		_player_in_welcome_area = _welcome_area.overlaps_body(_player)
		_player_in_room_area = _room_area.overlaps_body(_player)
		_player_in_chained_rooms_area = _chained_rooms_area.overlaps_body(_player)
		_player_in_influences_area = _influences_area.overlaps_body(_player)
		_player_in_mouse_follow_area = _mouse_follow_area.overlaps_body(_player)
		_player_in_multi_target_area = _multi_target_area.overlaps_body(_player)
		_player_in_screen_shake_area = _screen_shake_area.overlaps_body(_player)
		_mouse_follow.enabled = _player_in_mouse_follow_area
		if _player_in_multi_target_area:
			_add_npc_target()
		_update_tutorial_zone()


func _start_welcome_cinematic() -> void:
	_cinematic_caption_panel.hide()
	_camera.start_cinematic(WELCOME_CINEMATIC_NAME)


func _on_cinematic_point_started(
	sequence_name: StringName,
	point: JuiceCamCinematic2D
) -> void:
	if sequence_name != StringName(WELCOME_CINEMATIC_NAME):
		return
	if point.sequence_position < 0 or point.sequence_position >= WELCOME_CINEMATIC_CAPTIONS.size():
		_cinematic_caption_panel.hide()
		return
	_cinematic_caption.text = WELCOME_CINEMATIC_CAPTIONS[point.sequence_position]
	_cinematic_caption_panel.show()


func _on_cinematic_stopped(_sequence_name: StringName) -> void:
	_cinematic_caption_panel.hide()


func _ensure_mouse_follow_addon() -> void:
	_mouse_follow = _camera.get_addon("mouse_follow") as JuiceCamMouseFollow2D
	if _mouse_follow == null:
		var addon: JuiceCamMouseFollow2D = JuiceCamMouseFollow2D.new()
		addon.look_radius = 300.0
		addon.enabled = false
		_mouse_follow = _camera.add_addon(addon) as JuiceCamMouseFollow2D
	if _mouse_follow != null:
		_mouse_follow.enabled = false


func _ensure_screen_shake_addon() -> void:
	_screen_shake = _camera.get_addon("screen_shake") as JuiceCamScreenShake2D
	if _screen_shake == null:
		var addon: JuiceCamScreenShake2D = JuiceCamScreenShake2D.new()
		addon.apply_preset(JuiceCamScreenShake2D.Preset.IMPACT)
		_screen_shake = _camera.add_addon(addon) as JuiceCamScreenShake2D
	if _screen_shake == null:
		push_error("The screen-shake demo could not register its camera add-on.")
	else:
		_screen_shake.enabled = true


func _on_tutorial_area_body_entered(body: Node2D) -> void:
	if body != _player:
		return
	_player_in_welcome_area = _welcome_area.overlaps_body(_player)
	_player_in_room_area = _room_area.overlaps_body(_player)
	_player_in_chained_rooms_area = _chained_rooms_area.overlaps_body(_player)
	_player_in_influences_area = _influences_area.overlaps_body(_player)
	_player_in_screen_shake_area = _screen_shake_area.overlaps_body(_player)
	_update_tutorial_zone()


func _on_tutorial_area_body_exited(body: Node2D) -> void:
	if body != _player:
		return
	_player_in_welcome_area = _welcome_area.overlaps_body(_player)
	_player_in_room_area = _room_area.overlaps_body(_player)
	_player_in_chained_rooms_area = _chained_rooms_area.overlaps_body(_player)
	_player_in_influences_area = _influences_area.overlaps_body(_player)
	_player_in_screen_shake_area = _screen_shake_area.overlaps_body(_player)
	_update_tutorial_zone()


func _on_mouse_follow_area_body_entered(body: Node2D) -> void:
	if body != _player:
		return
	_player_in_mouse_follow_area = true
	_mouse_follow.enabled = true
	_update_tutorial_zone()


func _on_mouse_follow_area_body_exited(body: Node2D) -> void:
	if body != _player:
		return
	_player_in_mouse_follow_area = false
	_mouse_follow.enabled = false
	_update_tutorial_zone()


func _on_multi_target_area_body_entered(body: Node2D) -> void:
	if body != _player:
		return
	_player_in_multi_target_area = true
	_add_npc_target()
	_update_tutorial_zone()


func _on_multi_target_area_body_exited(body: Node2D) -> void:
	if body != _player:
		return
	_player_in_multi_target_area = false
	_camera.remove_target(_npc)
	_npc_target_data = null
	_update_tutorial_zone()


func _add_npc_target() -> void:
	_npc_target_data = _camera.add_target(_npc, 1.0, 32.0, Vector2.ZERO, false, 0.0)
	_player_target_data = _get_target_data(_player)
	if _player_target_data == null or _npc_target_data == null:
		push_error("The multi-target demo could not register the player and NPC camera targets.")
		return
	_sync_multi_target_controls()


func _update_tutorial_zone() -> void:
	var show_chained_rooms: bool = _player_in_chained_rooms_area
	var show_room: bool = _player_in_room_area and not show_chained_rooms
	var show_welcome: bool = _player_in_welcome_area and not show_room and not show_chained_rooms
	var show_influences: bool = (
		_player_in_influences_area
		and not show_welcome
		and not show_room
		and not show_chained_rooms
	)
	var show_mouse_follow: bool = (
		_player_in_mouse_follow_area
		and not show_welcome
		and not show_room
		and not show_chained_rooms
		and not show_influences
	)
	var show_multi_target: bool = (
		_player_in_multi_target_area
		and not show_welcome
		and not show_room
		and not show_chained_rooms
		and not show_influences
		and not show_mouse_follow
	)
	var show_screen_shake: bool = (
		_player_in_screen_shake_area
		and not show_welcome
		and not show_room
		and not show_chained_rooms
		and not show_influences
		and not show_mouse_follow
		and not show_multi_target
	)
	_welcome_controls.visible = show_welcome
	_room_controls.visible = show_room or show_chained_rooms
	_influence_controls.visible = show_influences
	_mouse_follow_controls.visible = show_mouse_follow
	_multi_target_controls.visible = show_multi_target
	_screen_shake_controls.visible = show_screen_shake
	if show_welcome or show_room or show_chained_rooms:
		_sync_debug_toggles()
	if show_room or show_chained_rooms:
		_sync_room_toggles()
	if show_influences:
		_sync_influence_toggles()
	if show_mouse_follow:
		_sync_mouse_follow_controls()
	if show_multi_target:
		_sync_multi_target_controls()
	if show_screen_shake:
		_sync_screen_shake_controls()


func _sync_debug_toggles() -> void:
	_debug_draw_toggle.set_pressed_no_signal(_camera.debug_draw_enabled)
	_room_debug_toggle.set_pressed_no_signal(_camera.debug_draw_enabled)


func _sync_room_toggles() -> void:
	var rooms: Array[JuiceCamRoom2D] = _get_controlled_rooms()
	if rooms.is_empty():
		return
	var all_enabled: bool = true
	var all_snap_on_entry: bool = true
	for room: JuiceCamRoom2D in rooms:
		all_enabled = all_enabled and room.enabled
		all_snap_on_entry = all_snap_on_entry and room.snap_on_enter
	_room_enabled_toggle.set_pressed_no_signal(all_enabled)
	_room_snap_toggle.set_pressed_no_signal(all_snap_on_entry)


func _sync_influence_toggles() -> void:
	_magnet_gradual_toggle.set_pressed_no_signal(not _magnet.use_full_force)
	_zoom_gradual_toggle.set_pressed_no_signal(_zoom.gradual_zoom)


func _build_influence_controls() -> void:
	var controls_container: PanelContainer = $HUD/Controls
	_influence_controls = PanelContainer.new()
	_influence_controls.name = "InfluenceControls"
	_influence_controls.visible = false
	_influence_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_influence_controls.add_theme_stylebox_override(
		"panel",
		_room_controls.get_theme_stylebox("panel")
	)
	controls_container.add_child(_influence_controls)

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 24)
	_influence_controls.add_child(row)

	_magnet_gradual_toggle = _make_influence_toggle(
		"Gradual magnet pull",
		not _magnet.use_full_force,
		_on_magnet_gradual_toggled
	)
	_magnet_gradual_toggle.name = "MagnetGradualToggle"
	_zoom_gradual_toggle = _make_influence_toggle(
		"Gradual zoom blend",
		_zoom.gradual_zoom,
		_on_zoom_gradual_toggled
	)
	_zoom_gradual_toggle.name = "ZoomGradualToggle"
	row.add_child(_magnet_gradual_toggle)
	row.add_child(_zoom_gradual_toggle)


func _build_mouse_follow_controls() -> void:
	var controls_container: PanelContainer = $HUD/Controls
	_mouse_follow_controls = PanelContainer.new()
	_mouse_follow_controls.name = "MouseFollowControls"
	_mouse_follow_controls.visible = false
	_mouse_follow_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mouse_follow_controls.add_theme_stylebox_override(
		"panel",
		_room_controls.get_theme_stylebox("panel")
	)
	controls_container.add_child(_mouse_follow_controls)

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 20)
	_mouse_follow_controls.add_child(row)

	_mouse_follow_toggle = _make_influence_toggle(
		"Mouse follow",
		_mouse_follow.enabled,
		_on_mouse_follow_toggled
	)
	_mouse_follow_toggle.name = "MouseFollowToggle"
	_mouse_follow_toggle.custom_minimum_size = Vector2(360.0, 96.0)
	row.add_child(_mouse_follow_toggle)

	var radius_label: Label = Label.new()
	radius_label.text = "Radius"
	radius_label.add_theme_font_size_override("font_size", 24)
	radius_label.add_theme_color_override("font_color", _debug_draw_toggle.get_theme_color("font_color"))
	row.add_child(radius_label)

	_mouse_radius_slider = HSlider.new()
	_mouse_radius_slider.name = "MouseRadiusSlider"
	_mouse_radius_slider.custom_minimum_size = Vector2(420.0, 36.0)
	_mouse_radius_slider.min_value = 0.0
	_mouse_radius_slider.max_value = 600.0
	_mouse_radius_slider.step = 10.0
	_mouse_radius_slider.value = _mouse_follow.look_radius
	_mouse_radius_slider.focus_mode = Control.FOCUS_NONE
	_mouse_radius_slider.modulate = Color("#8DE9A7")
	_style_mouse_radius_slider()
	_mouse_radius_slider.value_changed.connect(_on_mouse_radius_changed)
	row.add_child(_mouse_radius_slider)

	_mouse_radius_value = Label.new()
	_mouse_radius_value.name = "MouseRadiusValue"
	_mouse_radius_value.custom_minimum_size = Vector2(100.0, 0.0)
	_mouse_radius_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mouse_radius_value.add_theme_font_size_override("font_size", 24)
	_mouse_radius_value.add_theme_color_override("font_color", Color("#8DE9A7"))
	row.add_child(_mouse_radius_value)
	_update_mouse_radius_value(_mouse_radius_slider.value)


func _style_mouse_radius_slider() -> void:
	_style_green_slider(_mouse_radius_slider)


func _style_green_slider(slider: HSlider) -> void:
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color("#354247")
	track.set_corner_radius_all(5)
	track.content_margin_top = 4.0
	track.content_margin_bottom = 4.0
	slider.add_theme_stylebox_override("slider", track)

	var progress: StyleBoxFlat = StyleBoxFlat.new()
	progress.bg_color = Color("#45D878")
	progress.set_corner_radius_all(5)
	progress.content_margin_top = 4.0
	progress.content_margin_bottom = 4.0
	slider.add_theme_stylebox_override("grabber_area", progress)

	var highlighted_progress: StyleBoxFlat = progress.duplicate() as StyleBoxFlat
	highlighted_progress.bg_color = Color("#70F19A")
	slider.add_theme_stylebox_override("grabber_area_highlight", highlighted_progress)


func _build_multi_target_controls() -> void:
	var controls_container: PanelContainer = $HUD/Controls
	_multi_target_controls = PanelContainer.new()
	_multi_target_controls.name = "MultiTargetControls"
	_multi_target_controls.visible = false
	_multi_target_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_multi_target_controls.add_theme_stylebox_override(
		"panel",
		_room_controls.get_theme_stylebox("panel")
	)
	controls_container.add_child(_multi_target_controls)

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	_multi_target_controls.add_child(row)

	_auto_framing_toggle = _make_influence_toggle(
		"Auto framing",
		_camera.auto_framing,
		_on_auto_framing_toggled
	)
	_auto_framing_toggle.custom_minimum_size = Vector2(250.0, 96.0)
	row.add_child(_auto_framing_toggle)

	var player_weight_control: HBoxContainer = _make_weight_control("Player", "PlayerWeight", 1.0)
	_player_weight_slider = player_weight_control.get_node("Slider") as HSlider
	_player_weight_value = player_weight_control.get_node("Value") as Label
	_player_weight_slider.value_changed.connect(_on_player_weight_changed)
	row.add_child(player_weight_control)

	var npc_weight_control: HBoxContainer = _make_weight_control(
		"NPC", "NpcWeight", 1.0
	)
	_npc_weight_slider = npc_weight_control.get_node("Slider") as HSlider
	_npc_weight_value = npc_weight_control.get_node("Value") as Label
	_npc_weight_slider.value_changed.connect(_on_npc_weight_changed)
	row.add_child(npc_weight_control)


func _build_screen_shake_controls() -> void:
	var controls_container: PanelContainer = $HUD/Controls
	_screen_shake_controls = PanelContainer.new()
	_screen_shake_controls.name = "ScreenShakeControls"
	_screen_shake_controls.visible = false
	_screen_shake_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen_shake_controls.add_theme_stylebox_override(
		"panel",
		_room_controls.get_theme_stylebox("panel")
	)
	controls_container.add_child(_screen_shake_controls)

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 20)
	_screen_shake_controls.add_child(row)

	var preset_label: Label = Label.new()
	preset_label.text = "Shake preset"
	preset_label.add_theme_font_size_override("font_size", 24)
	preset_label.add_theme_color_override(
		"font_color",
		_debug_draw_toggle.get_theme_color("font_color")
	)
	row.add_child(preset_label)

	_screen_shake_preset = OptionButton.new()
	_screen_shake_preset.name = "ScreenShakePreset"
	_screen_shake_preset.custom_minimum_size = Vector2(280.0, 48.0)
	_screen_shake_preset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_screen_shake_preset.focus_mode = Control.FOCUS_NONE
	_screen_shake_preset.disabled = _screen_shake == null
	_screen_shake_preset.add_theme_font_size_override("font_size", 22)
	for preset_name: String in SCREEN_SHAKE_PRESET_NAMES:
		_screen_shake_preset.add_item(preset_name)
	_screen_shake_preset.item_selected.connect(_on_screen_shake_preset_selected)
	row.add_child(_screen_shake_preset)

	_screen_shake_button = Button.new()
	_screen_shake_button.name = "TriggerScreenShake"
	_screen_shake_button.text = "Trigger shake"
	_screen_shake_button.custom_minimum_size = Vector2(240.0, 64.0)
	_screen_shake_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_screen_shake_button.focus_mode = Control.FOCUS_NONE
	_screen_shake_button.disabled = _screen_shake == null
	_screen_shake_button.add_theme_font_size_override("font_size", 22)
	_screen_shake_button.add_theme_color_override(
		"font_color",
		_welcome_cinematic_button.get_theme_color("font_color")
	)
	_screen_shake_button.add_theme_color_override(
		"font_pressed_color",
		_welcome_cinematic_button.get_theme_color("font_pressed_color")
	)
	_screen_shake_button.add_theme_color_override(
		"font_hover_color",
		_welcome_cinematic_button.get_theme_color("font_hover_color")
	)
	_screen_shake_button.add_theme_stylebox_override(
		"normal",
		_welcome_cinematic_button.get_theme_stylebox("normal")
	)
	_screen_shake_button.add_theme_stylebox_override(
		"pressed",
		_welcome_cinematic_button.get_theme_stylebox("pressed")
	)
	_screen_shake_button.add_theme_stylebox_override(
		"hover",
		_welcome_cinematic_button.get_theme_stylebox("hover")
	)
	_screen_shake_button.pressed.connect(_on_screen_shake_button_pressed)
	row.add_child(_screen_shake_button)
	_sync_screen_shake_controls()


func _sync_screen_shake_controls() -> void:
	if _screen_shake == null or _screen_shake_preset == null:
		return
	var selected_index: int = -1
	match _screen_shake.preset:
		JuiceCamScreenShake2D.Preset.GUNSHOT:
			selected_index = 0
		JuiceCamScreenShake2D.Preset.EARTHQUAKE:
			selected_index = 1
		JuiceCamScreenShake2D.Preset.HANDHELD:
			selected_index = 2
		JuiceCamScreenShake2D.Preset.EXPLOSION:
			selected_index = 3
		JuiceCamScreenShake2D.Preset.IMPACT:
			selected_index = 4
		JuiceCamScreenShake2D.Preset.RUMBLE:
			selected_index = 5
		JuiceCamScreenShake2D.Preset.VIBRATION:
			selected_index = 6
		JuiceCamScreenShake2D.Preset.WOBBLY:
			selected_index = 7
	if selected_index >= 0:
		_screen_shake_preset.select(selected_index)


func _on_screen_shake_preset_selected(index: int) -> void:
	if _screen_shake == null:
		return
	match index:
		0:
			_screen_shake.apply_preset(JuiceCamScreenShake2D.Preset.GUNSHOT)
		1:
			_screen_shake.apply_preset(JuiceCamScreenShake2D.Preset.EARTHQUAKE)
		2:
			_screen_shake.apply_preset(JuiceCamScreenShake2D.Preset.HANDHELD)
		3:
			_screen_shake.apply_preset(JuiceCamScreenShake2D.Preset.EXPLOSION)
		4:
			_screen_shake.apply_preset(JuiceCamScreenShake2D.Preset.IMPACT)
		5:
			_screen_shake.apply_preset(JuiceCamScreenShake2D.Preset.RUMBLE)
		6:
			_screen_shake.apply_preset(JuiceCamScreenShake2D.Preset.VIBRATION)
		7:
			_screen_shake.apply_preset(JuiceCamScreenShake2D.Preset.WOBBLY)


func _on_screen_shake_button_pressed() -> void:
	if _screen_shake == null:
		return
	_screen_shake.shake()


func _make_weight_control(title: String, control_name: String, initial_value: float) -> HBoxContainer:
	var control: HBoxContainer = HBoxContainer.new()
	control.name = control_name
	control.alignment = BoxContainer.ALIGNMENT_CENTER
	control.add_theme_constant_override("separation", 8)

	var title_label: Label = Label.new()
	title_label.text = title
	title_label.custom_minimum_size = Vector2(96.0, 0.0)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", _debug_draw_toggle.get_theme_color("font_color"))
	control.add_child(title_label)

	var slider: HSlider = HSlider.new()
	slider.name = "Slider"
	slider.custom_minimum_size = Vector2(220.0, 36.0)
	slider.min_value = 0.0
	slider.max_value = 3.0
	slider.step = 0.1
	slider.value = initial_value
	slider.focus_mode = Control.FOCUS_NONE
	slider.modulate = Color("#8DE9A7")
	_style_green_slider(slider)
	control.add_child(slider)

	var value_label: Label = Label.new()
	value_label.name = "Value"
	value_label.custom_minimum_size = Vector2(56.0, 0.0)
	value_label.text = "%.1f" % initial_value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 22)
	value_label.add_theme_color_override("font_color", Color("#8DE9A7"))
	control.add_child(value_label)
	return control


func _sync_multi_target_controls() -> void:
	if _player_target_data == null or _npc_target_data == null:
		return
	_auto_framing_toggle.set_pressed_no_signal(_camera.auto_framing)
	_player_weight_slider.set_value_no_signal(_player_target_data.weight)
	_npc_weight_slider.set_value_no_signal(_npc_target_data.weight)
	_update_weight_value(_player_weight_value, _player_target_data.weight)
	_update_weight_value(_npc_weight_value, _npc_target_data.weight)


func _get_target_data(target_node: Node2D) -> JuiceCamTargetData:
	for target_data: JuiceCamTargetData in _camera.targets:
		if target_data.node == target_node:
			return target_data
	return null


func _on_auto_framing_toggled(enabled: bool) -> void:
	_camera.auto_framing = enabled


func _on_player_weight_changed(weight: float) -> void:
	if _player_target_data == null:
		return
	_player_target_data.weight = weight
	_update_weight_value(_player_weight_value, weight)


func _on_npc_weight_changed(weight: float) -> void:
	if _npc_target_data == null:
		return
	_npc_target_data.weight = weight
	_update_weight_value(_npc_weight_value, weight)


func _update_weight_value(value_label: Label, weight: float) -> void:
	value_label.text = "%.1f" % weight


func _make_influence_toggle(title: String, initial: bool, callback: Callable) -> CheckBox:
	var toggle: CheckBox = CheckBox.new()
	toggle.text = title
	toggle.button_pressed = initial
	toggle.custom_minimum_size = Vector2(480.0, 96.0)
	toggle.size_flags_horizontal = Control.SIZE_FILL
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.add_theme_font_size_override("font_size", 24)
	toggle.add_theme_color_override("font_color", _debug_draw_toggle.get_theme_color("font_color"))
	toggle.add_theme_color_override("font_hover_color", _debug_draw_toggle.get_theme_color("font_hover_color"))
	toggle.add_theme_constant_override("h_separation", 18)
	toggle.add_theme_constant_override("icon_max_width", 36)
	toggle.add_theme_icon_override("checked", _debug_draw_toggle.get_theme_icon("checked"))
	toggle.add_theme_icon_override("unchecked", _debug_draw_toggle.get_theme_icon("unchecked"))
	toggle.toggled.connect(callback)
	return toggle


func _get_controlled_rooms() -> Array[JuiceCamRoom2D]:
	var rooms: Array[JuiceCamRoom2D] = []
	if _player_in_chained_rooms_area:
		rooms.append(_chained_room_a)
		rooms.append(_chained_room_b)
	elif _player_in_room_area:
		rooms.append(_room)
	return rooms


func _on_debug_draw_toggled(enabled: bool) -> void:
	_camera.debug_draw_enabled = enabled
	_debug_draw_toggle.set_pressed_no_signal(enabled)
	_room_debug_toggle.set_pressed_no_signal(enabled)


func _on_room_enabled_toggled(enabled: bool) -> void:
	for room: JuiceCamRoom2D in _get_controlled_rooms():
		room.enabled = enabled


func _on_room_snap_toggled(enabled: bool) -> void:
	for room: JuiceCamRoom2D in _get_controlled_rooms():
		room.snap_on_enter = enabled


func _on_magnet_gradual_toggled(enabled: bool) -> void:
	_magnet.use_full_force = not enabled


func _on_zoom_gradual_toggled(enabled: bool) -> void:
	_zoom.gradual_zoom = enabled


func _sync_mouse_follow_controls() -> void:
	_mouse_follow_toggle.set_pressed_no_signal(_mouse_follow.enabled)
	_mouse_radius_slider.set_value_no_signal(_mouse_follow.look_radius)
	_update_mouse_radius_value(_mouse_follow.look_radius)


func _on_mouse_follow_toggled(enabled: bool) -> void:
	_mouse_follow.enabled = enabled


func _on_mouse_radius_changed(value: float) -> void:
	_mouse_follow.look_radius = value
	_update_mouse_radius_value(value)


func _update_mouse_radius_value(value: float) -> void:
	_mouse_radius_value.text = "%d px" % roundi(value)
