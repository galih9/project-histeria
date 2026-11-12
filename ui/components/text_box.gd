class_name TextBox
extends PanelContainer
## EarthBound-style text window (GDD 03, "Battle Text Box"). Lines type out
## one character at a time; a confirm press finishes the line, and a second
## press skips the short hold. Old lines scroll up and out.
##
## Usage:  await text_box.say("Tata attacks!")

signal line_finished

@export var visible_lines := 3
## Keep the finished line on screen this long (seconds). Negative = use UserSettings.
@export var hold_override := -1.0
## Wait for a confirm press after each line (overworld dialogue) in place of the timed hold.
@export var wait_for_confirm := false

var _label: Label
var _history: PackedStringArray = []
var _busy := false


func _ready() -> void:
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.max_lines_visible = visible_lines
	add_child(_label)


func is_busy() -> bool:
	return _busy


func clear() -> void:
	_history.clear()
	_label.text = ""
	_label.lines_skipped = 0


## Shows text at once, with no typing and no waiting (target names, hints).
func show_instant(text: String) -> void:
	clear()
	_label.text = text
	_label.visible_characters = -1


## Types a new line under the previous ones and waits until it has been read.
func say(text: String) -> void:
	_busy = true
	show()
	_history.append(text)
	while _history.size() > visible_lines * 2:
		_history.remove_at(0)
	_label.text = "\n".join(_history)
	_scroll_to_bottom()

	var total := _label.text.length()
	var already_shown := total - text.length() # earlier lines stay fully visible
	var typed := float(already_shown)
	var speed := UserSettings.chars_per_second()
	_label.visible_characters = already_shown
	while _label.visible_characters < total and not is_inf(speed):
		await get_tree().process_frame
		if Input.is_action_just_pressed("confirm"):
			break
		typed += speed * get_process_delta_time()
		_label.visible_characters = mini(int(typed), total)
		_scroll_to_bottom() # the label may have just been laid out
	_label.visible_characters = -1
	_scroll_to_bottom()

	var hold := hold_override if hold_override >= 0.0 else UserSettings.hold_seconds()
	if wait_for_confirm:
		hold = INF
	var waited := 0.0
	while waited < hold:
		await get_tree().process_frame
		if Input.is_action_just_pressed("confirm"):
			break
		waited += get_process_delta_time()
	_busy = false
	line_finished.emit()


func _scroll_to_bottom() -> void:
	if _label.size.x < 8.0:
		return # not laid out yet; the typing loop calls this again next frame
	var skip := maxi(_label.get_line_count() - visible_lines, 0)
	if _label.lines_skipped != skip:
		_label.lines_skipped = skip
