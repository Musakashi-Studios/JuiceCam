@tool
extends VBoxContainer

## Rendered target stack for the JuiceCam2D Inspector.

const JuiceCamTargetDataScript: GDScript = preload(
	"res://addons/juicecam/2d/juice_cam_target_data_2d.gd"
)

const TARGET_HEADER_LEFT_OVERHANG: int = 6

static var _collapsed_cards: Dictionary = {}
static var _targets_section_collapsed: bool = false

var _camera: JuiceCam2D
var _undo_redo: EditorUndoRedoManager


func _init(camera: JuiceCam2D) -> void:
	_camera = camera
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_undo_redo = EditorInterface.get_editor_undo_redo()
	if _undo_redo != null and not _undo_redo.version_changed.is_connected(_on_undo_redo_version_changed):
		_undo_redo.version_changed.connect(_on_undo_redo_version_changed)
	_build_ui()


func _exit_tree() -> void:
	if _undo_redo != null and _undo_redo.version_changed.is_connected(_on_undo_redo_version_changed):
		_undo_redo.version_changed.disconnect(_on_undo_redo_version_changed)


func _build_ui() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	if not is_instance_valid(_camera):
		return

	add_theme_constant_override("separation", 8)
	var targets: Array[JuiceCamTargetData] = _camera.get_all_targets()

	var target_well: PanelContainer = PanelContainer.new()
	target_well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_well.add_theme_stylebox_override(
		"panel",
		_make_panel_style(_editor_color("dark_color_1", Color(0.12, 0.13, 0.16, 1.0)), 8)
	)
	var target_list: VBoxContainer = VBoxContainer.new()
	target_list.add_theme_constant_override("separation", 6)
	target_well.add_child(target_list)
	if targets.is_empty():
		target_list.add_child(_create_empty_state())
	else:
		for index: int in range(targets.size()):
			target_list.add_child(_create_target_card(index, targets[index]))

	var add_button: Button = _create_accent_button("Add Target", "Add")
	add_button.tooltip_text = "Add a target by selecting a Node2D from the current scene."
	add_button.pressed.connect(_open_node_picker.bind(-1))

	var section_content: VBoxContainer = VBoxContainer.new()
	section_content.add_theme_constant_override("separation", 8)
	section_content.visible = not _targets_section_collapsed
	section_content.add_child(target_well)
	section_content.add_child(add_button)
	add_child(_create_section_header(targets.size(), section_content))
	add_child(section_content)


func _create_section_header(target_count: int, section_content: Control) -> Control:
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var fold_button: Button = Button.new()
	fold_button.flat = true
	fold_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	fold_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fold_button.custom_minimum_size.y = 24
	fold_button.add_theme_constant_override("icon_max_width", 16)
	_apply_flat_styles(fold_button, true)
	var editor_theme: Theme = EditorInterface.get_editor_theme()
	if editor_theme != null and editor_theme.has_font("bold", "EditorFonts"):
		fold_button.add_theme_font_override("font", editor_theme.get_font("bold", "EditorFonts"))
	_update_targets_section_button(fold_button)
	fold_button.pressed.connect(_toggle_targets_section.bind(section_content, fold_button))
	header.gui_input.connect(
		_on_targets_header_gui_input.bind(header, section_content, fold_button)
	)
	var fold_button_container: MarginContainer = MarginContainer.new()
	fold_button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fold_button_container.add_theme_constant_override("margin_left", -TARGET_HEADER_LEFT_OVERHANG)
	fold_button_container.add_child(fold_button)
	header.add_child(fold_button_container)

	var count_badge: PanelContainer = PanelContainer.new()
	count_badge.custom_minimum_size = Vector2(24, 22)
	count_badge.mouse_filter = Control.MOUSE_FILTER_PASS
	count_badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	count_badge.add_theme_stylebox_override(
		"panel",
		_make_panel_style(_editor_color("dark_color_2", Color(0.09, 0.10, 0.12, 1.0)), 4)
	)
	var count_label: Label = Label.new()
	count_label.text = str(target_count)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.mouse_filter = Control.MOUSE_FILTER_PASS
	count_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	count_badge.add_child(count_label)
	header.add_child(count_badge)

	return header


