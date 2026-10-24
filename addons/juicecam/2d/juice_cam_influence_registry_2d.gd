@tool
class_name JuiceCamInfluenceRegistry2D
extends RefCounted

## Shared registry for world-space 2D camera influences in one SceneTree.
## Spatial regions use a grid; global path constraints use a per-tree path list.
## All camera queries are filtered to World2D for isolated SubViewport worlds.

const GROUP_NAME: StringName = &"juice_cam_influences_2d"
const PATH_GROUP_NAME: StringName = &"juice_cam_paths_2d"
const TREE_META_KEY: StringName = &"_juice_cam_influence_registry_2d"
const CELL_SIZE: float = 512.0
const COARSE_CELL_SIZE: float = 8192.0
const MAX_CELLS_PER_NODE: int = 256

# Godot doesn't support typed collections nested inside another typed collection.
# Keep these outer maps untyped and type each array at its use site.
var _cells: Dictionary = {}
var _coarse_cells: Dictionary = {}
var _node_cells: Dictionary = {}
var _node_coarse_cells: Dictionary = {}
var _node_bounds: Dictionary[int, Rect2] = {}
var _query_ids: Dictionary[int, bool] = {}
var _nodes: Array[Node2D] = []
var _path_nodes: Array[Node2D] = []
var _overflow_nodes: Array[Node2D] = []
var _debug_cameras: Dictionary[int, Node2D] = {}


static func get_for_tree(scene_tree: SceneTree) -> JuiceCamInfluenceRegistry2D:
	if scene_tree.has_meta(TREE_META_KEY):
		var existing: JuiceCamInfluenceRegistry2D = scene_tree.get_meta(TREE_META_KEY) as JuiceCamInfluenceRegistry2D
		if existing != null:
			return existing

	var registry: JuiceCamInfluenceRegistry2D = JuiceCamInfluenceRegistry2D.new()
	scene_tree.set_meta(TREE_META_KEY, registry)
	registry._initialize(scene_tree)
	return registry


static func get_existing(scene_tree: SceneTree) -> JuiceCamInfluenceRegistry2D:
	if not scene_tree.has_meta(TREE_META_KEY):
		return null
	return scene_tree.get_meta(TREE_META_KEY) as JuiceCamInfluenceRegistry2D


func _initialize(scene_tree: SceneTree) -> void:
	for node: Node in scene_tree.get_nodes_in_group(GROUP_NAME):
		register_node(node as Node2D)


func register_node(node: Node2D) -> void:
	if not is_instance_valid(node) or not node.is_in_group(GROUP_NAME):
		return
	if _node_cells.has(node.get_instance_id()):
		return
	_nodes.append(node)
	if node.is_in_group(PATH_GROUP_NAME):
		_path_nodes.append(node)
	_index_node(node)
	for camera: Node2D in _debug_cameras.values():
		if is_instance_valid(camera) and _nodes_share_world(node, camera):
			node.call("set_camera_debug", camera, true)


func unregister_node(node: Node2D) -> void:
	if not is_instance_valid(node):
		return
	var instance_id: int = node.get_instance_id()
	if not _node_cells.has(instance_id):
		return
	_remove_from_index(node)
	_nodes.erase(node)
	_path_nodes.erase(node)
	_node_cells.erase(instance_id)


func update_node(node: Node2D) -> void:
	if not is_instance_valid(node) or not _node_cells.has(node.get_instance_id()):
		return
	_remove_from_index(node)
	_index_node(node)
	for camera: Node2D in _debug_cameras.values():
		if not is_instance_valid(camera):
			continue
		if _nodes_share_world(node, camera):
			node.call("set_camera_debug", camera, true)
		else:
			node.call("forget_camera", camera)


## Fills `result` with indexed regions that overlap the search bounds.
func query_aabb(world: World2D, search_bounds: Rect2, result: Array[Node2D]) -> void:
	result.clear()
	_query_ids.clear()
	var start: Vector2i = _get_cell(search_bounds.position)
	var end: Vector2i = _get_cell(search_bounds.end)
	_append_cells_in_range(start, end, _cells, world, search_bounds, result)
	var coarse_start: Vector2i = _get_cell(search_bounds.position, COARSE_CELL_SIZE)
	var coarse_end: Vector2i = _get_cell(search_bounds.end, COARSE_CELL_SIZE)
	_append_cells_in_range(coarse_start, coarse_end, _coarse_cells, world, search_bounds, result)
	for node: Node2D in _overflow_nodes:
		_append_candidate_if_overlapping(node, world, search_bounds, result)


## Fills `result` with every registered path in this World2D.
## Paths are global constraints, so camera selection must not depend on proximity.
func query_paths(world: World2D, result: Array[Node2D]) -> void:
	result.clear()
	if world == null:
		return
	for path: Node2D in _path_nodes:
		if (
			not is_instance_valid(path)
			or not path.is_inside_tree()
			or path.is_queued_for_deletion()
		):
			continue
		if _nodes_share_world_with_world(path, world):
			result.append(path)


func _append_cells_in_range(
	start: Vector2i,
	end: Vector2i,
	cells: Dictionary,
	world: World2D,
	search_bounds: Rect2,
	result: Array[Node2D]
) -> void:
	for x: int in range(start.x, end.x + 1):
		for y: int in range(start.y, end.y + 1):
			var cell: Vector2i = Vector2i(x, y)
			if not cells.has(cell):
				continue
			var bucket: Array[Node2D] = cells[cell]
			for node: Node2D in bucket:
				_append_candidate_if_overlapping(node, world, search_bounds, result)


