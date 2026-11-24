class_name BattleView
extends Control
## Everything the player sees in battle (GDD 03): animated background, enemy
## sprites in the center, text box and menus at the top, party windows at the
## bottom. It reads Battler signals and plays effects; it holds no rules.

const PARTY_WINDOW := preload("res://battle/ui/party_window.tscn")
const ENEMY_BASELINE := 164.0
const ENEMY_GAP := 8.0
const DAMAGE_COLOR := Color("fff2b0")
const HEAL_COLOR := Color("8be36b")
const MP_COLOR := Color("7ec8ff")
const MISS_COLOR := Color("c9c3d9")
const LUCKY_COLOR := Color("ffd84a")
const MOOD_COLOR := Color("ff7a6b")
const COIN_COLOR := Color("ffe08a")
## Recruit talk answer list: under the text box, at the left.
const ANSWER_LIST_POSITION := Vector2(6, 58)
const ANSWER_LIST_WIDTH := 200.0

## Every battle text line, for logs and tests.
signal narrated(text: String)
signal _target_input(command: StringName)

@onready var text_box: TextBox = %TextBox
@onready var command_menu: CommandMenu = %CommandMenu
@onready var _background: ColorRect = %Background
@onready var _enemy_layer: Control = %Enemies
@onready var _fx_layer: Control = %Fx
@onready var _party_hud: HBoxContainer = %PartyHud
@onready var _dialogue: DialogueBubble = %Dialogue

var _enemy_sprites: Dictionary = {} # Battler -> EnemySprite
var _party_windows: Dictionary = {} # Battler -> PartyWindow
var _selecting := false
var _answer_list: MenuList


func setup(ctx: BattleContext) -> void:
	command_menu.bind_view(self)
	var preset := ctx.encounter.background if ctx.encounter.background else BattleBackgroundPreset.new()
	preset.apply_to(_background.material as ShaderMaterial)
	for battler in ctx.enemies():
		_add_enemy_sprite(battler)
	_layout_enemies(false)
	for battler in ctx.party(false):
		_add_party_window(battler)
	_build_answer_list()
	text_box.clear()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# --- Text and turn -----------------------------------------------------------

func say(text: String) -> void:
	narrated.emit(text)
	text_box.show()
	await text_box.say(text)


func clear_text() -> void:
	text_box.clear()


func set_active(actor: Battler) -> void:
	for battler: Battler in _party_windows:
		_party_windows[battler].set_active(battler == actor)


## Shows one Raider line. With `wait`, returns once the line has closed
## (conversations play their lines one after another).
func show_dialogue(speaker: Battler, text: String, expression: StringName, as_thought: bool,
		priority: int, wait := false) -> void:
	var anchor := Vector2(size.x / 2.0, 150.0)
	if _party_windows.has(speaker):
		anchor = _party_windows[speaker].top_center()
	if wait:
		await _dialogue.present(speaker, text, expression, as_thought, anchor, priority, text_box, true)
	else:
		_dialogue.present(speaker, text, expression, as_thought, anchor, priority, text_box)


## A new action closes a single line; `force` also ends a conversation line.
func dismiss_dialogue(force := false) -> void:
	_dialogue.dismiss(force)


# --- Recruit talk -------------------------------------------------------------

## Shows the answers under the question in the text box and waits for a pick.
## The talk always needs an answer, so Cancel does nothing here.
func choose_answer(answers: Array[String]) -> int:
	var entries: Array[MenuEntry] = []
	for answer in answers:
		entries.append(MenuEntry.new(answer))
	text_box.show()
	_answer_list.reset_size.call_deferred() # fit 2 or 3 answers
	var index := -1
	while index < 0:
		index = await _answer_list.choose(entries)
	return index


func _build_answer_list() -> void:
	if _answer_list:
		return
	_answer_list = MenuList.new()
	_answer_list.add_cancel_entry = false
	_answer_list.allow_cancel = false
	_answer_list.max_visible_rows = 3
	_answer_list.custom_minimum_size = Vector2(ANSWER_LIST_WIDTH, 0)
	_answer_list.position = ANSWER_LIST_POSITION
	add_child(_answer_list)


# --- Target selection --------------------------------------------------------

