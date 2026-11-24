class_name DevMenu
extends CanvasLayer
## Developer menu for tuning things while the game runs (debug builds only).
## Open it with the DEV button in the top-right corner, F1, or the ` key.
## Close it the same way, or with X / Esc.
##
## Right now it drives the map's Wind: direction, strength and gustiness, plus
## Calm / Breeze / Gale presets, and how thick the grass folds are. The world keeps running while the menu is open,
## so every change shows on the grass live; the player stands still until the
## menu closes. With the menu open, Up/Down picks a slider and Left/Right moves it.
## The Lang button opens the Souls and Electronics languages for the recruit talk.

const COMPASS_POINTS: PackedStringArray = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const INK := Color("f2e8cc")
const GOLD := Color("ffd35f")
const NIGHT := Color("100d26")
const DUSK := Color("24184a")
## Thinnest folds, as a share of the Fold slider (the thickest folds).
const FOLD_MIN_SHARE := 0.4

var _button: Button
var _panel: PanelContainer
var _compass: Control
var _note: Label
var _direction: HSlider
var _strength: HSlider
var _gustiness: HSlider
var _fold: HSlider
var _direction_value: Label
var _strength_value: Label
var _gustiness_value: Label
var _fold_value: Label
var _languages: Button
var _player_input_before := true


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.hide()


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func open() -> void:
	_panel.show()
	_sync_from_wind()
	var player := _player()
	if player:
		_player_input_before = player.input_enabled
		player.input_enabled = false
	_direction.grab_focus()


func close() -> void:
	_panel.hide()
	get_viewport().gui_release_focus()
	var player := _player()
	if player:
		player.input_enabled = _player_input_before


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode in [KEY_F1, KEY_QUOTELEFT]:
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open() and (event.is_action_pressed("cancel") or event.is_action_pressed("menu")):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if is_open():
		_sync_from_wind()
		_compass.queue_redraw()


# --- Wind -------------------------------------------------------------------

func _sync_from_wind() -> void:
	var fold_max := _fold_thickness().y
	_fold.set_value_no_signal(fold_max)
	_fold_value.text = "%d px" % roundi(fold_max)
	var wind := Wind.current
	var has_wind := is_instance_valid(wind)
	for slider in [_direction, _strength, _gustiness]:
		slider.editable = has_wind
	_note.visible = not has_wind
	if not has_wind:
		return
	_direction.set_value_no_signal(wind.direction_degrees)
	_strength.set_value_no_signal(wind.strength)
	_gustiness.set_value_no_signal(wind.gustiness)
	_direction_value.text = "%d° %s" % [roundi(wind.direction_degrees), _compass_point(wind.direction_degrees)]
	_strength_value.text = "%d%%" % roundi(wind.strength * 100.0)
	_gustiness_value.text = "%.2f" % wind.gustiness


func _on_direction_changed(value: float) -> void:
	if is_instance_valid(Wind.current):
		Wind.current.blow(value, Wind.current.strength, 0.0)
		_sync_from_wind()


func _on_strength_changed(value: float) -> void:
	if is_instance_valid(Wind.current):
		Wind.current.blow(Wind.current.direction_degrees, value, 0.0)
		_sync_from_wind()


func _on_gustiness_changed(value: float) -> void:
	if is_instance_valid(Wind.current):
		Wind.current.gustiness = value
		_sync_from_wind()


## Sets the widest point of the thickest grass folds; the thinnest scale along.
func _on_fold_changed(value: float) -> void:
	var thinnest := maxf(1.0, roundf(value * FOLD_MIN_SHARE))
	Wind.STREAK_MATERIAL.set_shader_parameter(&"thickness_px", Vector2(thinnest, value))
	_sync_from_wind()


## (thinnest, thickest) fold thickness in px, read from the fold material.
func _fold_thickness() -> Vector2:
	var value: Variant = Wind.STREAK_MATERIAL.get_shader_parameter(&"thickness_px")
	if value is Vector2:
		return value
	return Vector2(3.0, 8.0)  # the shader's default


func _apply_preset(new_strength: float, new_gustiness: float) -> void:
	var wind := Wind.current
	if not is_instance_valid(wind):
		return
	wind.gustiness = new_gustiness
	wind.blow(wind.direction_degrees, new_strength, 1.5)


# --- Recruit talk -------------------------------------------------------------

func _toggle_languages() -> void:
	GameState.dev_all_languages = not GameState.dev_all_languages
	_update_languages_label()


func _update_languages_label() -> void:
	_languages.text = "Lang: all open" if GameState.dev_all_languages else "Lang: as in game"


func _compass_point(degrees: float) -> String:
	return COMPASS_POINTS[posmod(roundi(degrees / 45.0), 8)]


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


# --- Building the UI ----------------------------------------------------------

