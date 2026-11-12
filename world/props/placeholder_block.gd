@tool
class_name PlaceholderBlock
extends StaticBody2D
## A solid map piece drawn with EarthBound's oblique look: a top face plus a
## darker front face, so the player sees both. The node's origin is the
## bottom-left corner of the footprint, which makes Y-sorting work.
## Swap these for TileMapLayer blocks once the tileset is ready.

enum Style { WALL, TREE, HOUSE, ROCK, WATER, STAND, SIGN }

## Ground area that blocks movement, in pixels (keep it on the 8 px grid).
@export var footprint := Vector2i(32, 16):
	set(value):
		footprint = value
		_rebuild()
## How tall the front face is drawn.
@export var height := 16:
	set(value):
		height = value
		queue_redraw()
@export var style := Style.WALL:
	set(value):
		style = value
		queue_redraw()
@export var color := Color("7a6a8f"):
	set(value):
		color = value
		queue_redraw()

var _shape_node: CollisionShape2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape_node == null:
		_shape_node = CollisionShape2D.new()
		add_child(_shape_node) # not saved: rebuilt from `footprint` every time
	var rect := RectangleShape2D.new()
	rect.size = Vector2(footprint)
	_shape_node.shape = rect
	_shape_node.position = Vector2(footprint.x / 2.0, -footprint.y / 2.0)
	queue_redraw()


func _draw() -> void:
	var w := float(footprint.x)
	var d := float(footprint.y)
	var h := float(height)
	var dark := color.darkened(0.35)
	var outline := color.darkened(0.6)
	match style:
		Style.WATER:
			draw_rect(Rect2(0, -d, w, d), color)
			for y in range(int(-d) + 4, 0, 8):
				for x in range(2, int(w) - 4, 12):
					draw_rect(Rect2(x + (y / 8 % 2) * 6, y, 4, 1), color.lightened(0.3))
		Style.TREE:
			draw_rect(Rect2(w / 2.0 - 3, -h, 6, h), Color("6b4a2f"))
			var canopy := Rect2(0, -h - d - 8, w, d + 12)
			draw_rect(canopy.grow(1), outline)
			draw_rect(canopy, color)
			draw_rect(Rect2(canopy.position + Vector2(4, 3), Vector2(w * 0.4, 3)), color.lightened(0.25))
		Style.HOUSE:
			var wall := Rect2(0, -h, w, h)
			var roof := Rect2(-2, -h - d, w + 4, d)
			draw_rect(roof.grow(1), outline)
			draw_rect(roof, color)
			draw_rect(wall, Color("e8dcc2"))
			draw_rect(Rect2(w / 2.0 - 5, -12, 10, 12), Color("6b4a2f"))
			draw_rect(Rect2(6, -h + 6, 8, 6), Color("8fd3ff"))
			draw_rect(Rect2(w - 14, -h + 6, 8, 6), Color("8fd3ff"))
		Style.STAND:
			draw_rect(Rect2(0, -h, w, h), dark)
			draw_rect(Rect2(0, -h - d, w, d), color)
			for i in range(0, int(w), 8):
				draw_rect(Rect2(i, -h - d - 6, 4, 6), Color("ff6b6b") if i % 16 == 0 else Color.WHITE)
		Style.SIGN:
			draw_rect(Rect2(w / 2.0 - 1, -h, 2, h), Color("6b4a2f"))
			draw_rect(Rect2(0, -h - 10, w, 10).grow(1), outline)
			draw_rect(Rect2(0, -h - 10, w, 10), color)
			draw_rect(Rect2(3, -h - 7, w - 6, 1), outline)
			draw_rect(Rect2(3, -h - 4, w - 10, 1), outline)
		_:
			draw_rect(Rect2(0, -h - d, w, d + h).grow(1), outline)
			draw_rect(Rect2(0, -h - d, w, d), color)
			draw_rect(Rect2(0, -h, w, h), dark)
