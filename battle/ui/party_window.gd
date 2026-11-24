class_name PartyWindow
extends Control
## One party member's window (GDD 03): name, HP, MP, pixel bars, and status pips.
## Rises a few pixels on that character's turn, flashes and wiggles when hit,
## darkens when downed. A Shield (Ale's Overheal) shows next to HP.
## HP uses a rolling counter (EarthBound's signature); switch it off with rolling_hp.

const RISE_PIXELS := 6.0
const ROLL_SPEED := 45.0 # HP per second
const DOWN_MODULATE := Color(0.45, 0.42, 0.5)
const LOW_HP_COLOR := Color("ff6e61")
const MID_HP_COLOR := Color("ffd35f")
const FULL_HP_COLOR := Color("6bd96b")
const MP_COLOR := Color("5eb8ff")
const SHIELD_COLOR := Color("8fe3ff")
const BAR_BG := Color("181233")
const BAR_SHADOW := Color("090717")
const TARGET_GOLD := Color("ffd35f")

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
@onready var _shield_label: Label = %ShieldLabel
@onready var _pips: Control = %StatusPips
@onready var _hp_bar: Control = %HpBar
@onready var _mp_bar: Control = %MpBar


func _ready() -> void:
	_pips.draw.connect(_draw_pips)
	_hp_bar.draw.connect(_draw_hp_bar)
	_mp_bar.draw.connect(_draw_mp_bar)


func bind(target: Battler) -> void:
	battler = target
	_name_label.text = battler.window_name()
	_shown_hp = battler.hp
	battler.hp_changed.connect(func(_old: int, _new: int) -> void: _refresh())
	battler.mp_changed.connect(func(_mp: int) -> void: _refresh())
	battler.statuses_changed.connect(_on_statuses_changed)
	battler.shield_changed.connect(func(_shield: int) -> void: _refresh())
	_on_statuses_changed()
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
		_blink = fmod(_blink + delta, 0.7)
		_panel.modulate = Color(1.15, 1.12, 1.0) if _blink < 0.35 else Color.WHITE
		queue_redraw()


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
	_panel.modulate = Color.WHITE
	queue_redraw()


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


func _on_statuses_changed() -> void:
	if battler == null:
		return
	_pips.custom_minimum_size.x = maxi(battler.statuses.size() * 4 - 1, 0) if not battler.statuses.is_empty() else 0
	_pips.queue_redraw()


func _refresh() -> void:
	var hp_shown := ceili(_shown_hp)
	_hp_label.text = "%d" % hp_shown
	_mp_label.text = "%d" % battler.mp
	_shield_label.text = "+%d" % battler.shield if battler.shield > 0 else ""
	var low := battler.hp_ratio() < 0.3
	if low:
		_hp_label.add_theme_color_override("font_color", LOW_HP_COLOR)
	else:
		_hp_label.remove_theme_color_override("font_color")
	var downed := not battler.is_alive() and hp_shown <= 0
	modulate = DOWN_MODULATE if downed else Color.WHITE
	_name_label.text = battler.window_name() + (" " + GameText.text("ui_text.party_window_downed", "DOWN") if downed else "")
	_hp_bar.queue_redraw()
	_mp_bar.queue_redraw()


## Tiny status pips on the right of the header row: one dot per active status.
func _draw_pips() -> void:
	if battler == null:
		return
	var x := _pips.size.x - 3.0
	var y := floorf((_pips.size.y - 3.0) * 0.5)
	for active in battler.statuses:
		_pips.draw_rect(Rect2(x, y, 3, 3), active.data.color)
		x -= 4.0


func _draw_hp_bar() -> void:
	if battler == null:
		return
	var max_hp := maxi(battler.max_hp(), 1)
	var ratio := clampf(_shown_hp / float(max_hp), 0.0, 1.0)
	var col := LOW_HP_COLOR if ratio < 0.3 else (MID_HP_COLOR if ratio < 0.55 else FULL_HP_COLOR)
	_draw_pixel_bar(_hp_bar, ratio, col, battler.shield > 0)


func _draw_mp_bar() -> void:
	if battler == null:
		return
	var max_mp := maxi(battler.max_mp(), 1)
	var ratio := clampf(float(battler.mp) / float(max_mp), 0.0, 1.0)
	_draw_pixel_bar(_mp_bar, ratio, MP_COLOR, false)


func _draw_pixel_bar(bar: Control, ratio: float, fill_color: Color, with_shield: bool) -> void:
	var w := bar.size.x
	if w <= 0.0:
		return
	bar.draw_rect(Rect2(0, 0, w, 2), BAR_BG)
	bar.draw_rect(Rect2(0, 2, w, 1), BAR_SHADOW)
	if ratio > 0.0:
		var fill_w := clampf(roundf(w * ratio), 1.0, w)
		bar.draw_rect(Rect2(0, 0, fill_w, 2), fill_color)
	if with_shield:
		var shield_w := clampf(roundf(w * clampf(float(battler.shield) / float(maxi(battler.max_hp(), 1)), 0.0, 1.0)), 2.0, w)
		bar.draw_rect(Rect2(w - shield_w, 0, shield_w, 2), SHIELD_COLOR)


func _draw() -> void:
	if not _targeted:
		return
	var bob := 1 if _blink >= 0.35 else 0
	var cx := int(floorf(_panel.position.x + _panel.size.x * 0.5))
	var top := int(floorf(_panel.position.y)) - 7 + bob
	draw_rect(Rect2(cx - 4, top - 1, 9, 2), BAR_SHADOW)
	draw_rect(Rect2(cx - 3, top + 1, 7, 1), BAR_SHADOW)
	draw_rect(Rect2(cx - 2, top + 2, 5, 1), BAR_SHADOW)
	draw_rect(Rect2(cx - 1, top + 3, 3, 1), BAR_SHADOW)
	draw_rect(Rect2(cx, top + 4, 1, 1), BAR_SHADOW)
	draw_rect(Rect2(cx - 3, top, 7, 1), TARGET_GOLD)
	draw_rect(Rect2(cx - 2, top + 1, 5, 1), TARGET_GOLD)
	draw_rect(Rect2(cx - 1, top + 2, 3, 1), TARGET_GOLD)
	draw_rect(Rect2(cx, top + 3, 1, 1), TARGET_GOLD)
