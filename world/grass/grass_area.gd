@tool
class_name GrassArea
extends Polygon2D
## A shape you draw in the 2D editor that fills itself with grass.
##
## How to use:
##   1. Select the map's Entities node, Add Child Node, pick GrassArea.
##      It starts as a small square.
##   2. Drag the whole area to move it. Drag its corner points to reshape it.
##      With the node selected, the toolbar above the 2D view has the point
##      tools: add points (click on an edge or in empty space), move, delete.
##   3. The grass refills by itself a moment after each change.
## Ctrl+D duplicates an area. The fill is a pale green in the editor and
## invisible in the game. Tufts are rebuilt from `pattern_seed` on load, so they
## stay out of the scene file; change the seed for a new arrangement.
## Keep areas inside the Y-sorted Entities node so the player walks *through*
## the grass. After moving blocks or paths, press "Rebuild grass".

const EDITOR_FILL := Color(0.55, 1.0, 0.45, 0.22)
const CELL := 32.0
const REBUILD_DELAY := 0.2

@export_tool_button("Rebuild grass", "Reload") var rebuild_action := _rebuild

## Tufts per 32x32 block.
@export_range(0.25, 8.0, 0.05) var density := 3.0:
	set(value):
		density = value
		_queue_rebuild()
@export var pattern_seed := 1:
	set(value):
		pattern_seed = value
		_queue_rebuild()
## 0 = even carpet, 1 = clumps with gaps between them.
@export_range(0.0, 1.0, 0.05) var patchiness := 0.35:
	set(value):
		patchiness = value
		_queue_rebuild()
## Tufts thin out over this many px toward the outline, for soft borders.
@export var edge_fade := 10:
	set(value):
		edge_fade = value
		_queue_rebuild()

@export_group("Tufts")
@export var layers := Vector2i(1, 3):
	set(value):
		layers = value
		_queue_rebuild()
@export var blades_per_layer := Vector2i(2, 5):
	set(value):
		blades_per_layer = value
		_queue_rebuild()
@export var spread := 5:
	set(value):
		spread = value
		_queue_rebuild()
@export var layer_gap := 2:
	set(value):
		layer_gap = value
		_queue_rebuild()
## Back to front; the front layer always uses the last (lightest) color.
@export var layer_colors := PackedColorArray([Color("3f7340"), Color("5d9a4d"), Color("7fb758")]):
	set(value):
		layer_colors = value
		_queue_rebuild()
@export_range(0.0, 1.0, 0.05) var flip_chance := 0.5:
	set(value):
		flip_chance = value
		_queue_rebuild()

@export_group("Keep clear")
## Skip the footprints of PlaceholderBlocks that share this node's parent.
@export var avoid_blocks := true:
	set(value):
		avoid_blocks = value
		_queue_rebuild()
## Skip the sandy paths painted by the map's Ground node.
@export var avoid_ground_paths := true:
	set(value):
		avoid_ground_paths = value
		_queue_rebuild()
## Extra px of space kept around blocks and paths.
@export var clear_margin := 3:
	set(value):
		clear_margin = value
		_queue_rebuild()

var _rebuild_queued := false
var _seen_polygon := PackedVector2Array()
var _seen_offset := Vector2.ZERO
var _seen_position := Vector2.ZERO
var _change_countdown := -1.0


func _init() -> void:
	color = EDITOR_FILL
	if polygon.is_empty():
		polygon = PackedVector2Array([Vector2(0, 0), Vector2(64, 0), Vector2(64, 48), Vector2(0, 48)])


func _ready() -> void:
	y_sort_enabled = true
	if not Engine.is_editor_hint():
		color = Color(0, 0, 0, 0)
	_remember_shape()
	_rebuild()
	set_process(Engine.is_editor_hint())


## Editor only: refill after the shape or position stops changing for a moment.
func _process(delta: float) -> void:
	if polygon != _seen_polygon or offset != _seen_offset or position != _seen_position:
		_remember_shape()
		_change_countdown = REBUILD_DELAY
	if _change_countdown >= 0.0:
		_change_countdown -= delta
		if _change_countdown < 0.0:
			_rebuild()


