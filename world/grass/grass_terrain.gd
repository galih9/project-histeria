@tool
class_name GrassTerrain
extends Node2D
## Valdrin-style sub-tile mask grass terrain.
##
## Builds a fine RGBA8 sub-tile mask texture (`sub_cell_px` = 2 px, i.e. 64
## sub-cells per 16x16 tile) from the map's paths, natural clearings, and
## PlaceholderBlock footprints, blurs it softly, and lets `grass_terrain.gdshader`
## carve ragged noise-eaten borders with crisp pixel-art tufts and wildflowers.
##
## Mask channels:
##   R = grass coverage (0 = bare dirt/path, 1 = full meadow)
##   G = worn earth weight (0 = warm sandy path, 1 = dark worn earth)
##   B = lushness (0 = trimmed grass near roads, 1 = thick wild meadow)
##   A = ambient occlusion (1 = fully lit, <1 = shaded under trees/props)

const TERRAIN_MATERIAL := preload("res://world/grass/grass_terrain_material.tres")

@export_tool_button("Rebuild mask", "Reload") var rebuild_action := rebuild_mask

## Total terrain rectangle in local pixels (usually matches WorldMap bounds).
@export var bounds := Rect2i(0, 0, 640, 480):
	set(value):
		bounds = value
		_queue_rebuild()

## Pixel size of one sub-tile cell (2 px = 8x8 = 64 cells per 16x16 tile).
@export_range(1, 8, 1) var sub_cell_px := 2:
	set(value):
		sub_cell_px = maxi(value, 1)
		_queue_rebuild()

@export var pattern_seed := 7:
	set(value):
		pattern_seed = value
		_queue_rebuild()

## Sandy path rectangles in local pixels.
@export var paths: Array[Rect2i] = []:
	set(value):
		paths = value
		_queue_rebuild()

## Optional manual dirt patches: Vector3(x, y, radius_px).
@export var dirt_patches: Array[Vector3] = []:
	set(value):
		dirt_patches = value
		_queue_rebuild()

## Small organic bare-earth patches scattered across open meadow.
@export_range(0, 32, 1) var natural_dirt_spots := 7:
	set(value):
		natural_dirt_spots = value
		_queue_rebuild()

## Automatically wear grass down to dark earth under sibling/Entities PlaceholderBlocks.
@export var wear_under_props := true:
	set(value):
		wear_under_props = value
		_queue_rebuild()

var _mask_w := 0
var _mask_h := 0
var _grass := PackedFloat32Array()
var _worn := PackedFloat32Array()
var _lush := PackedFloat32Array()
var _ao := PackedFloat32Array()
var _mask_texture: ImageTexture
var _rebuild_queued := false


func _ready() -> void:
	if material == null:
		material = TERRAIN_MATERIAL
	rebuild_mask()


func _queue_rebuild() -> void:
	if not is_node_ready() or _rebuild_queued:
		return
	_rebuild_queued = true
	rebuild_mask.call_deferred()


