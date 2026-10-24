@tool
class_name JuiceCamTargetSet2D
extends RefCounted

## Owns target state, weighted tracking, and its scene-serialized inspector properties.

const TargetDataScript: GDScript = preload("res://addons/juicecam/2d/juice_cam_target_data_2d.gd")

enum PropertyWriteResult {
	UNHANDLED,
	HANDLED,
	SCHEMA_CHANGED,
}

var _entries: Array[JuiceCamTargetData] = []
var _serialized_entries: Array[JuiceCamTargetData] = []
var _is_loading_serialized_entries: bool = false


func get_size() -> int:
	_finalize_serialized_entries()
	return _entries.size()


## Reconstructs dynamic serialized fields while a scene is loading.
## get_all_targets() removes any entries whose serialized node reference is missing.
func _resize_serialized_entries(count: int) -> bool:
	var normalized_count: int = maxi(0, count)
	if _is_loading_serialized_entries and normalized_count == _serialized_entries.size():
		return false

	_is_loading_serialized_entries = true
	_serialized_entries.clear()
	while _serialized_entries.size() < normalized_count:
		_serialized_entries.append(_new_target())
	return true


func _finalize_serialized_entries() -> bool:
	if not _is_loading_serialized_entries:
		return false
	var serialized_count: int = _serialized_entries.size()
	for target_data: JuiceCamTargetData in _serialized_entries:
		if target_data == null or not target_data.is_valid():
			continue
		var duplicate_node: bool = false
		for existing: JuiceCamTargetData in _entries:
			if existing != null and existing.node == target_data.node:
				duplicate_node = true
				break
		if not duplicate_node:
			_entries.append(target_data)
	_serialized_entries.clear()
	_is_loading_serialized_entries = false
	return _entries.size() != serialized_count


func remove_at(index: int) -> bool:
	_finalize_serialized_entries()
	if index < 0 or index >= _entries.size():
		return false
	_entries.remove_at(index)
	return true


func restore_at(index: int, target_data: JuiceCamTargetData) -> bool:
	_finalize_serialized_entries()
	if index < 0 or target_data == null or not target_data.is_valid():
		return false
	if index > _entries.size() or has_target(target_data.node):
		return false
	_entries.insert(index, target_data)
	return true


func set_primary_target(node: Node2D) -> void:
	_finalize_serialized_entries()
	if not _is_valid_target_node(node):
		return
	if _entries.is_empty():
		_entries.append(_new_target(node))
		return
	set_node_at(0, node)


func set_node_at(index: int, node: Node2D) -> bool:
	_finalize_serialized_entries()
	if index < 0 or index >= _entries.size() or not _is_valid_target_node(node):
		return false
	if _entries[index] == null:
		_entries[index] = _new_target()
	if _entries[index].node == node:
		return false
	for other_index: int in range(_entries.size()):
		if other_index != index and _entries[other_index] != null and _entries[other_index].node == node:
			return false
	_entries[index].node = node
	return true


func get_primary_target() -> Node2D:
	_finalize_serialized_entries()
	for target_data: JuiceCamTargetData in _entries:
		if target_data != null and target_data.is_valid():
			return target_data.node
	return null


func get_primary_influential_target() -> Node2D:
	_finalize_serialized_entries()
	for target_data: JuiceCamTargetData in _entries:
		if target_data != null and target_data.is_valid() and target_data.weight > 0.0001:
			return target_data.node
	return null


func add_target(
	node: Node2D,
	weight: float = 1.0,
	radius: float = 32.0,
	offset: Vector2 = Vector2.ZERO,
	use_lookahead: bool = true,
	lookahead_factor: float = 0.0
) -> JuiceCamTargetData:
	_finalize_serialized_entries()
	if not _is_valid_target_node(node):
		return null
	for existing: JuiceCamTargetData in _entries:
		if existing != null and existing.node == node:
			return existing

	var target_data: JuiceCamTargetData = TargetDataScript.new(
		node,
		weight,
		radius,
		offset,
		use_lookahead,
		lookahead_factor
	) as JuiceCamTargetData
	_entries.append(target_data)
	return target_data


