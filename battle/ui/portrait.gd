class_name Portrait
extends Control
## 32x32 character portrait with an expression (GDD 03). Uses the character's
## portrait_frames when present, otherwise a placeholder face.

const SIZE := Vector2(32, 32)

var _data: CombatantData
var _expression := &"neutral"
var _sprite: AnimatedSprite2D


func _ready() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_face(data: CombatantData, expression: StringName) -> void:
	_data = data
	_expression = expression
	if data.portrait_frames and data.portrait_frames.has_animation(expression):
		if _sprite == null:
			_sprite = AnimatedSprite2D.new()
			_sprite.centered = false
			add_child(_sprite)
		_sprite.sprite_frames = data.portrait_frames
		_sprite.play(expression)
		_sprite.show()
	elif _sprite:
		_sprite.hide()
	queue_redraw()


func _draw() -> void:
	if _data == null or (_sprite and _sprite.visible):
		return
	var frame := Rect2(Vector2.ZERO, SIZE)
	draw_rect(frame, _data.color.darkened(0.6))
	PlaceholderArt.draw_creature(self, frame.grow(-4), _data.color, CombatantData.PlaceholderShape.BOX, _expression)