func rebuild_mask() -> void:
	_rebuild_queued = false
	if material == null:
		material = TERRAIN_MATERIAL

	var step := maxi(sub_cell_px, 1)
	_mask_w = maxi(ceili(float(bounds.size.x) / float(step)), 1)
	_mask_h = maxi(ceili(float(bounds.size.y) / float(step)), 1)
	var count := _mask_w * _mask_h

	_grass.resize(count)
	_worn.resize(count)
	_lush.resize(count)
	_ao.resize(count)
	_grass.fill(1.0)
	_worn.fill(0.0)
	_lush.fill(0.85)
	_ao.fill(1.0)

	# 1. Stamp sandy paths and trim lushness along their edges.
	for path in paths:
		_stamp_rect(Rect2(path).grow(10.0), -1.0, -1.0, 0.35, -1.0)
		_stamp_rect(Rect2(path), 0.0, 0.0, 0.25, -1.0)

	# 2. Stamp manual dirt patches.
	for patch in dirt_patches:
		_stamp_circle(Vector2(patch.x, patch.y), patch.z, 0.0, 0.85, 0.4, -1.0)

	# 3. Wear grass under PlaceholderBlock props (houses, pond, trees, signs, rocks).
	var prop_rects: Array[Rect2] = []
	if wear_under_props:
		prop_rects = _stamp_props()

	# 4. Scatter deterministic small organic dirt scars away from paths & props.
	_stamp_natural_dirt_spots(prop_rects)

	# 5. Soften the sub-tile mask with 2 separable 3-tap box blur passes so
	#    bilinear texture filtering produces smooth organic erosion ramps.
	_blur_plane(_grass, 2)
	_blur_plane(_worn, 2)
	_blur_plane(_lush, 2)
	_blur_plane(_ao, 2)

	_upload_texture()
	_push_uniforms()
	queue_redraw()


## Runtime painting API: paints a circular patch (e.g., player/building wear).
func paint_circle(world_pos: Vector2, radius_px: float, grass_value := 0.0, worn_value := 0.85) -> void:
	var local_pos := to_local(world_pos)
	_stamp_circle(local_pos, radius_px, grass_value, worn_value, -1.0, -1.0)
	var r_cells := ceili((radius_px + float(sub_cell_px) * 4.0) / float(sub_cell_px))
	var cx := int(floorf((local_pos.x - float(bounds.position.x)) / float(sub_cell_px)))
	var cy := int(floorf((local_pos.y - float(bounds.position.y)) / float(sub_cell_px)))
	var region := Rect2i(cx - r_cells, cy - r_cells, r_cells * 2 + 1, r_cells * 2 + 1)
	_blur_plane_region(_grass, region, 1)
	_blur_plane_region(_worn, region, 1)
	_upload_texture()


## Runtime painting API: paints a rectangular patch (e.g., road or footprint).
func paint_rect(rect: Rect2, grass_value := 0.0, worn_value := 0.85) -> void:
	_stamp_rect(rect, grass_value, worn_value, -1.0, -1.0)
	var step := float(sub_cell_px)
	var min_x := int(floorf((rect.position.x - float(bounds.position.x)) / step)) - 2
	var min_y := int(floorf((rect.position.y - float(bounds.position.y)) / step)) - 2
	var max_x := int(ceilf((rect.end.x - float(bounds.position.x)) / step)) + 2
	var max_y := int(ceilf((rect.end.y - float(bounds.position.y)) / step)) + 2
	var region := Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	_blur_plane_region(_grass, region, 1)
	_blur_plane_region(_worn, region, 1)
	_upload_texture()


func _stamp_props() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var root := get_parent()
	if root == null:
		return rects
	var candidates: Array[Node] = []
	for child in root.get_children():
		candidates.append(child)
		if child.name == &"Entities":
			for sub in child.get_children():
				candidates.append(sub)
	for node in candidates:
		var block := node as PlaceholderBlock
		if block == null:
			continue
		var origin := to_local(block.global_position)
		var foot := Vector2(block.footprint)
		var rect := Rect2(origin.x, origin.y - foot.y, foot.x, foot.y)
		rects.append(rect.grow(8.0))
		match block.style:
			PlaceholderBlock.Style.HOUSE:
				_stamp_rect(rect.grow(4.0), 0.0, 0.92, 0.35, 0.55)
			PlaceholderBlock.Style.STAND:
				_stamp_rect(rect.grow(4.0), 0.0, 0.78, 0.4, 0.65)
			PlaceholderBlock.Style.WATER:
				_stamp_rect(rect.grow(2.5), 0.0, 0.88, 0.45, 0.72)
			PlaceholderBlock.Style.ROCK:
				_stamp_rect(rect.grow(1.5), 0.15, 0.72, 0.55, 0.60)
			PlaceholderBlock.Style.SIGN:
				_stamp_rect(rect.grow(2.0), 0.12, 0.62, 0.5, 0.78)
				_stamp_circle(Vector2(rect.get_center().x, rect.end.y + 3.0), 5.5, 0.15, 0.55, 0.45, -1.0)
			PlaceholderBlock.Style.TREE:
				var trunk := Vector2(rect.get_center().x, rect.end.y - 2.0)
				_stamp_circle(trunk, 5.5, 0.22, 0.75, -1.0, -1.0)
				_stamp_circle(trunk + Vector2(2.0, -2.0), 11.0, -1.0, -1.0, 1.0, 0.58)
			_:
				_stamp_rect(rect.grow(2.0), 0.1, 0.75, 0.5, 0.65)
	return rects


