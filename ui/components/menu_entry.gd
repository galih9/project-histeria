class_name MenuEntry
extends RefCounted
## One row of a MenuList.

var text: String
## Small text on the right (MP cost, item count).
var right_text: String
var color: Color
var disabled: bool
## Anything the caller wants back when this row is picked.
var payload: Variant


func _init(label: String, value: Variant = null, right := "", is_disabled := false, tint := Color(0, 0, 0, 0)) -> void:
	text = label
	payload = value
	right_text = right
	disabled = is_disabled
	color = tint


func has_color() -> bool:
	return color.a > 0.0
