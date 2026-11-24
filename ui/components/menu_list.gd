class_name MenuList
extends PanelContainer
## The shared vertical list with a cursor (GDD 03, "Menus"). Long lists scroll,
## with a dedicated right scroll rail for arrows above/below. Used by the
## battle menu, the title menu, recruit answers, and the pause menu.
##
## Usage:  var index := await menu.choose(entries)   # -1 = cancelled

signal closed(index: int)
signal highlighted(index: int)

const CURSOR_SLOT_WIDTH := 7
const SCROLL_RAIL_WIDTH := 7
const DISABLED_COLOR := Color("7d7691")
const SELECTED_COLOR := Color("fff8e0")
const NORMAL_RIGHT_COLOR := Color("bdb5d6")
const ACTIVE_GOLD := Color("ffd35f")
const DORMANT_ARROW := Color("a8a0c4")
const OUTLINE_COLOR := Color("090717")
const RAIL_TRACK_COLOR := Color("2e264a")
const RAIL_DIM_ARROW := Color("4c436b")
const CANCEL_TEXT := "Cancel"

@export var max_visible_rows := 4
@export var row_height := 15
## Lets the Cancel input close the list (returns -1).
@export var allow_cancel := true
## Adds a Cancel row at the bottom (GDD 03, "Cancel input").
@export var add_cancel_entry := true
## Keeps the list visible with a muted highlight after picking an entry.
@export var keep_visible_on_select := false
## Uses the gold HighlightPanel border while active.
@export var highlight_active_border := true

var _entries: Array[MenuEntry] = []
var _index := 0
var _scroll := 0
var _active := false
var _bob := 0.0
var _content: HBoxContainer
var _rows: VBoxContainer
var _scroll_rail: Control
var _active_cursor: Control

var _row_active_box: StyleBoxFlat
var _row_dormant_box: StyleBoxFlat
var _row_empty_box: StyleBoxEmpty


func _ready() -> void:
	_init_row_styles()

	_content = HBoxContainer.new()
	_content.add_theme_constant_override("separation", 2)
	add_child(_content)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 1)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(_rows)

	_scroll_rail = Control.new()
	_scroll_rail.custom_minimum_size.x = SCROLL_RAIL_WIDTH
	_scroll_rail.size_flags_vertical = Control.SIZE_FILL
	_scroll_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_rail.draw.connect(_draw_scroll_rail)
	_scroll_rail.hide()
	_content.add_child(_scroll_rail)

	hide()


func _init_row_styles() -> void:
	_row_active_box = StyleBoxFlat.new()
	_row_active_box.bg_color = Color("2a1f57")
	_row_active_box.border_width_left = 1
	_row_active_box.border_color = ACTIVE_GOLD
	_row_active_box.content_margin_left = 2.0
	_row_active_box.content_margin_right = 3.0
	_row_active_box.content_margin_top = 0.0
	_row_active_box.content_margin_bottom = 0.0
	_row_active_box.anti_aliasing = false

	_row_dormant_box = StyleBoxFlat.new()
	_row_dormant_box.bg_color = Color("1c153b")
	_row_dormant_box.border_width_left = 1
	_row_dormant_box.border_color = Color("7d739e")
	_row_dormant_box.content_margin_left = 2.0
	_row_dormant_box.content_margin_right = 3.0
	_row_dormant_box.content_margin_top = 0.0
	_row_dormant_box.content_margin_bottom = 0.0
	_row_dormant_box.anti_aliasing = false

	_row_empty_box = StyleBoxEmpty.new()
	_row_empty_box.content_margin_left = 3.0
	_row_empty_box.content_margin_right = 3.0
	_row_empty_box.content_margin_top = 0.0
	_row_empty_box.content_margin_bottom = 0.0


func _process(delta: float) -> void:
	if _active and is_instance_valid(_active_cursor):
		_bob = fmod(_bob + delta, 0.7)
		_active_cursor.queue_redraw()