func _build() -> void:
	_button = _make_button("DEV")
	_button.position = Vector2(369, 3)
	_button.pressed.connect(toggle)
	add_child(_button)

	_panel = PanelContainer.new()
	_panel.position = Vector2(244, 19)
	_panel.custom_minimum_size = Vector2(152, 0)
	add_child(_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 1)
	_panel.add_child(rows)

	var header := HBoxContainer.new()
	rows.add_child(header)
	var title := Label.new()
	title.text = "WIND"
	title.add_theme_color_override("font_color", GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_compass = Control.new()
	_compass.custom_minimum_size = Vector2(15, 15)
	_compass.draw.connect(_draw_compass)
	header.add_child(_compass)

	_note = Label.new()
	_note.text = "This scene has no Wind node."
	rows.add_child(_note)

	var dir_row := _add_slider_row(rows, "Dir", 0.0, 359.0, 1.0, 15.0)
	_direction = dir_row[0]
	_direction_value = dir_row[1]
	_direction.value_changed.connect(_on_direction_changed)

	var strength_row := _add_slider_row(rows, "Power", 0.0, 1.0, 0.01, 0.05)
	_strength = strength_row[0]
	_strength_value = strength_row[1]
	_strength.value_changed.connect(_on_strength_changed)

	var gust_row := _add_slider_row(rows, "Gusts", 0.0, 2.0, 0.05, 0.1)
	_gustiness = gust_row[0]
	_gustiness_value = gust_row[1]
	_gustiness.value_changed.connect(_on_gustiness_changed)

	var fold_row := _add_slider_row(rows, "Fold", 1.0, 12.0, 1.0, 1.0)
	_fold = fold_row[0]
	_fold_value = fold_row[1]
	_fold.value_changed.connect(_on_fold_changed)

	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 3)
	rows.add_child(presets)
	for preset: Array in [["Calm", 0.0, 0.5], ["Breeze", 0.6, 1.0], ["Gale", 1.0, 1.8]]:
		var b := _make_button(preset[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_apply_preset.bind(preset[1], preset[2]))
		presets.add_child(b)

	_languages = _make_button("")
	_languages.pressed.connect(_toggle_languages)
	rows.add_child(_languages)
	_update_languages_label()

	# Up/Down walks between the sliders (and wraps around).
	var order: Array[HSlider] = [_direction, _strength, _gustiness, _fold]
	for i in order.size():
		var slider := order[i]
		slider.focus_neighbor_top = slider.get_path_to(order[i - 1])
		slider.focus_neighbor_bottom = slider.get_path_to(order[(i + 1) % order.size()])


func _on_slider_key(event: InputEvent, slider: HSlider, key_step: float) -> void:
	var direction := 0.0
	if event.is_action_pressed("ui_left", true):
		direction = -1.0
	elif event.is_action_pressed("ui_right", true):
		direction = 1.0
	if direction != 0.0:
		slider.value += direction * key_step
		slider.accept_event()


## Returns [HSlider, value Label].
func _add_slider_row(parent: Container, label_text: String, min_value: float, max_value: float,
		step: float, key_step: float) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(30, 0)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	# Left/Right on a focused slider moves by key_step instead of the fine drag step.
	slider.gui_input.connect(_on_slider_key.bind(slider, key_step))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, 9)
	_style_slider(slider)
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(36, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	return [slider, value_label]


func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _box(NIGHT, INK))
	b.add_theme_stylebox_override("hover", _box(DUSK, GOLD))
	b.add_theme_stylebox_override("pressed", _box(DUSK, GOLD))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	return b


func _style_slider(slider: HSlider) -> void:
	var track := _box(NIGHT, INK)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.anti_aliasing = false
	fill.content_margin_top = 2
	fill.content_margin_bottom = 2
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_icon_override("grabber", _grabber_icon(INK))
	slider.add_theme_icon_override("grabber_highlight", _grabber_icon(GOLD))
	slider.add_theme_icon_override("grabber_disabled", _grabber_icon(Color("6b6580")))
	slider.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), GOLD))


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.content_margin_left = 3
	box.content_margin_right = 3
	box.content_margin_top = 0
	box.content_margin_bottom = 1
	box.anti_aliasing = false
	return box


func _grabber_icon(color: Color) -> ImageTexture:
	var image := Image.create_empty(3, 9, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


## Arrow showing where the wind blows right now (drift included); longer = stronger.
func _draw_compass() -> void:
	var area := Rect2(Vector2.ZERO, _compass.size)
	_compass.draw_rect(area, NIGHT)
	_compass.draw_rect(area, INK, false, 1.0)
	var center := (area.size / 2.0).floor() + Vector2(0.5, 0.5)
	var reach := lerpf(2.0, 6.0, Wind.get_strength())
	var tip := center + Wind.get_direction() * reach
	_compass.draw_line(center, tip, GOLD, 1.0, false)
	_compass.draw_rect(Rect2(tip.floor(), Vector2.ONE), INK)
