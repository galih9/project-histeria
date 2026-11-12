class_name PlaceholderArt
extends RefCounted
## Draws goofy placeholder creatures with plain shapes until real pixel art
## arrives. Soft colored outlines in place of black, like the GDD's color rule.

const EYE_WHITE := Color("f6f1e3")
const PUPIL := Color("2b2141")


static func outline_color(base: Color) -> Color:
	return base.darkened(0.55)


static func draw_creature(canvas: CanvasItem, rect: Rect2, base: Color,
		shape: CombatantData.PlaceholderShape, expression := &"happy") -> void:
	var body := _shape_points(rect, shape)
	canvas.draw_colored_polygon(_shape_points(rect.grow(1), shape), outline_color(base))
	canvas.draw_colored_polygon(body, base)
	# Simple top-left highlight band.
	var shine := Rect2(rect.position + rect.size * Vector2(0.18, 0.12), rect.size * Vector2(0.22, 0.08))
	if shape == CombatantData.PlaceholderShape.BOX:
		canvas.draw_rect(shine, base.lightened(0.35))
	draw_face(canvas, rect, expression)


static func draw_face(canvas: CanvasItem, rect: Rect2, expression: StringName) -> void:
	var unit := maxf(floorf(minf(rect.size.x, rect.size.y) / 10.0), 1.0)
	var center := rect.get_center()
	var eye_y := floorf(rect.position.y + rect.size.y * 0.38)
	var eye_dx := floorf(rect.size.x * 0.2)
	var eye_r := maxf(unit * 1.2, 1.0)
	for side: float in [-1.0, 1.0]:
		var eye := Vector2(floorf(center.x + side * eye_dx), eye_y)
		match expression:
			&"smug":
				canvas.draw_rect(Rect2(eye - Vector2(eye_r, 0), Vector2(eye_r * 2, maxf(unit * 0.6, 1))), PUPIL)
			&"surprised":
				canvas.draw_circle(eye, eye_r + unit * 0.4, EYE_WHITE)
				canvas.draw_circle(eye, maxf(eye_r * 0.4, 1.0), PUPIL)
			_:
				canvas.draw_circle(eye, eye_r, EYE_WHITE)
				canvas.draw_circle(eye + Vector2(0, unit * 0.3), maxf(eye_r * 0.55, 1.0), PUPIL)
		if expression == &"worried":
			var brow := eye + Vector2(0, -eye_r - unit)
			canvas.draw_line(brow + Vector2(-side * eye_r, -unit * 0.6), brow + Vector2(side * eye_r, unit * 0.4), PUPIL, maxf(unit * 0.5, 1.0))

	var mouth_y := floorf(rect.position.y + rect.size.y * 0.62)
	var mouth_w := floorf(rect.size.x * 0.22)
	var thickness := maxf(unit * 0.6, 1.0)
	match expression:
		&"happy":
			canvas.draw_polyline(_arc(Vector2(center.x, mouth_y - unit), mouth_w, 0.0, PI), PUPIL, thickness)
		&"worried":
			canvas.draw_polyline(_arc(Vector2(center.x, mouth_y + unit), mouth_w * 0.8, PI, TAU), PUPIL, thickness)
		&"surprised":
			canvas.draw_circle(Vector2(center.x, mouth_y), maxf(unit * 1.4, 1.5), PUPIL)
		&"smug":
			canvas.draw_line(Vector2(center.x - mouth_w, mouth_y), Vector2(center.x + mouth_w, mouth_y - unit * 1.5), PUPIL, thickness)
		_:
			canvas.draw_line(Vector2(center.x - mouth_w * 0.7, mouth_y), Vector2(center.x + mouth_w * 0.7, mouth_y), PUPIL, thickness)


static func _shape_points(rect: Rect2, shape: CombatantData.PlaceholderShape) -> PackedVector2Array:
	match shape:
		CombatantData.PlaceholderShape.ROUND:
			return _ellipse(rect, 24)
		CombatantData.PlaceholderShape.DIAMOND:
			var c := rect.get_center()
			return PackedVector2Array([
				Vector2(c.x, rect.position.y), Vector2(rect.end.x, c.y),
				Vector2(c.x, rect.end.y), Vector2(rect.position.x, c.y)])
		CombatantData.PlaceholderShape.BLOB:
			var points := _ellipse(Rect2(rect.position + Vector2(0, rect.size.y * 0.15), rect.size * Vector2(1, 0.85)), 28)
			return points
		_:
			return PackedVector2Array([
				rect.position, Vector2(rect.end.x, rect.position.y),
				rect.end, Vector2(rect.position.x, rect.end.y)])


static func _ellipse(rect: Rect2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var center := rect.get_center()
	var radius := rect.size / 2.0
	for i in segments:
		var angle := TAU * i / segments
		points.append((center + Vector2(cos(angle), sin(angle)) * radius).floor())
	return points


static func _arc(center: Vector2, radius: float, from: float, to: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 9:
		var angle := lerpf(from, to, i / 8.0)
		points.append((center + Vector2(cos(angle), sin(angle)) * Vector2(radius, radius * 0.6)).floor())
	return points