func remove_target(node: Node2D) -> void:
	_finalize_serialized_entries()
	if not is_instance_valid(node):
		return

	for index: int in range(_entries.size() - 1, -1, -1):
		var target_data: JuiceCamTargetData = _entries[index]
		if target_data != null and target_data.node == node:
			_entries.remove_at(index)


func has_target(node: Node2D) -> bool:
	_finalize_serialized_entries()
	if not _is_valid_target_node(node):
		return false
	for target_data: JuiceCamTargetData in _entries:
		if target_data != null and target_data.node == node:
			return true
	return false


func clear() -> void:
	_finalize_serialized_entries()
	_entries.clear()


func get_all_targets() -> Array[JuiceCamTargetData]:
	_finalize_serialized_entries()
	for index: int in range(_entries.size() - 1, -1, -1):
		var target_data: JuiceCamTargetData = _entries[index]
		if target_data == null or not target_data.is_valid():
			_entries.remove_at(index)
	return _entries.duplicate()


func has_influential_targets() -> bool:
	_finalize_serialized_entries()
	for target_data: JuiceCamTargetData in _entries:
		if target_data != null and target_data.is_valid() and target_data.weight > 0.0001:
			return true
	return false


func get_influential_target_count() -> int:
	_finalize_serialized_entries()
	var count: int = 0
	for target_data: JuiceCamTargetData in _entries:
		if target_data != null and target_data.is_valid() and target_data.weight > 0.0001:
			count += 1
	return count


func calculate_weighted_centroid(fallback_position: Vector2) -> Vector2:
	_finalize_serialized_entries()
	var weighted_sum: Vector2 = Vector2.ZERO
	var total_weight: float = 0.0

	for target_data: JuiceCamTargetData in _entries:
		if target_data == null or not target_data.is_valid():
			continue
		var weight: float = maxf(0.0, target_data.weight)
		if weight > 0.0001:
			weighted_sum += target_data.get_world_position() * weight
			total_weight += weight

	if total_weight > 0.0001:
		return weighted_sum / total_weight
	return fallback_position


## Updates target velocity samples and returns their weighted mean world-space speed.
func update_tracking_data(delta: float, lookahead_damping_rate: float) -> float:
	_finalize_serialized_entries()
	var weighted_speed: float = 0.0
	var total_weight: float = 0.0

	for target_data: JuiceCamTargetData in _entries:
		if target_data == null:
			continue
		target_data.update_tracking_position(delta, lookahead_damping_rate)
		if not target_data.is_valid():
			continue
		var weight: float = maxf(0.0, target_data.weight)
		if weight <= 0.0001:
			continue
		weighted_speed += target_data.get_world_speed() * weight
		total_weight += weight

	return weighted_speed / total_weight if total_weight > 0.0001 else 0.0