## Moves a cursor over the candidates. Returns the picked battlers, or an empty
## array when the player cancels. With all_at_once, every candidate is picked.
func select_targets(candidates: Array[Battler], all_at_once: bool) -> Array[Battler]:
	var result: Array[Battler] = []
	if candidates.is_empty():
		return result
	var menu_was_visible := command_menu.visible
	command_menu.hide()
	text_box.show()
	var index := 0
	_selecting = true
	while true:
		_highlight(candidates, index, all_at_once)
		text_box.show_instant(_target_caption(candidates, index, all_at_once))
		var command: StringName = await _target_input
		match command:
			&"next":
				index = wrapi(index + 1, 0, candidates.size())
			&"previous":
				index = wrapi(index - 1, 0, candidates.size())
			&"confirm":
				if all_at_once:
					result.assign(candidates)
				else:
					result.append(candidates[index])
				break
			&"cancel":
				break
	_selecting = false
	_highlight([], -1, false)
	text_box.clear()
	command_menu.visible = menu_was_visible
	if menu_was_visible:
		text_box.hide()
	return result


func _unhandled_input(event: InputEvent) -> void:
	if not _selecting:
		return
	var command := &""
	if event.is_action_pressed("move_right", true) or event.is_action_pressed("move_down", true):
		command = &"next"
	elif event.is_action_pressed("move_left", true) or event.is_action_pressed("move_up", true):
		command = &"previous"
	elif event.is_action_pressed("confirm"):
		command = &"confirm"
	elif event.is_action_pressed("cancel"):
		command = &"cancel"
	if command != &"":
		get_viewport().set_input_as_handled()
		_target_input.emit(command)


func _highlight(candidates: Array, index: int, all_at_once: bool) -> void:
	for battler: Battler in _enemy_sprites:
		_enemy_sprites[battler].set_targeted(false)
	for battler: Battler in _party_windows:
		_party_windows[battler].set_targeted(false)
	for i in candidates.size():
		if not all_at_once and i != index:
			continue
		var battler: Battler = candidates[i]
		if _enemy_sprites.has(battler):
			_enemy_sprites[battler].set_targeted(true)
		elif _party_windows.has(battler):
			_party_windows[battler].set_targeted(true)


func _target_caption(candidates: Array[Battler], index: int, all_at_once: bool) -> String:
	if all_at_once:
		if candidates[0].side == Battler.Side.ENEMY:
			return GameText.text("ui_text.target_picker.all_enemies", "All enemies")
		return GameText.text("ui_text.target_picker.all_party", "The whole party")
	return BattleText.fill(GameText.text("ui_text.target_picker.single", "{target}"), {"target": candidates[index].label()})


# --- Effects -----------------------------------------------------------------

## The user's wind-up. Enemies hop toward the camera; the party has no sprite.
func play_user_action(user: Battler) -> void:
	if _enemy_sprites.has(user):
		await _enemy_sprites[user].lunge()


func play_attack(_user: Battler, target: Battler, result: HitResult, effect: DamageEffect) -> void:
	var at := _anchor(target)
	if not result.hit:
		if _enemy_sprites.has(target):
			_enemy_sprites[target].dodge()
		PopupText.spawn(_fx_layer, _popup("miss", "MISS"), at + Vector2(0, -10), MISS_COLOR)
		if result.lucky_dodge:
			_lucky_popup(at)
		await _wait(0.3)
		return

	HitFx.spawn(_fx_layer, at, effect.fx_kind(), result.crit)
	await _wait(0.05)
	_impact(target)
	if UserSettings.show_damage_numbers:
		PopupText.spawn(_fx_layer, str(result.damage), at + Vector2(0, -6), DAMAGE_COLOR)
	if result.any_lucky():
		_lucky_popup(at)
	await _hit_stop(result.crit)
	await _wait(0.2)


func play_status(target: Battler, status: StatusData) -> void:
	PopupText.spawn(_fx_layer, status.display_name, _anchor(target) + Vector2(0, -14), status.color)


func play_status_tick(target: Battler, status: StatusData, amount: int) -> void:
	_impact(target)
	if UserSettings.show_damage_numbers:
		PopupText.spawn(_fx_layer, str(amount), _anchor(target) + Vector2(0, -6), status.color)


func play_heal(target: Battler, amount: int) -> void:
	var text := _popup("heal", "+{amount}", amount) if amount > 0 else _popup("heal_zero", "+0")
	PopupText.spawn(_fx_layer, text, _anchor(target) + Vector2(0, -8), HEAL_COLOR)


func play_mp(target: Battler, amount: int) -> void:
	PopupText.spawn(_fx_layer, _popup("mp_restore", "+{amount} MP", amount), _anchor(target) + Vector2(0, -8), MP_COLOR)


## The recruit talk added a mood stack to the critter.
func play_mood(target: Battler) -> void:
	PopupText.spawn(_fx_layer, _popup("mood_up", "MOOD +1"), _anchor(target) + Vector2(0, -20), MOOD_COLOR)
	if _enemy_sprites.has(target):
		_enemy_sprites[target].wiggle()


