class_name PartyWindow
extends Control
## One party member's window (GDD 03): name, HP and MP only. Rises a few pixels
## on that character's turn, flashes and wiggles when hit, darkens on KO.
## HP uses a rolling counter (EarthBound's signature); switch it off with rolling_hp.

const RISE_PIXELS := 6.0
const ROLL_SPEED := 45.0 # HP per second
const KO_MODULATE := Color(0.45, 0.42, 0.5)
const LOW_HP_COLOR := Color("ff8f61")

@export var rolling_hp := true

var battler: Battler
var _shown_hp := 0.0
var _active := false
var _targeted := false
var _blink := 0.0

@onready var _panel: PanelContainer = %Panel
@onready var _name_label: Label = %NameLabel
@onready var _hp_label: Label = %HpLabel
@onready var _mp_label: Label = %MpLabel
@onready var _pips: Control = %StatusPips


func _ready() -> void:
	_pips.draw.connect(_draw_pips)


func bind(target: Battler) -> void:
	battler = target
	_name_label.text = battler.window_name()
	_shown_hp = battler.hp
	battler.hp_changed.connect(func(_old: int, _new: int) -> void: _refresh())
	battler.mp_changed.connect(func(_mp: int) -> void: _refresh())
	battler.statuses_changed.connect(_pips.queue_redraw)
	_refresh()


func _process(delta: float) -> void:
	if battler == null:
		return
	if not is_equal_approx(_shown_hp, battler.hp):
		if rolling_hp:
			_shown_hp = move_toward(_shown_hp, battler.hp, ROLL_SPEED * delta)
		else:
			_shown_hp = battler.hp
		_refresh()
	if _targeted:
		_blink = fmod(_blink + delta, 0.4)
		_panel.modulate.a = 1.0 if _blink < 0.25 else 0.55


func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	_panel.theme_type_variation = &"PartyPanelActive" if active else &"PartyPanel"
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", -RISE_PIXELS if active else 0.0, 0.08)


func set_targeted(targeted: bool) -> void:
	_targeted = targeted
	_blink = 0.0
	_panel.modulate.a = 1.0


func play_hit() -> void:
	var tween := create_tween()
	_panel.self_modulate = Color(3, 3, 3)
	tween.tween_property(_panel, "self_modulate", Color.WHITE, 0.15)
	var wiggle := create_tween()
	for offset: float in [2.0, -2.0, 1.0, 0.0]:
		wiggle.tween_property(_panel, "position:x", offset, 0.03)


func anchor_point() -> Vector2:
	return _panel.get_global_rect().get_center()


func top_center() -> Vector2:
	var rect := _panel.get_global_rect()
	return Vector2(rect.get_center().x, rect.position.y)


func _refresh() -> void:
	var hp_shown := ceili(_shown_hp)
	_hp_label.text = "HP %3d" % hp_shown
	_mp_label.text = "MP %3d" % battler.mp
	var low := battler.hp_ratio() < 0.3
	if low:
		_hp_label.add_theme_color_override("font_color", LOW_HP_COLOR)
	else:
		_hp_label.remove_theme_color_override("font_color")
	var knocked_out := not battler.is_alive() and hp_shown <= 0
	modulate = KO_MODULATE if knocked_out else Color.WHITE
	_name_label.text = battler.window_name() + (" KO" if knocked_out else "")


## Tiny status pips in the corner (GDD 03 proposal): one dot per active status.
func _draw_pips() -> void:
	if battler == null:
		return
	var x := _pips.size.x - 3.0
	for active in battler.statuses:
		_pips.draw_rect(Rect2(x - 1, 0, 3, 3), active.data.color)
		x -= 4.0
