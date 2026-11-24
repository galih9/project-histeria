class_name EnemySprite
extends Control
## An enemy on the front-view battle screen (GDD 03). Shows real SpriteFrames
## when the monster has them, otherwise a placeholder creature.
## The sprite moves on its own (wiggle, hop, dodge); the screen stays still.

const SHADER := preload("res://shaders/battle_sprite.gdshader")
const SHIELD_COLOR := Color("8fe3ff")
const TARGET_GOLD := Color("ffd35f")
const TARGET_OUTLINE := Color("090717")

var battler: Battler

var _visual: Control
var _anim: AnimatedSprite2D
var _material := ShaderMaterial.new()
var _time := 0.0
var _targeted := false
var _wiggle_x := 0.0
var _hop_y := 0.0
var _expression := &"happy"


static func create(target: Battler) -> EnemySprite:
	var sprite := EnemySprite.new()
	sprite.battler = target
	return sprite


func _ready() -> void:
	var sprite_size := Vector2(battler.data.battle_size)
	custom_minimum_size = sprite_size
	size = sprite_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material.shader = SHADER

	_visual = Control.new()
	_visual.size = sprite_size
	_visual.pivot_offset = sprite_size / 2.0
	_visual.material = _material
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.draw.connect(_draw_visual)
	add_child(_visual)

	if battler.data.battle_frames:
		_anim = AnimatedSprite2D.new()
		_anim.sprite_frames = battler.data.battle_frames
		_anim.centered = false
		_anim.use_parent_material = true
		_visual.add_child(_anim)
		_play(&"idle")
	_time = randf() * TAU


func _process(delta: float) -> void:
	_time += delta
	var bob := roundf(sin(_time * 2.2) * 1.0)
	_visual.position = Vector2(roundf(_wiggle_x), bob + roundf(_hop_y))
	if _targeted:
		_visual.modulate = Color(1.18, 1.14, 1.0) if fmod(_time, 0.5) < 0.25 else Color.WHITE
		queue_redraw()
	if battler.has_shield():
		_visual.queue_redraw()


func anchor_point() -> Vector2:
	return get_global_rect().get_center()


func set_targeted(targeted: bool) -> void:
	_targeted = targeted
	_visual.visible = true
	_visual.modulate = Color.WHITE
	queue_redraw()


func _draw() -> void:
	if not _targeted:
		return
	var bob := 1 if fmod(_time, 0.7) >= 0.35 else 0
	var cx := int(floorf(size.x * 0.5))
	var top := -8 + bob
	draw_rect(Rect2(cx - 4, top - 1, 9, 2), TARGET_OUTLINE)
	draw_rect(Rect2(cx - 3, top + 1, 7, 1), TARGET_OUTLINE)
	draw_rect(Rect2(cx - 2, top + 2, 5, 1), TARGET_OUTLINE)
	draw_rect(Rect2(cx - 1, top + 3, 3, 1), TARGET_OUTLINE)
	draw_rect(Rect2(cx, top + 4, 1, 1), TARGET_OUTLINE)
	draw_rect(Rect2(cx - 3, top, 7, 1), TARGET_GOLD)
	draw_rect(Rect2(cx - 2, top + 1, 5, 1), TARGET_GOLD)
	draw_rect(Rect2(cx - 1, top + 2, 3, 1), TARGET_GOLD)
	draw_rect(Rect2(cx, top + 3, 1, 1), TARGET_GOLD)


func refresh() -> void:
	_visual.queue_redraw()


func flash() -> void:
	_material.set_shader_parameter("flash", 1.0)
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: _material.set_shader_parameter("flash", v), 1.0, 0.0, 0.18)


func wiggle() -> void:
	_play(&"hurt")
	_expression = &"surprised"
	_visual.queue_redraw()
	var tween := create_tween()
	for offset: float in [3.0, -3.0, 2.0, -2.0, 0.0]:
		tween.tween_property(self, "_wiggle_x", offset, 0.035)
	tween.tween_callback(_back_to_idle)


func dodge() -> void:
	var tween := create_tween()
	tween.tween_property(self, "_wiggle_x", 10.0, 0.08)
	tween.tween_property(self, "_wiggle_x", 0.0, 0.12)


## Hop toward the camera before an attack.
func lunge() -> void:
	_play(&"attack")
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector2(1.12, 1.12), 0.08)
	tween.parallel().tween_property(self, "_hop_y", -4.0, 0.08)
	tween.tween_property(_visual, "scale", Vector2.ONE, 0.1)
	tween.parallel().tween_property(self, "_hop_y", 0.0, 0.1)
	await tween.finished
	_back_to_idle()


## A small bounce for negotiation replies and taunts.
func react() -> void:
	var tween := create_tween()
	tween.tween_property(self, "_hop_y", -5.0, 0.07)
	tween.tween_property(self, "_hop_y", 0.0, 0.09)
	tween.tween_property(self, "_hop_y", -2.0, 0.05)
	tween.tween_property(self, "_hop_y", 0.0, 0.05)


func dissolve() -> void:
	set_targeted(false)
	flash()
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: _material.set_shader_parameter("dissolve", v), 0.0, 1.0, 0.55)
	await tween.finished
	_visual.hide()


func _back_to_idle() -> void:
	_expression = &"happy"
	_visual.queue_redraw()
	_play(&"idle")


func _play(animation: StringName) -> void:
	if _anim and _anim.sprite_frames.has_animation(animation):
		_anim.play(animation)


func _draw_visual() -> void:
	if _anim == null:
		var rect := Rect2(Vector2.ZERO, _visual.size).grow(-1)
		PlaceholderArt.draw_creature(_visual, rect, battler.data.color, battler.data.placeholder_shape, _expression)
	if battler.has_shield():
		# Shield shimmer for the Flying Stone Thing passive (GDD 02).
		var shimmer := SHIELD_COLOR
		shimmer.a = 0.45 + 0.35 * sin(_time * 6.0)
		_visual.draw_rect(Rect2(Vector2.ZERO, _visual.size), shimmer, false, 1.0)
		_visual.draw_rect(Rect2(Vector2(2, 2), _visual.size - Vector2(4, 4)), Color(shimmer, shimmer.a * 0.5), false, 1.0)
