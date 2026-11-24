class_name DialogueBubble
extends PanelContainer
## Raider lines in battle (GDD 03): a self thought above the active character's
## window, or party dialogue at the side of the screen. Closes on its own and
## waits for the battle text to finish typing before it appears.

const SHOW_SECONDS := 2.6
## Conversation lines stay up for a time that grows with their length.
const CONVERSATION_MIN_SECONDS := 1.6
const CONVERSATION_SECONDS_PER_CHAR := 0.045
const TEXT_WIDTH := 120.0
const SCREEN_MARGIN := 4.0

var _portrait: Portrait
var _label: Label
var _priority := 0
var _serial := 0
var _locked := false


func _ready() -> void:
	theme_type_variation = &"ThoughtPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	add_child(row)
	_portrait = Portrait.new()
	row.add_child(_portrait)
	_label = Label.new()
	_label.theme_type_variation = &"ThoughtLabel"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = TEXT_WIDTH
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_label)
	hide()


## anchor: for thoughts, the top center of the speaker's party window.
## `in_conversation` keeps the line up when a new action closes single lines.
func present(speaker: Battler, text: String, expression: StringName, as_thought: bool,
		anchor: Vector2, priority: int, text_box: TextBox, in_conversation := false) -> void:
	if visible and priority < _priority:
		return
	_locked = in_conversation
	_serial += 1
	var serial := _serial
	_priority = priority
	while text_box.is_busy():
		await text_box.line_finished
	if serial != _serial:
		return

	_portrait.show_face(speaker.data, expression)
	_label.text = ("(%s)" % text) if as_thought else text
	reset_size()
	var screen := get_viewport_rect().size
	var bubble_size := get_combined_minimum_size()
	var target: Vector2
	if as_thought:
		target = Vector2(anchor.x - bubble_size.x / 2.0, anchor.y - bubble_size.y - 10.0)
	else:
		target = Vector2(screen.x - bubble_size.x - SCREEN_MARGIN, 84.0)
	position = target.clamp(Vector2.ONE * SCREEN_MARGIN, screen - bubble_size - Vector2.ONE * SCREEN_MARGIN).round()
	modulate.a = 0.0
	show()
	create_tween().tween_property(self, "modulate:a", 1.0, 0.1)

	var seconds := SHOW_SECONDS
	if in_conversation:
		seconds = maxf(CONVERSATION_MIN_SECONDS, 0.9 + text.length() * CONVERSATION_SECONDS_PER_CHAR)
	await get_tree().create_timer(seconds, true, false, true).timeout
	if serial == _serial:
		dismiss(true)


func dismiss(force := false) -> void:
	if _locked and not force:
		return
	_locked = false
	_serial += 1
	_priority = 0
	hide()