func _on_targets_header_gui_input(
	event: InputEvent,
	header: Control,
	section_content: Control,
	fold_button: Button
) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_toggle_targets_section(section_content, fold_button)
			header.accept_event()


func _toggle_targets_section(section_content: Control, fold_button: Button) -> void:
	_targets_section_collapsed = not _targets_section_collapsed
	section_content.visible = not _targets_section_collapsed
	_update_targets_section_button(fold_button)


func _update_targets_section_button(fold_button: Button) -> void:
	var arrow_name: String = "GuiTreeArrowRight" if _targets_section_collapsed else "GuiTreeArrowDown"
	fold_button.tooltip_text = "Expand targets" if _targets_section_collapsed else "Collapse targets"
	if has_theme_icon(arrow_name, "EditorIcons"):
		fold_button.icon = get_theme_icon(arrow_name, "EditorIcons")
		fold_button.text = "Targets"
	else:
		fold_button.icon = null
		fold_button.text = ("> " if _targets_section_collapsed else "v ") + "Targets"


func _create_empty_state() -> Control:
	var empty_state: Label = Label.new()
	empty_state.text = "Add targets for the camera to follow."
	empty_state.custom_minimum_size = Vector2(0, 40)
	empty_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_state.add_theme_color_override(
		"font_color", _editor_color("font_color", Color(0.72, 0.73, 0.76, 1.0))
	)
	return empty_state


func _create_target_card(index: int, target_data: JuiceCamTargetData) -> Control:
	assert(target_data != null and target_data.is_valid(), "Target cards require an assigned live Node2D.")
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel",
		_make_panel_style(_editor_color("base_color", Color(0.15, 0.16, 0.19, 1.0)), 0)
	)

	var card_content: VBoxContainer = VBoxContainer.new()
	card_content.add_theme_constant_override("separation", 0)
	card.add_child(card_content)

	var target_node: Node2D = target_data.node if target_data != null else null
	var card_id: int = target_data.get_instance_id()
	var body_collapsed: bool = bool(_collapsed_cards.get(card_id, false))
	var header_panel: PanelContainer = PanelContainer.new()
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	header_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	header_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(_editor_color("dark_color_2", Color(0.09, 0.10, 0.12, 1.0)), 6)
	)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	header_panel.add_child(header)

	var fold_button: Button = _create_flat_icon_button(
		"GuiTreeArrowRight" if body_collapsed else "GuiTreeArrowDown",
		"Expand target settings" if body_collapsed else "Collapse target settings"
	)
	fold_button.custom_minimum_size = Vector2(22, 22)
	header.add_child(fold_button)

	var target_icon: TextureRect = _create_target_icon(target_node)
	target_icon.mouse_filter = Control.MOUSE_FILTER_PASS
	target_icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	header.add_child(target_icon)

	var target_name: Label = Label.new()
	target_name.text = target_node.name
	target_name.tooltip_text = str(target_node.get_path())
	target_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	target_name.mouse_filter = Control.MOUSE_FILTER_PASS
	target_name.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	header.add_child(target_name)

	var choose_button: Button = _create_flat_icon_button("Edit", "Choose a Node2D from the scene tree")
	choose_button.pressed.connect(_open_node_picker.bind(index))
	header.add_child(choose_button)

	var remove_button: Button = _create_flat_icon_button("Remove", "Remove this target")
	remove_button.pressed.connect(_remove_target.bind(index))
	header.add_child(remove_button)

	card_content.add_child(header_panel)

	var body_panel: PanelContainer = PanelContainer.new()
	body_panel.visible = not body_collapsed
	body_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(_editor_color("base_color", Color(0.15, 0.16, 0.19, 1.0)).lightened(0.04), 8)
	)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	body_panel.add_child(body)
	body.add_child(_create_slider_row(index, "weight", "Weight", target_data.weight, 0.0, 10.0, 0.1))
	body.add_child(_create_slider_row(index, "radius", "Radius (px)", target_data.radius, 0.0, 2000.0, 1.0))
	body.add_child(_create_offset_row(index, target_data.offset))

	var lookahead_row: HBoxContainer = HBoxContainer.new()
	lookahead_row.add_theme_constant_override("separation", 8)
	var lookahead_label: Label = Label.new()
	lookahead_label.text = "Lookahead"
	lookahead_label.custom_minimum_size.x = 92
	lookahead_row.add_child(lookahead_label)
	var lookahead_check: CheckBox = CheckBox.new()
	lookahead_check.button_pressed = target_data.use_lookahead
	lookahead_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lookahead_row.add_child(lookahead_check)
	body.add_child(lookahead_row)

	var lookahead_factor: Control = _create_slider_row(
		index,
		"lookahead_factor",
		"Lookahead Factor",
		target_data.lookahead_factor,
		0.0,
		5.0,
		0.1
	)
	lookahead_factor.visible = target_data.use_lookahead
	body.add_child(lookahead_factor)
	lookahead_check.toggled.connect(
		func(enabled: bool) -> void:
			_set_target_property(index, "use_lookahead", enabled)
			lookahead_factor.visible = enabled
	)

	card_content.add_child(body_panel)
	header_panel.gui_input.connect(
		_on_target_card_header_gui_input.bind(header_panel, card_id, body_panel, fold_button)
	)
	fold_button.pressed.connect(_toggle_target_card.bind(card_id, body_panel, fold_button))
	return card


