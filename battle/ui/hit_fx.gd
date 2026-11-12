class_name HitFx
extends Node2D
## Short pixel hit effects drawn in code: blunt burst, slashes, magic ring,
## poison bubbles. Placeholders for the effect sprites in GDD 02's asset list.
## Runs on scaled time, so hit-stop freezes it too.

const DURATION := 0.28
const COLORS: Dictionary = {
	DamageEffect.HitFx.BLUNT: Color("fff2b0"),
	DamageEffect.HitFx.SLASH: Color("ffffff"),
	DamageEffect.HitFx.MAGIC: Color("b98cff"),
	DamageEffect.HitFx.POISON: Color("8be36b"),
}

var kind := DamageEffect.HitFx.BLUNT
var big := false
var _t := 0.0


static func spawn(parent: Node, at: Vector2, fx_kind: DamageEffect.HitFx, critical := false) -> HitFx:
	var fx := HitFx.new()
	fx.kind = fx_kind
	fx.big = critical
	fx.position = at.round()
	parent.add_child(fx)
	return fx


func _process(delta: float) -> void:
	_t += delta / DURATION
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var color: Color = COLORS.get(kind, Color.WHITE)
	color.a = 1.0 - _t * _t
	var scale_factor := 1.6 if big else 1.0
	var reach := (6.0 + 14.0 * _t) * scale_factor
	match kind:
		DamageEffect.HitFx.SLASH:
			for i in 3:
				var offset := Vector2(-6 + i * 6, 0) * scale_factor
				var from := offset + Vector2(-reach, -reach) * 0.7
				var to := offset + Vector2(reach, reach) * 0.7
				draw_line(from.round(), to.round(), color, 1.0)
		DamageEffect.HitFx.MAGIC:
			draw_arc(Vector2.ZERO, reach, 0.0, TAU, 20, color, 1.0)
			for i in 6:
				var angle := TAU * i / 6.0 + _t * 2.0
				draw_rect(Rect2((Vector2(cos(angle), sin(angle)) * reach * 1.2).round(), Vector2(2, 2)), color)
		DamageEffect.HitFx.POISON:
			for i in 5:
				var x := (i - 2) * 6.0 * scale_factor
				var y := -reach * (0.5 + 0.15 * i)
				draw_circle(Vector2(x, y).round(), 2.0 + (i % 2), color)
		_:
			for i in 8:
				var angle := TAU * i / 8.0
				var direction := Vector2(cos(angle), sin(angle))
				draw_line((direction * reach * 0.4).round(), (direction * reach).round(), color, 1.0)
			draw_circle(Vector2.ZERO, 3.0 * scale_factor * (1.0 - _t), color)
