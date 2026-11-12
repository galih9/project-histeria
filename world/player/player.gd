class_name Player
extends CharacterBody2D
## The placeholder player box (16x24, Ness size). Free pixel movement with
## 4-way facing (GDD 01, "Movement"). Confirm talks to whatever is in front,
## otherwise it swings: hitting a hologram first gives the party a first strike.

const BODY_SIZE := Vector2(16, 24)

@export var speed := 64.0
@export var swing_seconds := 0.16
@export var swing_cooldown := 0.3
@export var color := Color("f2c94c")
@export var outline := Color("7a5a12")

var facing := Vector2.DOWN
var input_enabled := true

var _swing_time := 0.0
var _cooldown := 0.0
var _invulnerable_time := 0.0
var _walk_time := 0.0

@onready var _swing_area: Area2D = $SwingArea
@onready var _interact_area: Area2D = $InteractArea
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group(&"player")
	_place_front_areas()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_invulnerable_time = maxf(_invulnerable_time - delta, 0.0)
	if _swing_time > 0.0:
		_swing_time = maxf(_swing_time - delta, 0.0)
		_check_swing_hits()

	var direction := Vector2.ZERO
	if input_enabled:
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	if direction != Vector2.ZERO:
		facing = _four_way(direction)
		_place_front_areas()
		_walk_time += delta
	else:
		_walk_time = 0.0
	move_and_slide()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not event.is_action_pressed("confirm"):
		return
	get_viewport().set_input_as_handled()
	if not _try_interact():
		_swing()


func is_swinging() -> bool:
	return _swing_time > 0.0


func is_invulnerable() -> bool:
	return _invulnerable_time > 0.0


func make_invulnerable(seconds: float) -> void:
	_invulnerable_time = seconds


## True when `point` is behind the player (used for the enemy first strike).
func is_behind(point: Vector2) -> bool:
	var to_point := (point - global_position).normalized()
	return to_point.dot(facing) < -0.5


func set_camera_limits(bounds: Rect2i) -> void:
	_camera.limit_left = bounds.position.x
	_camera.limit_top = bounds.position.y
	_camera.limit_right = bounds.end.x
	_camera.limit_bottom = bounds.end.y
	_camera.reset_smoothing()


func _swing() -> void:
	if _cooldown > 0.0:
		return
	_swing_time = swing_seconds
	_cooldown = swing_cooldown
	_check_swing_hits()


func _check_swing_hits() -> void:
	for area in _swing_area.get_overlapping_areas():
		var target := area.get_parent()
		if target is Hologram:
			target.on_struck(self)
			_swing_time = 0.0
			return


func _try_interact() -> bool:
	for area in _interact_area.get_overlapping_areas():
		if area is Interactable:
			area.interact(self)
			return true
	return false


func _place_front_areas() -> void:
	var offset := facing * Vector2(12, 12) + Vector2(0, -8)
	_swing_area.position = offset
	_interact_area.position = offset


func _four_way(direction: Vector2) -> Vector2:
	if absf(direction.x) > absf(direction.y):
		return Vector2(signf(direction.x), 0)
	return Vector2(0, signf(direction.y))


func _draw() -> void:
	# Shadow
	draw_rect(Rect2(-7, -2, 14, 3), Color(0, 0, 0, 0.25))
	if is_invulnerable() and fmod(_invulnerable_time, 0.2) < 0.1:
		return
	var bounce := -1.0 if fmod(_walk_time, 0.3) > 0.15 else 0.0
	var body := Rect2(Vector2(-BODY_SIZE.x / 2.0, -BODY_SIZE.y + bounce), BODY_SIZE)
	draw_rect(body.grow(1), outline)
	draw_rect(body, color)
	# Eyes show the facing direction.
	var eye_y := body.position.y + 7
	var look := facing.x * 3.0
	if facing != Vector2.UP:
		draw_rect(Rect2(-4 + look, eye_y, 2, 3), outline)
		draw_rect(Rect2(2 + look, eye_y, 2, 3), outline)
	if is_swinging():
		var center := facing * 12.0 + Vector2(0, -10)
		draw_arc(center, 8.0, facing.angle() - 1.2, facing.angle() + 1.2, 8, Color.WHITE, 1.0)
