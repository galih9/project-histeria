@tool
class_name CloudShadows
extends Node2D
## Cloud shadows drifting over one map section. Add it to a map scene below
## (after) the Entities node so it shades the ground, props and characters.
## It draws one rect over `area` with world/weather/cloud_shadows_material.tres;
## the Wind node moves the clouds downwind. Look settings (color, size,
## coverage, edge dither) live on that material.

const CLOUD_MATERIAL := preload("res://world/weather/cloud_shadows_material.tres")

## The map area to shade, in px. Match the map's bounds.
@export var area := Rect2i(0, 0, 640, 480):
	set(value):
		area = value
		queue_redraw()
## Extra px past the edges, so camera shake or overscan stays covered.
@export var margin := 32:
	set(value):
		margin = value
		queue_redraw()
## Show the (frozen) shadows while editing the map.
@export var show_in_editor := true:
	set(value):
		show_in_editor = value
		queue_redraw()


func _ready() -> void:
	if material == null:
		material = CLOUD_MATERIAL
	# Above everything in the map section; UI lives on its own CanvasLayer.
	z_index = 50


func _draw() -> void:
	if Engine.is_editor_hint() and not show_in_editor:
		return
	draw_rect(Rect2(area).grow(margin), Color.WHITE)
