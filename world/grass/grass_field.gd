@tool
class_name GrassField
extends Node2D
## Fills a rectangle with GrassTuft sets. Keep it inside the map's Y-sorted
## Entities node so the player walks *through* the grass: blades in front of
## their feet draw over them, blades behind draw under them.
##
## The tufts are rebuilt from `pattern_seed` every time the scene loads, so they
## stay out of the scene file. Change the seed for a new arrangement, and press
## "Rebuild grass" after moving blocks or paths around.

const CELL := 32.0

@export_tool_button("Rebuild grass", "Reload") var rebuild_action := _rebuild

## Field size in px, from this node's position to the bottom right.
@export var size := Vector2i(160, 96):
	set(value):
		size = value
		_queue_rebuild()
## Tufts per 32x32 block.
@export_range(0.25, 8.0, 0.05) var density := 2.5:
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
## Tufts thin out over this many px toward the edges, for soft borders.
@export var edge_fade := 12:
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
## Extra areas to keep clear, in map px.
@export var avoid_rects: Array[Rect2i] = []:
	set(value):
		avoid_rects = value
		_queue_rebuild()
## Extra px of space kept around blocks and paths.
@export var clear_margin := 3:
	set(value):
		clear_margin = value
		_queue_rebuild()

var _rebuild_queued := false


func _ready() -> void:
	y_sort_enabled = true
	_rebuild()


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
	queue_redraw()

	var blockers := _collect_blockers()
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern_seed
	var noise := FastNoiseLite.new()
	noise.seed = pattern_seed
	noise.frequency = 0.025

	var cell := CELL / sqrt(density)
	var columns := ceili(size.x / cell)
	var rows := ceili(size.y / cell)
	for gy in rows:
		for gx in columns:
			# Jittered grid: one tuft per cell, randomly placed inside it.
			var spot := Vector2((gx + rng.randf()) * cell, (gy + rng.randf()) * cell).floor()
			var tuft_seed := rng.randi()
			var roll := rng.randf()
			if spot.x >= size.x or spot.y >= size.y:
				continue
			if roll > _keep_chance(spot, noise):
				continue
			var map_spot := global_position.floor() + spot
			if _is_blocked(map_spot, blockers):
				continue
			_spawn_tuft(spot, tuft_seed)


func _keep_chance(spot: Vector2, noise: FastNoiseLite) -> float:
	var chance := 1.0
	if edge_fade > 0:
		var edge := minf(minf(spot.x, size.x - spot.x), minf(spot.y, size.y - spot.y))
		chance *= clampf(edge / float(edge_fade), 0.15, 1.0)
	if patchiness > 0.0:
		var map_spot := global_position + spot
		var clump := smoothstep(-0.25, 0.3, noise.get_noise_2dv(map_spot))
		chance *= lerpf(1.0, clump, patchiness)
	return chance


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
	for r in avoid_rects:
		rects.append(Rect2(r))
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


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, Vector2(size)), Color(0.6, 1.0, 0.45, 0.6), false, 1.0)