func _on_target_card_header_gui_input(
	event: InputEvent,
	header_panel: Control,
	card_id: int,
	body_panel: Control,
	fold_button: Button
) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_toggle_target_card(card_id, body_panel, fold_button)
			header_panel.accept_event()


func _toggle_target_card(card_id: int, body_panel: Control, fold_button: Button) -> void:
	body_panel.visible = not body_panel.visible
	_collapsed_cards[card_id] = not body_panel.visible
	var arrow_name: String = "GuiTreeArrowDown" if body_panel.visible else "GuiTreeArrowRight"
	if has_theme_icon(arrow_name, "EditorIcons"):
		fold_button.icon = get_theme_icon(arrow_name, "EditorIcons")
		fold_button.text = ""
	else:
		fold_button.icon = null
		fold_button.text = "v" if body_panel.visible else ">"
	fold_button.tooltip_text = "Collapse target settings" if body_panel.visible else "Expand target settings"


func _create_target_icon(target_node: Node2D) -> TextureRect:
	var target_icon: TextureRect = TextureRect.new()
	target_icon.custom_minimum_size = Vector2(16, 16)
	target_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	target_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not is_instance_valid(target_node):
		target_icon.visible = false
		return target_icon

	var editor_control: Control = EditorInterface.get_base_control()
	var icon_name: StringName = StringName(target_node.get_class())
	if editor_control.has_theme_icon(icon_name, &"EditorIcons"):
		target_icon.texture = editor_control.get_theme_icon(icon_name, &"EditorIcons")
	else:
		target_icon.visible = false
	return target_icon


func _create_slider_row(
	index: int,
	field: String,
	label_text: String,
	value: float,
	minimum: float,
	maximum: float,
	step: float
) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 92
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var slider: HSlider = HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var value_box: SpinBox = SpinBox.new()
	value_box.min_value = minimum
	value_box.max_value = maximum
	value_box.step = step
	value_box.value = value
	value_box.custom_minimum_size.x = 64
	value_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value_box)

	var synchronizing: Array[bool] = [false]
	slider.value_changed.connect(
		func(new_value: float) -> void:
			if synchronizing[0]:
				return
			synchronizing[0] = true
			value_box.value = new_value
			synchronizing[0] = false
			_set_target_property(index, field, new_value)
	)
	value_box.value_changed.connect(
		func(new_value: float) -> void:
			if synchronizing[0]:
				return
			synchronizing[0] = true
			slider.value = new_value
			synchronizing[0] = false
			_set_target_property(index, field, new_value)
	)
	return row