func set_camera_debug(camera: Node2D, draw_enabled: bool) -> void:
	if not is_instance_valid(camera):
		return
	var instance_id: int = camera.get_instance_id()
	if draw_enabled:
		_debug_cameras[instance_id] = camera
	else:
		_debug_cameras.erase(instance_id)
	for node: Node2D in _nodes:
		if is_instance_valid(node) and (not draw_enabled or _nodes_share_world(node, camera)):
			node.call("set_camera_debug", camera, draw_enabled)


func forget_camera(camera: Node2D) -> void:
	if not is_instance_valid(camera):
		return
	_debug_cameras.erase(camera.get_instance_id())
	for node: Node2D in _nodes:
		if is_instance_valid(node):
			node.call("forget_camera", camera)


func _index_node(node: Node2D) -> void:
	var instance_id: int = node.get_instance_id()
	if node.is_in_group(PATH_GROUP_NAME):
		# Paths are selected globally by priority instead of through spatial overlap.
		var empty_path_cells: Array[Vector2i] = []
		var empty_path_coarse_cells: Array[Vector2i] = []
		_node_cells[instance_id] = empty_path_cells
		_node_coarse_cells[instance_id] = empty_path_coarse_cells
		return
	var bounds: Rect2 = node.call("get_influence_world_aabb")
	_node_bounds[instance_id] = bounds
	var start: Vector2i = _get_cell(bounds.position)
	var end: Vector2i = _get_cell(bounds.end)
	var cell_width: int = end.x - start.x + 1
	var cell_height: int = end.y - start.y + 1
	var occupied_cells: Array[Vector2i] = []
	if not _exceeds_cell_budget(cell_width, cell_height):
		_index_in_grid(node, start, end, _cells, occupied_cells)
		_node_cells[instance_id] = occupied_cells
		_node_coarse_cells[instance_id] = []
		return

	var coarse_start: Vector2i = _get_cell(bounds.position, COARSE_CELL_SIZE)
	var coarse_end: Vector2i = _get_cell(bounds.end, COARSE_CELL_SIZE)
	var coarse_width: int = coarse_end.x - coarse_start.x + 1
	var coarse_height: int = coarse_end.y - coarse_start.y + 1
	var occupied_coarse_cells: Array[Vector2i] = []
	if _exceeds_cell_budget(coarse_width, coarse_height):
		_overflow_nodes.append(node)
		_node_cells[instance_id] = occupied_cells
		_node_coarse_cells[instance_id] = occupied_coarse_cells
		return
	_index_in_grid(node, coarse_start, coarse_end, _coarse_cells, occupied_coarse_cells)
	_node_cells[instance_id] = occupied_cells
	_node_coarse_cells[instance_id] = occupied_coarse_cells


func _exceeds_cell_budget(width: int, height: int) -> bool:
	return (
		width > MAX_CELLS_PER_NODE
		or height > MAX_CELLS_PER_NODE
		or width * height > MAX_CELLS_PER_NODE
	)


func _index_in_grid(
	node: Node2D,
	start: Vector2i,
	end: Vector2i,
	cells: Dictionary,
	occupied_cells: Array[Vector2i]
) -> void:
	for x: int in range(start.x, end.x + 1):
		for y: int in range(start.y, end.y + 1):
			var cell: Vector2i = Vector2i(x, y)
			var bucket: Array[Node2D] = []
			if cells.has(cell):
				bucket = cells[cell]
			else:
				cells[cell] = bucket
			bucket.append(node)
			occupied_cells.append(cell)


func _remove_from_index(node: Node2D) -> void:
	var instance_id: int = node.get_instance_id()
	if not _node_cells.has(instance_id):
		return
	var occupied_cells: Array[Vector2i] = _node_cells[instance_id]
	for cell: Vector2i in occupied_cells:
		if not _cells.has(cell):
			continue
		var bucket: Array[Node2D] = _cells[cell]
		bucket.erase(node)
		if bucket.is_empty():
			_cells.erase(cell)
	# Dictionary.get() returns an untyped Array even when the stored value is typed.
	var occupied_coarse_cells: Array = _node_coarse_cells.get(instance_id, [])
	for cell: Vector2i in occupied_coarse_cells:
		if not _coarse_cells.has(cell):
			continue
		var coarse_bucket: Array[Node2D] = _coarse_cells[cell]
		coarse_bucket.erase(node)
		if coarse_bucket.is_empty():
			_coarse_cells.erase(cell)
	_overflow_nodes.erase(node)
	_node_bounds.erase(instance_id)
	_node_cells.erase(instance_id)
	_node_coarse_cells.erase(instance_id)


func _append_candidate_if_overlapping(
	node: Node2D,
	world: World2D,
	search_bounds: Rect2,
	result: Array[Node2D]
) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion():
		return
	if world == null or not _nodes_share_world_with_world(node, world):
		return
	var instance_id: int = node.get_instance_id()
	if _query_ids.has(instance_id) or not _node_bounds.has(instance_id):
		return
	var node_bounds: Rect2 = _node_bounds[instance_id]
	if not node_bounds.intersects(search_bounds, true):
		return
	_query_ids[instance_id] = true
	result.append(node)


func _nodes_share_world(a: Node2D, b: Node2D) -> bool:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return false
	if not a.is_inside_tree() or not b.is_inside_tree():
		return false
	return _nodes_share_world_with_world(a, b.get_viewport().world_2d)


func _nodes_share_world_with_world(node: Node2D, world: World2D) -> bool:
	return (
		is_instance_valid(node)
		and node.is_inside_tree()
		and world != null
		and node.get_viewport().world_2d == world
	)


func _get_cell(position: Vector2, cell_size: float = CELL_SIZE) -> Vector2i:
	return Vector2i(floori(position.x / cell_size), floori(position.y / cell_size))
