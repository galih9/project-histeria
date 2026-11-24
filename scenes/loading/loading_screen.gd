class_name LoadingScreen
extends Control
## Shown by SceneRouter while the next scene streams in. Shows a progress bar,
## a bouncing placeholder box and a tip from game_text.json.

@onready var _bar: ProgressBar = %Bar
@onready var _tip: Label = %Tip
@onready var _box: Control = %Box
@onready var _title: Label = %Title

var _time := 0.0


func _ready() -> void:
	var tips := GameText.lines("boot_and_title.loading_tips")
	_tip.text = tips[randi() % tips.size()] if not tips.is_empty() else ""
	_title.text = GameText.text("boot_and_title.loading.label", _title.text)
	_box.draw.connect(_draw_box)


func _process(delta: float) -> void:
	_time += delta
	_box.position.y = -absf(sin(_time * 6.0)) * 10.0
	_box.queue_redraw()


func set_progress(value: float) -> void:
	if _bar:
		_bar.value = clampf(value, 0.0, 1.0) * 100.0


func _draw_box() -> void:
	var squash := 1.0 - 0.15 * clampf(1.0 - absf(sin(_time * 6.0)) * 4.0, 0.0, 1.0)
	var box_size := Vector2(16, 24 * squash)
	var rect := Rect2(Vector2(0, 24 - box_size.y), box_size)
	PlaceholderArt.draw_creature(_box, rect, Color("f2c94c"), CombatantData.PlaceholderShape.BOX, &"happy")
