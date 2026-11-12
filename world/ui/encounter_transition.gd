class_name EncounterTransition
extends CanvasLayer
## Full-screen swirl into battle and a plain fade out of it (GDD 01).
## The swirl color tells who has the advantage.

const COLORS: Dictionary = {
	EncounterData.Advantage.NEUTRAL: Color("8c66f2"),
	EncounterData.Advantage.PARTY: Color("5ee07a"),
	EncounterData.Advantage.ENEMY: Color("ff4f5e"),
}
const SWIRL_SECONDS := 0.8
const FADE_SECONDS := 0.3

@onready var _rect: ColorRect = %Swirl

var _material: ShaderMaterial


func _ready() -> void:
	_material = _rect.material as ShaderMaterial
	_rect.hide()


## Swirls the screen to black.
func cover_with_swirl(advantage: EncounterData.Advantage) -> void:
	_material.set_shader_parameter("tint", COLORS.get(advantage, COLORS[EncounterData.Advantage.NEUTRAL]))
	_material.set_shader_parameter("progress", 0.0)
	_rect.modulate.a = 1.0
	_rect.show()
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: _material.set_shader_parameter("progress", v), 0.0, 1.0, SWIRL_SECONDS)
	await tween.finished


## Fades the screen to black.
func cover_with_fade() -> void:
	_material.set_shader_parameter("progress", 1.0)
	_rect.modulate.a = 0.0
	_rect.show()
	var tween := create_tween()
	tween.tween_property(_rect, "modulate:a", 1.0, FADE_SECONDS)
	await tween.finished


## Fades the black away again.
func reveal() -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "modulate:a", 0.0, FADE_SECONDS)
	await tween.finished
	_rect.hide()