func _stamp_natural_dirt_spots(prop_rects: Array[Rect2]) -> void:
	if natural_dirt_spots <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern_seed * 97 + 13
	var margin := 28.0
	var placed := 0
	var attempts := 0
	while placed < natural_dirt_spots and attempts < natural_dirt_spots * 10:
		attempts += 1
		var spot := Vector2(
			rng.randf_range(float(bounds.position.x) + margin, float(bounds.end.x) - margin),
			rng.randf_range(float(bounds.position.y) + margin, float(bounds.end.y) - margin)
		)
		var blocked := false
		for p in paths:
			if Rect2(p).grow(18.0).has_point(spot):
				blocked = true
				break
		if not blocked:
			for pr in prop_rects:
				if pr.grow(14.0).has_point(spot):
					blocked = true
					break
		if blocked:
			continue
		placed += 1
		# Cluster of 3-4 small overlapping circles for a ragged Valdrin-style scar.
		var blobs := rng.randi_range(3, 4)
		for b in blobs:
			var offset := Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-6.0, 6.0))
			var radius := rng.randf_range(3.5, 7.0)
			var g_val := rng.randf_range(0.15, 0.38)
			_stamp_circle(spot + offset, radius, g_val, 0.88, 0.5, -1.0)


func _stamp_rect(rect: Rect2, grass_val: float, worn_val: float, lush_val: float, ao_val: float) -> void:
	var step := float(sub_cell_px)
	var min_x := clampi(int(floorf((rect.position.x - float(bounds.position.x)) / step)), 0, _mask_w - 1)
	var min_y := clampi(int(floorf((rect.position.y - float(bounds.position.y)) / step)), 0, _mask_h - 1)
	var max_x := clampi(int(ceilf((rect.end.x - float(bounds.position.x)) / step)) - 1, 0, _mask_w - 1)
	var max_y := clampi(int(ceilf((rect.end.y - float(bounds.position.y)) / step)) - 1, 0, _mask_h - 1)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	for y in range(min_y, max_y + 1):
		var row := y * _mask_w
		for x in range(min_x, max_x + 1):
			var idx := row + x
			if grass_val >= 0.0:
				_grass[idx] = minf(_grass[idx], grass_val)
			if worn_val >= 0.0:
				_worn[idx] = maxf(_worn[idx], worn_val)
			if lush_val >= 0.0:
				_lush[idx] = lush_val
			if ao_val >= 0.0:
				_ao[idx] = minf(_ao[idx], ao_val)


