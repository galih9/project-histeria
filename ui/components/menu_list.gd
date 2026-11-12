class_name MenuList
extends PanelContainer
## The shared vertical list with a cursor (GDD 03, "Menus"). Long lists scroll,
## with small arrows for more rows above or below. Used by the battle menu,
## the title menu and the pause menu.
##
## Usage:  var index := await menu.choose(entries)   # -1 = cancelled

signal closed(index: int)
signal highlighted(index: int)

const CURSOR_WIDTH := 8
const DISABLED_COLOR := Color(0.5, 0.48, 0.55)
const CANCEL_TEXT := "Cancel"

@export var max_visible_rows := 4
@export var row_height := 13
## Lets the Cancel input close the list (returns -1).
@export var allow_cancel := true
## Adds a Cancel row at the bottom (GDD 03, "Cancel input").
@export var add_cancel_entry := true

var _entries: Array[MenuEntry] = []
var _index := 0
var _scroll := 0
var _active := false
var _blink := 0.0
var _rows: VBoxContainer
var _arrows: Control


func _ready() -> void:
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 0)
	add_child(_rows)
	_arrows = Control.new()
	_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrows.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrows.draw.connect(_draw_overlay)
	add_child(_arrows)
	hide()


func _process(delta: float) -> void:
	if _active:
		_blink = fmod(_blink + delta, 0.8)
		_arrows.queue_redraw()


## Opens the list and waits for a pick. Returns the entry index, or -1 on cancel.
func choose(entries: Array[MenuEntry], start_index := 0) -> int:
	open(entries, start_index)
	return await closed


func open(entries: Array[MenuEntry], start_index := 0) -> void:
	_entries = entries.duplicate()
	if add_cancel_entry and allow_cancel:
		_entries.append(MenuEntry.new(CANCEL_TEXT, null))
	_index = clampi(start_index, 0, maxi(_entries.size() - 1, 0))
	_scroll = 0
	_ensure_visible()
	_rebuild_rows()
	_active = true
	show()
	highlighted.emit(_index)


func close() -> void:
	_active = false
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
	close()
	closed.emit(index)


func _ensure_visible() -> void:
	if _index < _scroll:
		_scroll = _index
	elif _index >= _scroll + max_visible_rows:
		_scroll = _index - max_visible_rows + 1


func _rebuild_rows() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var last := mini(_scroll + max_visible_rows, _entries.size())
	for i in range(_scroll, last):
		_rows.add_child(_make_row(_entries[i]))
	_arrows.queue_redraw()


func _make_row(entry: MenuEntry) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = row_height
	row.clip_contents = true
	row.add_theme_constant_override("separation", 4)

	var spacer := Control.new()
	spacer.custom_minimum_size.x = CURSOR_WIDTH
	row.add_child(spacer)

	var label := Label.new()
	label.text = entry.text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tint(label, entry)
	row.add_child(label)

	if not entry.right_text.is_empty():
		var right := Label.new()
		right.text = entry.right_text
		_tint(right, entry)
		row.add_child(right)
	return row


func _tint(label: Label, entry: MenuEntry) -> void:
	if entry.disabled:
		label.add_theme_color_override("font_color", DISABLED_COLOR)
	elif entry.has_color():
		label.add_theme_color_override("font_color", entry.color)


## Cursor triangle and scroll arrows, drawn as pixels (the font has no arrow glyphs).
func _draw_overlay() -> void:
	# The overlay sits inside the panel margins, like the rows.
	if not _active:
		return
	var color := get_theme_color("font_color", "Label")
	if _blink < 0.55:
		var y := floorf((_index - _scroll) * row_height + row_height / 2.0)
		_arrows.draw_colored_polygon(PackedVector2Array([
			Vector2(0, y - 3), Vector2(4, y), Vector2(0, y + 3)]), color)
	var cx := _arrows.size.x - 2.0
	if _scroll > 0:
		_arrows.draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 3, 3), Vector2(cx + 3, 3), Vector2(cx, 0)]), color)
	if _scroll + max_visible_rows < _entries.size():
		var by := _arrows.size.y
		_arrows.draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 3, by - 3), Vector2(cx + 3, by - 3), Vector2(cx, by)]), color)