func _create_offset_row(index: int, value: Vector2) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	var label: Label = Label.new()
	label.text = "Offset"
	label.tooltip_text = "Target-local offset. It rotates with the target."
	label.custom_minimum_size.x = 92
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var x_box: SpinBox = _create_offset_spin_box(value.x)
	x_box.prefix = "X "
	var y_box: SpinBox = _create_offset_spin_box(value.y)
	y_box.prefix = "Y "
	row.add_child(x_box)
	row.add_child(y_box)
	x_box.value_changed.connect(
		func(_new_x: float) -> void:
			_set_target_property(index, "offset", Vector2(x_box.value, y_box.value))
	)
	y_box.value_changed.connect(
		func(_new_y: float) -> void:
			_set_target_property(index, "offset", Vector2(x_box.value, y_box.value))
	)
	return row


func _create_offset_spin_box(value: float) -> SpinBox:
	var spin_box: SpinBox = SpinBox.new()
	spin_box.min_value = -10000.0
	spin_box.max_value = 10000.0
	spin_box.step = 0.1
	spin_box.value = value
	spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return spin_box


func _open_node_picker(target_index: int) -> void:
	if not is_instance_valid(_camera) or EditorInterface.get_edited_scene_root() == null:
		return

	var current_value: Node = null
	if target_index >= 0:
		var targets: Array[JuiceCamTargetData] = _camera.get_all_targets()
		if target_index < targets.size():
			current_value = targets[target_index].node

	var valid_types: Array[StringName] = [&"Node2D"]
	EditorInterface.popup_node_selector(
		Callable(self, "_on_target_node_selected").bind(target_index),
		valid_types,
		current_value
	)


func _on_target_node_selected(node_path: NodePath, target_index: int) -> void:
	if node_path.is_empty() or not is_instance_valid(_camera):
		return
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return
	var selected_node: Node2D = scene_root.get_node_or_null(node_path) as Node2D
	if not is_instance_valid(selected_node):
		return

	if target_index < 0:
		if _camera.has_target(selected_node):
			return
		var targets: Array[JuiceCamTargetData] = _camera.get_all_targets()
		_add_target_with_undo(targets.size(), selected_node)
		return

	var current_targets: Array[JuiceCamTargetData] = _camera.get_all_targets()
	if target_index >= current_targets.size() or current_targets[target_index].node == selected_node:
		return
	if _camera.has_target(selected_node):
		return
	_set_node_with_undo(target_index, current_targets[target_index].node, selected_node)


func _add_target_with_undo(index: int, target_node: Node2D) -> void:
	if _undo_redo == null:
		_mark_scene_dirty()
		_camera.add_target(target_node)
		return

	_undo_redo.create_action("Add JuiceCam Target", UndoRedo.MERGE_DISABLE, _camera)
	_undo_redo.add_do_method(_camera, &"add_target", target_node)
	_undo_redo.add_undo_method(_camera, &"_editor_remove_target_at", index)
	_undo_redo.commit_action()


func _set_node_with_undo(index: int, old_node: Node2D, new_node: Node2D) -> void:
	if _undo_redo == null:
		_mark_scene_dirty()
		_camera.set_target_node(index, new_node)
		return

	_undo_redo.create_action("Change JuiceCam Target", UndoRedo.MERGE_DISABLE, _camera)
	_undo_redo.add_do_method(_camera, &"set_target_node", index, new_node)
	_undo_redo.add_undo_method(_camera, &"set_target_node", index, old_node)
	_undo_redo.commit_action()