func get_dynamic_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		"name": "target_count",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_STORAGE,
	})
	var serialized_count: int = _get_serialized_entry_count()
	for index: int in range(serialized_count):
		var prefix: String = "target_%d_" % index
		properties.append({
			"name": prefix + "node",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_NODE_TYPE,
			"hint_string": "Node2D",
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		properties.append({
			"name": prefix + "weight",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,10.0,0.1",
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		properties.append({
			"name": prefix + "radius",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,2000.0,1.0,suffix:px",
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		properties.append({
			"name": prefix + "offset",
			"type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		properties.append({
			"name": prefix + "use_lookahead",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		properties.append({
			"name": prefix + "lookahead_factor",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,5.0,0.1",
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	return properties


func get_dynamic_property(property: StringName) -> Variant:
	if property == &"target_count":
		return _get_serialized_entry_count()

	var parsed_property: Dictionary = _parse_target_property(property)
	if parsed_property.is_empty():
		return null

	var index: int = parsed_property["index"]
	if index < 0 or index >= _get_serialized_entry_count():
		return null
	var target_data: JuiceCamTargetData = _get_serialized_entry(index)
	if target_data == null:
		return null

	match String(parsed_property["field"]):
		"node":
			return target_data.node
		"weight":
			return target_data.weight
		"radius":
			return target_data.radius
		"offset":
			return target_data.offset
		"use_lookahead":
			return target_data.use_lookahead
		"lookahead_factor":
			return target_data.lookahead_factor
	return null


func set_dynamic_property(property: StringName, value: Variant) -> PropertyWriteResult:
	if property == &"target_count":
		var requested_count: int = 0 if value == null else maxi(0, int(value))
		return PropertyWriteResult.SCHEMA_CHANGED if _resize_serialized_entries(requested_count) else PropertyWriteResult.HANDLED

	var parsed_property: Dictionary = _parse_target_property(property)
	if parsed_property.is_empty():
		return PropertyWriteResult.UNHANDLED

	var index: int = parsed_property["index"]
	if index < 0:
		return PropertyWriteResult.UNHANDLED
	var schema_changed: bool = index >= _get_serialized_entry_count()
	var target_data: JuiceCamTargetData = _ensure_serialized_entry(index)
	if target_data == null:
		return PropertyWriteResult.UNHANDLED
	match String(parsed_property["field"]):
		"node":
			var target_node: Node2D = value as Node2D
			if not _is_valid_target_node(target_node):
				return PropertyWriteResult.HANDLED
			for other_index: int in range(_entries.size()):
				if other_index != index and _entries[other_index] != null and _entries[other_index].node == target_node:
					return PropertyWriteResult.HANDLED
			if target_data.node == target_node:
				return PropertyWriteResult.HANDLED
			target_data.node = target_node
			return PropertyWriteResult.SCHEMA_CHANGED
		"weight":
			target_data.weight = maxf(0.0, 0.0 if value == null else float(value))
		"radius":
			target_data.radius = maxf(0.0, 0.0 if value == null else float(value))
		"offset":
			target_data.offset = (value as Vector2) if value is Vector2 else Vector2.ZERO
		"use_lookahead":
			target_data.use_lookahead = false if value == null else bool(value)
		"lookahead_factor":
			target_data.lookahead_factor = maxf(0.0, 0.0 if value == null else float(value))
	return PropertyWriteResult.SCHEMA_CHANGED if schema_changed else PropertyWriteResult.HANDLED


func _parse_target_property(property: StringName) -> Dictionary:
	var property_text: String = String(property)
	if not property_text.begins_with("target_"):
		return {}

	var remainder: String = property_text.trim_prefix("target_")
	var separator_index: int = remainder.find("_")
	if separator_index <= 0:
		return {}

	var index_text: String = remainder.substr(0, separator_index)
	if not index_text.is_valid_int():
		return {}
	var field: String = remainder.substr(separator_index + 1)
	if field not in ["node", "weight", "radius", "offset", "use_lookahead", "lookahead_factor"]:
		return {}
	return {"index": index_text.to_int(), "field": field}


func _ensure_serialized_entry(index: int) -> JuiceCamTargetData:
	if _is_loading_serialized_entries:
		while _serialized_entries.size() <= index:
			_serialized_entries.append(_new_target())
		if _serialized_entries[index] == null:
			_serialized_entries[index] = _new_target()
		return _serialized_entries[index]
	if index < 0 or index >= _entries.size():
		return null
	return _entries[index]


func _get_serialized_entry_count() -> int:
	return _serialized_entries.size() if _is_loading_serialized_entries else _entries.size()


func _get_serialized_entry(index: int) -> JuiceCamTargetData:
	if index < 0 or index >= _get_serialized_entry_count():
		return null
	return _serialized_entries[index] if _is_loading_serialized_entries else _entries[index]


func _new_target(node: Node2D = null) -> JuiceCamTargetData:
	return TargetDataScript.new(node) as JuiceCamTargetData


func _is_valid_target_node(node: Node2D) -> bool:
	return is_instance_valid(node) and not node.is_queued_for_deletion()
