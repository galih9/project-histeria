@tool
class_name GrassTuft
extends Node2D
## One set of grass made from the white, straight blade in assets/grassblade.png:
## 1-3 layers, each with 2-5 blades. Back layers sit a few px higher and use
## the darker colors; the front layer always uses the last (lightest) color.
## Blades are randomly mirrored for variety. The node's position is the root
## of the front layer, so Y-sorting puts the player in front of or behind it.
##
## GrassField spawns these. You can also drop one into a Y-sorted node by hand.

const BLADE_TEXTURE := preload("res://assets/grassblade.png")
const GRASS_MATERIAL := preload("res://world/grass/grass_material.tres")
## Where the root sits inside the 32x32 blade texture: the middle of the base
## (between columns 15 and 16), at the bottom edge. The mirrored copy shares it.
## Keep in sync with `blade_root` in grass_sway.gdshader.
const BLADE_ROOT := Vector2(16, 32)
## Horizontal slices per blade: more slices = smoother curve.
const SLICES := 4

static var _mirrored: Texture2D

@export var pattern_seed := 0:
	set(value):
		pattern_seed = value
		_regenerate()
## Layer count, min and max.
@export var layers := Vector2i(1, 3):
	set(value):
		layers = value
		_regenerate()
## Blades in each layer, min and max.
@export var blades_per_layer := Vector2i(2, 5):
	set(value):
		blades_per_layer = value
		_regenerate()
## How far blades scatter left and right of the tuft's center, in px.
@export var spread := 5:
	set(value):
		spread = value
		_regenerate()
## How many px each layer sits behind the one in front of it.
@export var layer_gap := 2:
	set(value):
		layer_gap = value
		_regenerate()
## Back to front. The front layer always gets the last color, so keep it the lightest.
@export var layer_colors := PackedColorArray([Color("3f7340"), Color("5d9a4d"), Color("7fb758")]):
	set(value):
		layer_colors = value
		_regenerate()
@export_range(0.0, 1.0, 0.05) var flip_chance := 0.5:
	set(value):
		flip_chance = value
		_regenerate()

var _positions := PackedVector2Array()
var _flipped := PackedByteArray()
var _colors := PackedColorArray()


func _ready() -> void:
	material = GRASS_MATERIAL
	_regenerate()


func _regenerate() -> void:
	if not is_node_ready():
		return
	_positions.clear()
	_flipped.clear()
	_colors.clear()
	if layer_colors.is_empty():
		queue_redraw()
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern_seed
	var layer_count := clampi(rng.randi_range(layers.x, maxi(layers.x, layers.y)), 1, layer_colors.size())
	# Back layer first so front blades draw over back ones.
	for depth in range(layer_count - 1, -1, -1):
		var color := layer_colors[layer_colors.size() - 1 - depth]
		var count := rng.randi_range(maxi(blades_per_layer.x, 1), maxi(blades_per_layer.x, blades_per_layer.y))
		for i in count:
			var x := rng.randi_range(-spread, spread)
			var y := -depth * layer_gap - (rng.randi_range(0, 1) if depth > 0 else 0)
			_positions.append(Vector2(x, y))
			_flipped.append(1 if rng.randf() < flip_chance else 0)
			_colors.append(color)
	queue_redraw()


func _draw() -> void:
	var size := BLADE_TEXTURE.get_size()
	var slice_height := size.y / SLICES
	for i in _positions.size():
		var texture: Texture2D = _mirrored_texture() if _flipped[i] == 1 else BLADE_TEXTURE
		var top_left := _positions[i] - BLADE_ROOT
		# Stacked slices give the shader corners along the blade, so it can curve it.
		for s in SLICES:
			var src := Rect2(0.0, s * slice_height, size.x, slice_height)
			var dst := Rect2(top_left + src.position, src.size)
			draw_texture_rect_region(texture, dst, src, _colors[i])


## A left-right mirrored copy of the blade, made once and shared by every tuft.
static func _mirrored_texture() -> Texture2D:
	if _mirrored == null:
		var image := BLADE_TEXTURE.get_image()
		image.flip_x()
		_mirrored = ImageTexture.create_from_image(image)
	return _mirrored
