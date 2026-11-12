@tool
class_name Ground
extends Node2D
## Placeholder floor painted in 32x32 blocks (4x4 tiles of 8x8), the
## EarthBound map unit. Replace with a TileMapLayer when the tileset arrives.

const BLOCK := 32

@export var size := Vector2i(640, 480):
	set(value):
		size = value
		queue_redraw()
@export var grass := Color("4f8a4b")
@export var grass_alt := Color("4a8246")
@export var sand := Color("d9c58f")
## Rectangles (in pixels) painted as sandy paths.
@export var paths: Array[Rect2i] = []
@export var flower_seed := 7


func _draw() -> void:
	for by in range(0, size.y, BLOCK):
		for bx in range(0, size.x, BLOCK):
			var tint := grass if (bx / BLOCK + by / BLOCK) % 2 == 0 else grass_alt
			draw_rect(Rect2(bx, by, BLOCK, BLOCK), tint)
	for path in paths:
		draw_rect(Rect2(path), sand)
		draw_rect(Rect2(path.position.x, path.end.y - 1, path.size.x, 1), sand.darkened(0.15))

	var rng := RandomNumberGenerator.new()
	rng.seed = flower_seed
	for i in (size.x * size.y) / 900:
		var spot := Vector2(rng.randi_range(0, size.x - 2), rng.randi_range(0, size.y - 2)).floor()
		var flower := [Color("f6f1e3"), Color("ffd84a"), Color("ff8fb1")][rng.randi_range(0, 2)] as Color
		if rng.randf() < 0.6:
			draw_rect(Rect2(spot, Vector2(1, 1)), grass.lightened(0.2))
		else:
			draw_rect(Rect2(spot, Vector2(2, 2)), flower)