func _remember_shape() -> void:
	_seen_polygon = polygon.duplicate()
	_seen_offset = offset
	_seen_position = position


func _queue_rebuild() -> void:
	if not is_node_ready() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		if child is GrassTuft:
			remove_child(child)
			child.free()
	if polygon.size() < 3:
		return

	var shape := polygon.duplicate()
	for i in shape.size():
		shape[i] += offset
	var bounds := Rect2(shape[0], Vector2.ZERO)
	for point in shape:
		bounds = bounds.expand(point)

	var blockers := _collect_blockers()
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern_seed
	var noise := FastNoiseLite.new()
	noise.seed = pattern_seed
	noise.frequency = 0.025

	var cell := CELL / sqrt(density)
	var columns := ceili(bounds.size.x / cell)
	var rows := ceili(bounds.size.y / cell)
	for gy in rows:
		for gx in columns:
			# Jittered grid: one tuft per cell, randomly placed inside it.
			var spot := (bounds.position + Vector2((gx + rng.randf()) * cell, (gy + rng.randf()) * cell)).floor()
			var tuft_seed := rng.randi()
			var roll := rng.randf()
			if not Geometry2D.is_point_in_polygon(spot, shape):
				continue
			if roll > _keep_chance(spot, shape, noise):
				continue
			if _is_blocked(to_global(spot), blockers):
				continue
			_spawn_tuft(spot, tuft_seed)


func _keep_chance(spot: Vector2, shape: PackedVector2Array, noise: FastNoiseLite) -> float:
	var chance := 1.0
	if edge_fade > 0:
		chance *= clampf(_distance_to_outline(spot, shape) / float(edge_fade), 0.15, 1.0)
	if patchiness > 0.0:
		var clump := smoothstep(-0.25, 0.3, noise.get_noise_2dv(to_global(spot)))
		chance *= lerpf(1.0, clump, patchiness)
	return chance


func _distance_to_outline(spot: Vector2, shape: PackedVector2Array) -> float:
	var nearest := INF
	for i in shape.size():
		var a := shape[i]
		var b := shape[(i + 1) % shape.size()]
		nearest = minf(nearest, spot.distance_to(Geometry2D.get_closest_point_to_segment(spot, a, b)))
	return nearest


func _spawn_tuft(spot: Vector2, tuft_seed: int) -> void:
	var tuft := GrassTuft.new()
	tuft.position = spot
	tuft.layers = layers
	tuft.blades_per_layer = blades_per_layer
	tuft.spread = spread
	tuft.layer_gap = layer_gap
	tuft.layer_colors = layer_colors
	tuft.flip_chance = flip_chance
	tuft.pattern_seed = tuft_seed
	# No owner: the tuft lives only in memory and is never saved into the scene.
	add_child(tuft)


func _collect_blockers() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var parent := get_parent()
	if avoid_blocks and parent:
		for node in parent.get_children():
			var block := node as PlaceholderBlock
			if block:
				var foot := Vector2(block.footprint)
				var origin := block.global_position
				rects.append(Rect2(origin.x, origin.y - foot.y, foot.x, foot.y))
	if avoid_ground_paths:
		var ground := _find_ground()
		if ground:
			for path in ground.paths:
				rects.append(Rect2(ground.global_position + Vector2(path.position), Vector2(path.size)))
	for i in rects.size():
		rects[i] = rects[i].grow(clear_margin)
	return rects


func _is_blocked(map_spot: Vector2, blockers: Array[Rect2]) -> bool:
	for rect in blockers:
		if rect.has_point(map_spot):
			return true
	return false


## The map's Ground node: a sibling of this node or of one of its ancestors.
func _find_ground() -> Ground:
	var node := get_parent()
	while node:
		for child in node.get_children():
			if child is Ground:
				return child as Ground
		node = node.get_parent()
	return null