func play_coins(source: Battler, amount: int) -> void:
	PopupText.spawn(_fx_layer, _popup("coins", "+{amount} coins", amount), _anchor(source) + Vector2(0, -14), COIN_COLOR)


func play_react(target: Battler) -> void:
	if _enemy_sprites.has(target):
		_enemy_sprites[target].react()


func play_defeat(battler: Battler) -> void:
	if _enemy_sprites.has(battler):
		var sprite: EnemySprite = _enemy_sprites[battler]
		await sprite.dissolve()
	else:
		await _wait(0.2)


func refresh_battler(battler: Battler) -> void:
	if _enemy_sprites.has(battler):
		_enemy_sprites[battler].refresh()


## Recruit: the enemy sprite fades out and a party window pops in.
func move_to_party(battler: Battler) -> void:
	await remove_enemy(battler)
	var window := _add_party_window(battler)
	window.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(window, "modulate:a", 1.0, 0.25)
	await tween.finished


## The enemy sprite fades out and the others close the gap (recruit, or leaving the battle).
func remove_enemy(battler: Battler) -> void:
	if not _enemy_sprites.has(battler):
		return
	var sprite: EnemySprite = _enemy_sprites[battler]
	await sprite.dissolve()
	_enemy_sprites.erase(battler)
	sprite.queue_free()
	_layout_enemies(true)


# --- Building ----------------------------------------------------------------

func _add_enemy_sprite(battler: Battler) -> EnemySprite:
	var sprite := EnemySprite.create(battler)
	_enemy_layer.add_child(sprite)
	_enemy_sprites[battler] = sprite
	return sprite


func _add_party_window(battler: Battler) -> PartyWindow:
	var window: PartyWindow = PARTY_WINDOW.instantiate()
	_party_hud.add_child(window)
	window.bind(battler)
	_party_windows[battler] = window
	return window


## Centers the enemies side by side on one baseline (GDD 03, "Enemy sprites").
func _layout_enemies(animated: bool) -> void:
	var sprites := _enemy_sprites.values()
	var total := 0.0
	for sprite: EnemySprite in sprites:
		total += sprite.size.x
	total += ENEMY_GAP * maxi(sprites.size() - 1, 0)
	var x := roundf((size.x - total) / 2.0)
	for sprite: EnemySprite in sprites:
		var target := Vector2(x, ENEMY_BASELINE - sprite.size.y)
		if animated:
			create_tween().tween_property(sprite, "position", target, 0.25)
		else:
			sprite.position = target
		x += sprite.size.x + ENEMY_GAP


func _anchor(battler: Battler) -> Vector2:
	if _enemy_sprites.has(battler):
		return _enemy_sprites[battler].anchor_point() - global_position
	if _party_windows.has(battler):
		return _party_windows[battler].anchor_point() - global_position
	return size / 2.0


func _impact(target: Battler) -> void:
	if _enemy_sprites.has(target):
		_enemy_sprites[target].flash()
		_enemy_sprites[target].wiggle()
	elif _party_windows.has(target):
		_party_windows[target].play_hit()


func _lucky_popup(at: Vector2) -> void:
	PopupText.spawn(_fx_layer, _popup("lucky", "LUCKY!"), at + Vector2(0, -22), LUCKY_COLOR)
	for i in 4:
		HitFx.spawn(_fx_layer, at + Vector2(randf_range(-14, 14), randf_range(-18, 6)), DamageEffect.HitFx.MAGIC)


## Fighting-game hit-stop: freeze for a few frames on impact, with a random
## slow-motion beat on critical hits. No screen shake, ever (GDD 03).
func _hit_stop(critical: bool) -> void:
	Engine.time_scale = 0.0
	var freeze := BattleRules.CRIT_HIT_STOP_SECONDS if critical else BattleRules.HIT_STOP_SECONDS
	await get_tree().create_timer(freeze, true, false, true).timeout
	Engine.time_scale = 1.0
	if critical and randf() < BattleRules.CRIT_SLOWMO_CHANCE:
		Engine.time_scale = BattleRules.CRIT_SLOWMO_SCALE
		await get_tree().create_timer(BattleRules.CRIT_SLOWMO_SECONDS, true, false, true).timeout
		Engine.time_scale = 1.0


## Pop-up text from game_text.json ui_text.popups.
func _popup(key: String, fallback: String, amount := 0) -> String:
	return GameText.text("ui_text.popups." + key, fallback).format({"amount": amount})


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
