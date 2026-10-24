extends Node

## Plays the demo's shared click sound for every button in the tutorial HUD.
## Tracking SceneTree.node_added also covers controls created as the player
## enters feature areas.

@onready var _hud: CanvasLayer = get_node("../HUD") as CanvasLayer
@onready var _click_player: AudioStreamPlayer = $ClickPlayer


func _ready() -> void:
	var scene_tree: SceneTree = get_tree()
	if not scene_tree.node_added.is_connected(_on_node_added):
		scene_tree.node_added.connect(_on_node_added)
	_connect_buttons_in(_hud)


func _exit_tree() -> void:
	var scene_tree: SceneTree = get_tree()
	if scene_tree.node_added.is_connected(_on_node_added):
		scene_tree.node_added.disconnect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and _hud.is_ancestor_of(node):
		_connect_button(node as BaseButton)


func _connect_buttons_in(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node as BaseButton)
	for child: Node in node.get_children():
		_connect_buttons_in(child)


func _connect_button(button: BaseButton) -> void:
	if not button.pressed.is_connected(_play_click):
		button.pressed.connect(_play_click)


func _play_click() -> void:
	_click_player.play()
