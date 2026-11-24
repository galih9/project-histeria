class_name TextBox
extends PanelContainer
## EarthBound-style text window (GDD 03, "Battle Text Box"). Lines type out
## one character at a time; a confirm press finishes the line, and a second
## press skips the short hold. Old lines scroll up and out.
##
## Usage:  await text_box.say("Bo attacks!")

signal line_finished

const PROMPT_GOLD := Color("ffd35f")
const PROMPT_OUTLINE := Color("090717")

@export var visible_lines := 3
## Keep the finished line on screen this long (seconds). Negative = use UserSettings.
@export var hold_override := -1.0
## Wait for a confirm press after each line (overworld dialogue) in place of the timed hold.
@export var wait_for_confirm := false

var _label: Label
var _prompt: Control
var _history: PackedStringArray = []
var _busy := false
var _waiting_confirm := false
var _prompt_time := 0.0


func _ready() -> void:
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.max_lines_visible = visible_lines
	add_child(_label)

	_prompt = Control.new()
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prompt.draw.connect(_draw_prompt)
	add_child(_prompt)


func _process(delta: float) -> void:
	if _waiting_confirm:
		_prompt_time = fmod(_prompt_time + delta, 0.7)
		_prompt.queue_redraw()


func is_busy() -> bool:
	return _busy


func clear() -> void:
	_waiting_confirm = false
	_prompt.queue_redraw()
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
	_waiting_confirm = false
	_prompt.queue_redraw()
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
		_waiting_confirm = true
		_prompt_time = 0.0
		_prompt.queue_redraw()
	var waited := 0.0
	while waited < hold:
		await get_tree().process_frame
		if Input.is_action_just_pressed("confirm"):
			break
		waited += get_process_delta_time()
	_waiting_confirm = false
	_prompt.queue_redraw()
	_busy = false
	line_finished.emit()


func _scroll_to_bottom() -> void:
	if _label.size.x < 8.0:
		return # not laid out yet; the typing loop calls this again next frame
	var skip := maxi(_label.get_line_count() - visible_lines, 0)
	if _label.lines_skipped != skip:
		_label.lines_skipped = skip


func _draw_prompt() -> void:
	if not _waiting_confirm:
		return
	var bob := 1 if _prompt_time >= 0.35 else 0
	var cx := int(floorf(_prompt.size.x)) - 4
	var top := int(floorf(_prompt.size.y)) - 4 + bob
	# 1px dark outline behind a 5x3 golden down arrow
	_prompt.draw_rect(Rect2(cx - 3, top - 1, 7, 2), PROMPT_OUTLINE)
	_prompt.draw_rect(Rect2(cx - 2, top + 1, 5, 1), PROMPT_OUTLINE)
	_prompt.draw_rect(Rect2(cx - 1, top + 2, 3, 1), PROMPT_OUTLINE)
	_prompt.draw_rect(Rect2(cx, top + 3, 1, 1), PROMPT_OUTLINE)
	# Crisp 5x3 gold arrow
	_prompt.draw_rect(Rect2(cx - 2, top, 5, 1), PROMPT_GOLD)
	_prompt.draw_rect(Rect2(cx - 1, top + 1, 3, 1), PROMPT_GOLD)
	_prompt.draw_rect(Rect2(cx, top + 2, 1, 1), PROMPT_GOLD)