## Opens the list and waits for a pick. Returns the entry index, or -1 on cancel.
func choose(entries: Array[MenuEntry], start_index := 0) -> int:
	open(entries, start_index)
	return await closed


func open(entries: Array[MenuEntry], start_index := 0) -> void:
	_entries = entries.duplicate()
	if add_cancel_entry and allow_cancel:
		_entries.append(MenuEntry.new(GameText.text("ui_text.cancel_entry", CANCEL_TEXT), null))
	_index = clampi(start_index, 0, maxi(_entries.size() - 1, 0))
	_scroll = 0
	_bob = 0.0
	_active = true
	if highlight_active_border:
		theme_type_variation = &"HighlightPanel"
	_ensure_visible()
	_rebuild_rows()
	show()
	reset_size.call_deferred()
	highlighted.emit(_index)


func close() -> void:
	_active = false
	theme_type_variation = &""
	hide()


func is_open() -> bool:
	return _active


func _unhandled_input(event: InputEvent) -> void:
	if not _active or _entries.is_empty():
		return
	if event.is_action_pressed("move_up", true):
		_move(-1)
	elif event.is_action_pressed("move_down", true):
		_move(1)
	elif event.is_action_pressed("confirm"):
		_submit()
	elif event.is_action_pressed("cancel") and allow_cancel:
		_finish(-1)
	else:
		return
	get_viewport().set_input_as_handled()


func _move(step: int) -> void:
	_index = wrapi(_index + step, 0, _entries.size())
	_bob = 0.0
	_ensure_visible()
	_rebuild_rows()
	highlighted.emit(_index)


func _submit() -> void:
	var entry := _entries[_index]
	if entry.disabled:
		return
	var is_cancel_row := add_cancel_entry and allow_cancel and _index == _entries.size() - 1
	_finish(-1 if is_cancel_row else _index)


func _finish(index: int) -> void:
	if keep_visible_on_select and index >= 0:
		_active = false
		theme_type_variation = &""
		_rebuild_rows()
	else:
		close()
	closed.emit(index)


func _ensure_visible() -> void:
	if _index < _scroll:
		_scroll = _index
	elif _index >= _scroll + max_visible_rows:
		_scroll = _index - max_visible_rows + 1


func _rebuild_rows() -> void:
	_active_cursor = null
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	var last := mini(_scroll + max_visible_rows, _entries.size())
	for i in range(_scroll, last):
		var selected := i == _index
		_rows.add_child(_make_row(_entries[i], selected))

	_scroll_rail.visible = _entries.size() > max_visible_rows
	_scroll_rail.queue_redraw()
	reset_size()