func _remove_target(index: int) -> void:
	if not is_instance_valid(_camera):
		return
	var targets: Array[JuiceCamTargetData] = _camera.get_all_targets()
	if index < 0 or index >= targets.size():
		return
	var original: JuiceCamTargetData = targets[index]
	var snapshot: JuiceCamTargetData = JuiceCamTargetDataScript.new(
		original.node,
		original.weight,
		original.radius,
		original.offset,
		original.use_lookahead,
		original.lookahead_factor
	) as JuiceCamTargetData
	if _undo_redo == null:
		_mark_scene_dirty()
		_camera.remove_target_at(index)
		return

	_undo_redo.create_action("Remove JuiceCam Target", UndoRedo.MERGE_DISABLE, _camera)
	_undo_redo.add_do_method(_camera, &"remove_target_at", index)
	_undo_redo.add_undo_method(_camera, &"restore_target_at", index, snapshot)
	_undo_redo.add_undo_reference(snapshot)
	_undo_redo.commit_action()


func _set_target_property(index: int, field: String, value: Variant) -> void:
	if not is_instance_valid(_camera):
		return
	var property_name: StringName = StringName("target_%d_%s" % [index, field])
	var previous_value: Variant = _camera.get(property_name)
	if previous_value == value:
		return
	if _undo_redo == null:
		_mark_scene_dirty()
		_camera.set(property_name, value)
		return

	_undo_redo.create_action(
		"Change JuiceCam Target %s" % field.replace("_", " ").capitalize(),
		UndoRedo.MERGE_ENDS,
		_camera
	)
	_undo_redo.add_do_property(_camera, property_name, value)
	_undo_redo.add_undo_property(_camera, property_name, previous_value)
	_undo_redo.commit_action()


func _mark_scene_dirty() -> void:
	if not is_instance_valid(_camera):
		return
	var edited_root: Node = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(edited_root):
		return
	if _camera != edited_root and not edited_root.is_ancestor_of(_camera):
		return
	EditorInterface.mark_scene_as_unsaved()


func _on_undo_redo_version_changed() -> void:
	if is_inside_tree() and is_instance_valid(_camera):
		call_deferred("_build_ui")


func _create_flat_icon_button(icon_name: String, tooltip: String) -> Button:
	var button: Button = Button.new()
	button.flat = true
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_constant_override("icon_max_width", 16)
	button.custom_minimum_size = Vector2(24, 24)
	if has_theme_icon(icon_name, "EditorIcons"):
		button.icon = get_theme_icon(icon_name, "EditorIcons")
	else:
		match icon_name:
			"GuiTreeArrowDown":
				button.text = "v"
			"GuiTreeArrowRight":
				button.text = ">"
			"Edit":
				button.text = "✎"
			"Remove":
				button.text = "×"
	_apply_flat_styles(button)
	return button


func _create_accent_button(label: String, icon_name: String) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 32)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	if has_theme_icon(icon_name, "EditorIcons"):
		button.icon = get_theme_icon(icon_name, "EditorIcons")
	var accent: Color = _editor_color("accent_color", Color(0.18, 0.32, 0.52, 1.0))
	button.add_theme_stylebox_override("normal", _make_panel_style(accent, 8))
	button.add_theme_stylebox_override("hover", _make_panel_style(accent.lightened(0.12), 8))
	button.add_theme_stylebox_override("pressed", _make_panel_style(accent.darkened(0.08), 8))
	return button


func _apply_flat_styles(button: Button, remove_content_margin: bool = false) -> void:
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	if remove_content_margin:
		empty.set_content_margin_all(0.0)
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)


func _make_panel_style(color: Color, margin: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(margin)
	return style


func _editor_color(color_name: String, fallback: Color) -> Color:
	if has_theme_color(color_name, "Editor"):
		return get_theme_color(color_name, "Editor")
	return fallback
