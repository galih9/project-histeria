class_name WorldMap
extends Node2D
## One section of the top-down world (GDD 01: each section is one scene).
## Sets the camera limits, builds invisible edge walls and knows the spawn point.

const EDGE_THICKNESS := 16.0

@export var bounds := Rect2i(0, 0, 640, 480)

@onready var player: Player = %Player
@onready var _spawn: Marker2D = %Spawn


func _ready() -> void:
	player.global_position = _spawn.global_position
	player.set_camera_limits(bounds)
	_build_edges()


func respawn_player() -> void:
	player.global_position = _spawn.global_position
	player.facing = Vector2.DOWN
	player.set_camera_limits(bounds)


func _build_edges() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Edges"
	add_child(walls)
	var r := Rect2(bounds)
	var t := EDGE_THICKNESS
	for edge: Rect2 in [
		Rect2(r.position.x - t, r.position.y - t, r.size.x + t * 2, t),
		Rect2(r.position.x - t, r.end.y, r.size.x + t * 2, t),
		Rect2(r.position.x - t, r.position.y, t, r.size.y),
		Rect2(r.end.x, r.position.y, t, r.size.y),
	]:
		var shape := RectangleShape2D.new()
		shape.size = edge.size
		var node := CollisionShape2D.new()
		node.shape = shape
		node.position = edge.get_center()
		walls.add_child(node)