func _make_row(entry: MenuEntry, selected: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = row_height
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if selected:
		panel.add_theme_stylebox_override("panel", _row_active_box if _active else _row_dormant_box)
	else:
		panel.add_theme_stylebox_override("panel", _row_empty_box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var cursor := Control.new()
	cursor.custom_minimum_size = Vector2(CURSOR_SLOT_WIDTH, 0)
	cursor.size_flags_vertical = Control.SIZE_FILL
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cursor)

	var label := Label.new()
	label.text = entry.text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	_tint_main(label, entry, selected)
	row.add_child(label)

	if not entry.right_text.is_empty():
		var right := Label.new()
		right.text = entry.right_text
		right.size_flags_vertical = Control.SIZE_FILL
		right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_tint_right(right, entry, selected)
		row.add_child(right)

	if selected:
		_active_cursor = cursor
		cursor.draw.connect(_draw_cursor.bind(cursor, label))
	return panel


func _tint_main(label: Label, entry: MenuEntry, selected: bool) -> void:
	if entry.disabled:
		label.add_theme_color_override("font_color", DISABLED_COLOR)
	elif entry.has_color():
		label.add_theme_color_override("font_color", entry.color)
	elif selected and _active:
		label.add_theme_color_override("font_color", SELECTED_COLOR)


func _tint_right(label: Label, entry: MenuEntry, selected: bool) -> void:
	if entry.disabled:
		label.add_theme_color_override("font_color", DISABLED_COLOR)
	elif entry.has_color():
		label.add_theme_color_override("font_color", entry.color)
	elif selected and _active:
		label.add_theme_color_override("font_color", ACTIVE_GOLD)
	else:
		label.add_theme_color_override("font_color", NORMAL_RIGHT_COLOR)


## Draws the 5x7 outlined pixel arrow aligned to the sibling label's actual text glyph center.
func _draw_cursor(slot: Control, label: Label) -> void:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var line_h := ascent + descent
	var line_top := floorf((label.size.y - line_h) * 0.5)
	var cy := int(floorf(line_top + ascent * 0.62))

	var shift := 1 if (_active and _bob >= 0.35) else 0
	var bx := 1 + shift
	var fill := ACTIVE_GOLD if _active else DORMANT_ARROW

	# 1px dark outline
	slot.draw_rect(Rect2(bx, cy - 2, 1, 5), OUTLINE_COLOR)
	slot.draw_rect(Rect2(bx + 1, cy - 3, 1, 7), OUTLINE_COLOR)
	slot.draw_rect(Rect2(bx + 2, cy - 2, 1, 5), OUTLINE_COLOR)
	slot.draw_rect(Rect2(bx + 3, cy - 1, 1, 3), OUTLINE_COLOR)
	slot.draw_rect(Rect2(bx + 4, cy, 1, 1), OUTLINE_COLOR)

	# 3x5 crisp arrow body
	slot.draw_rect(Rect2(bx + 1, cy - 2, 1, 5), fill)
	slot.draw_rect(Rect2(bx + 2, cy - 1, 1, 3), fill)
	slot.draw_rect(Rect2(bx + 3, cy, 1, 1), fill)


func _draw_scroll_rail() -> void:
	if _entries.size() <= max_visible_rows:
		return
	var h := _scroll_rail.size.y
	if h < 12.0:
		return
	var cx := int(floorf(_scroll_rail.size.x * 0.5))
	var has_up := _scroll > 0
	var has_down := _scroll + max_visible_rows < _entries.size()

	# Up arrow (5x3)
	var up_col := ACTIVE_GOLD if has_up else RAIL_DIM_ARROW
	_scroll_rail.draw_rect(Rect2(cx, 1, 1, 1), up_col)
	_scroll_rail.draw_rect(Rect2(cx - 1, 2, 3, 1), up_col)
	_scroll_rail.draw_rect(Rect2(cx - 2, 3, 5, 1), up_col)

	# Down arrow (5x3)
	var down_col := ACTIVE_GOLD if has_down else RAIL_DIM_ARROW
	var by := int(floorf(h)) - 4
	_scroll_rail.draw_rect(Rect2(cx - 2, by, 5, 1), down_col)
	_scroll_rail.draw_rect(Rect2(cx - 1, by + 1, 3, 1), down_col)
	_scroll_rail.draw_rect(Rect2(cx, by + 2, 1, 1), down_col)

	# Track & proportional thumb
	var track_top := 6.0
	var track_bot := h - 6.0
	var track_len := track_bot - track_top
	if track_len >= 4.0:
		_scroll_rail.draw_rect(Rect2(cx, track_top, 1, track_len), RAIL_TRACK_COLOR)
		var max_scroll := maxi(_entries.size() - max_visible_rows, 1)
		var thumb_h := maxf(3.0, floorf(track_len * float(max_visible_rows) / float(_entries.size())))
		var thumb_y := track_top + floorf((track_len - thumb_h) * float(_scroll) / float(max_scroll))
		_scroll_rail.draw_rect(Rect2(cx - 1, thumb_y, 3, thumb_h), ACTIVE_GOLD)
