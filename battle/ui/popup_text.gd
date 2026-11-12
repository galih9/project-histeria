class_name PopupText
extends Label
## Pixel text that floats up and fades: damage numbers, "LUCKY!", "MISS".

const RISE := 12.0
const DURATION := 0.8


static func spawn(parent: Node, text_value: String, at: Vector2, tint: Color) -> PopupText:
	var popup := PopupText.new()
	popup.text = text_value
	popup.add_theme_color_override("font_color", tint)
	popup.add_theme_color_override("font_outline_color", Color("1a1330"))
	popup.add_theme_constant_override("outline_size", 2)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(popup)
	popup.position = (at - popup.get_minimum_size() / 2.0).round()
	popup._animate()
	return popup


func _animate() -> void:
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - RISE, DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(self, "modulate:a", 0.0, DURATION * 0.4).set_delay(DURATION * 0.6)
	tween.tween_callback(queue_free)