func _stamp_circle(center: Vector2, radius_px: float, grass_val: float, worn_val: float, lush_val: float, ao_val: float) -> void:
	if radius_px <= 0.0:
		return
	var step := float(sub_cell_px)
	var min_x := clampi(int(floorf((center.x - radius_px - float(bounds.position.x)) / step)), 0, _mask_w - 1)
	var min_y := clampi(int(floorf((center.y - radius_px - float(bounds.position.y)) / step)), 0, _mask_h - 1)
	var max_x := clampi(int(ceilf((center.x + radius_px - float(bounds.position.x)) / step)), 0, _mask_w - 1)
	var max_y := clampi(int(ceilf((center.y + radius_px - float(bounds.position.y)) / step)), 0, _mask_h - 1)
	var r2 := radius_px * radius_px
	for y in range(min_y, max_y + 1):
		var py := float(bounds.position.y) + (float(y) + 0.5) * step
		var dy := py - center.y
		var row := y * _mask_w
		for x in range(min_x, max_x + 1):
			var px := float(bounds.position.x) + (float(x) + 0.5) * step
			var dx := px - center.x
			if dx * dx + dy * dy <= r2:
				var idx := row + x
				if grass_val >= 0.0:
					_grass[idx] = minf(_grass[idx], grass_val)
				if worn_val >= 0.0:
					_worn[idx] = maxf(_worn[idx], worn_val)
				if lush_val >= 0.0:
					_lush[idx] = lush_val
				if ao_val >= 0.0:
					_ao[idx] = minf(_ao[idx], ao_val)


func _blur_plane(plane: PackedFloat32Array, passes: int) -> void:
	_blur_plane_region(plane, Rect2i(0, 0, _mask_w, _mask_h), passes)


func _blur_plane_region(plane: PackedFloat32Array, region: Rect2i, passes: int) -> void:
	if _mask_w <= 0 or _mask_h <= 0 or passes <= 0:
		return
	var x0 := clampi(region.position.x, 0, _mask_w - 1)
	var y0 := clampi(region.position.y, 0, _mask_h - 1)
	var x1 := clampi(region.end.x - 1, 0, _mask_w - 1)
	var y1 := clampi(region.end.y - 1, 0, _mask_h - 1)
	if x1 < x0 or y1 < y0:
		return

	var temp := plane.duplicate()
	for _p in passes:
		# Horizontal 3-tap pass.
		for y in range(y0, y1 + 1):
			var row := y * _mask_w
			for x in range(x0, x1 + 1):
				var xl := maxi(x - 1, 0)
				var xr := mini(x + 1, _mask_w - 1)
				temp[row + x] = (plane[row + xl] + plane[row + x] + plane[row + xr]) / 3.0
		# Vertical 3-tap pass.
		for y in range(y0, y1 + 1):
			var row := y * _mask_w
			var row_u := maxi(y - 1, 0) * _mask_w
			var row_d := mini(y + 1, _mask_h - 1) * _mask_w
			for x in range(x0, x1 + 1):
				plane[row + x] = (temp[row_u + x] + temp[row + x] + temp[row_d + x]) / 3.0


func _upload_texture() -> void:
	var bytes := PackedByteArray()
	bytes.resize(_mask_w * _mask_h * 4)
	for i in _mask_w * _mask_h:
		var o := i * 4
		bytes[o] = clampi(roundi(_grass[i] * 255.0), 0, 255)
		bytes[o + 1] = clampi(roundi(_worn[i] * 255.0), 0, 255)
		bytes[o + 2] = clampi(roundi(_lush[i] * 255.0), 0, 255)
		bytes[o + 3] = clampi(roundi(_ao[i] * 255.0), 0, 255)
	var img := Image.create_from_data(_mask_w, _mask_h, false, Image.FORMAT_RGBA8, bytes)
	if _mask_texture == null or _mask_texture.get_width() != _mask_w or _mask_texture.get_height() != _mask_h:
		_mask_texture = ImageTexture.create_from_image(img)
	else:
		_mask_texture.update(img)
	_push_uniforms()


func _push_uniforms() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter(&"mask_texture", _mask_texture)
	mat.set_shader_parameter(&"map_origin", Vector2(bounds.position))
	mat.set_shader_parameter(&"map_size", Vector2(bounds.size))
	mat.set_shader_parameter(&"seed_offset", float(pattern_seed) * 13.7)


func _draw() -> void:
	draw_rect(Rect2(bounds), Color.WHITE)
