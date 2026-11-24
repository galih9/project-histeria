extends Control
## Splash screen: fades the logo in and out, then goes to the title menu.
## Any confirm or cancel press skips it.

const NEXT_SCENE := "res://scenes/menu/main_menu.tscn"
const FADE_SECONDS := 0.6
const HOLD_SECONDS := 1.4

@onready var _content: Control = %Content

var _leaving := false


func _ready() -> void:
	var labels := _content.get_children()
	var texts := GameText.lines("boot_and_title.splash")
	for i in mini(labels.size(), texts.size()):
		(labels[i] as Label).text = texts[i]
	_content.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_content, "modulate:a", 1.0, FADE_SECONDS)
	tween.tween_interval(HOLD_SECONDS)
	tween.tween_property(_content, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(_leave)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm") or event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	SceneRouter.change_scene(NEXT_SCENE)
