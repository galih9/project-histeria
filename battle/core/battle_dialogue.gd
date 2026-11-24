class_name BattleDialogue
extends RefCounted
## Raider lines during battle (GDD 03 and 11, Character Dialogue).
## A line costs no turn. Most turns carry no line: each event rolls a chance,
## and after any line the next one waits COOLDOWN_TURNS turns. Only Raiders
## (and, later, party Guardians) speak. One line on screen at a time.
##
## Conversations (game_text.json "conversations"): when an event fires and an
## entry's conditions match, a multi-line exchange can play in place of the
## speaker's single line. Lines and conversations all come from the JSON.

const BATTLE_START := &"battle_start"
const BATTLE_START_PLAYER := &"battle_start_player"
const BATTLE_START_ENEMY := &"battle_start_enemy"
const BOSS_START := &"boss_start"
const TURN_START := &"turn_start"
const CRIT := &"crit"
const MISS := &"miss"
const LUCKY := &"lucky"
const HUMILIATE := &"humiliate"
const ALLY_LOW_HP := &"ally_low_hp"
const ALLY_DOWNED := &"ally_downed"
const ALLY_CRITTER_LOW_HP := &"ally_critter_low_hp"
const ALLY_CRITTER_DOWNED := &"ally_critter_downed"
const ENEMY_DEFEATED := &"enemy_defeated"
const RECRUIT_SUCCESS := &"recruit_success"
const RECRUIT_FAIL := &"recruit_fail"

## Chance that an event shows a line (GDD 11). Placeholders, tuned in playtests.
const CHANCES: Dictionary = {
	BATTLE_START: 0.5,
	BATTLE_START_PLAYER: 0.6,
	BATTLE_START_ENEMY: 0.6,
	BOSS_START: 1.0,
	TURN_START: 0.12,
	CRIT: 0.5,
	MISS: 0.35,
	LUCKY: 0.6,
	HUMILIATE: 0.6,
	ALLY_LOW_HP: 0.5,
	ALLY_DOWNED: 0.9,
	ALLY_CRITTER_LOW_HP: 0.5,
	ALLY_CRITTER_DOWNED: 0.9,
	ENEMY_DEFEATED: 0.25,
	RECRUIT_SUCCESS: 0.8,
	RECRUIT_FAIL: 0.5,
}

## A higher priority line can replace one already on screen. Priority 3 also
## skips the cooldown (boss start and downed lines, GDD 11).
const PRIORITIES: Dictionary = {
	BOSS_START: 3,
	ALLY_DOWNED: 3,
	ALLY_CRITTER_DOWNED: 3,
	ALLY_LOW_HP: 2,
	ALLY_CRITTER_LOW_HP: 2,
	RECRUIT_SUCCESS: 2,
}
## Conversations hold the screen until their last line.
const CONVERSATION_PRIORITY := 4
## When a conversation matches, the share of times it plays in place of the single line.
const CONVERSATION_SHARE := 0.5

## Turns to wait after any line before the next one can roll.
const COOLDOWN_TURNS := 2

## Test switch: every event shows a line (chance 1, no cooldown).
static var force_lines := false
## Test switch: a matching conversation always plays.
static var force_conversations := false

## Every line shown, as [event, speaker id, text], for tests.
signal line_shown(event: StringName, speaker: StringName, text: String)
signal conversation_played(id: String)

var _ctx: BattleContext
var _cooldown := 0
var _in_conversation := false


func _init(ctx: BattleContext) -> void:
	_ctx = ctx


func on_turn_passed() -> void:
	_cooldown = maxi(_cooldown - 1, 0)


func is_busy() -> bool:
	return _in_conversation


## Rolls for a line from `speaker`, who also caused the event (crit, miss,
## recruit...). Shown as a self thought when the speaker is the active
## character, otherwise as party dialogue at the side of the screen.
func trigger(event: StringName, speaker: Battler, target: Battler = null) -> void:
	_fire(event, speaker, speaker, target)


## Picks a random Raider in the party (other than `exclude`) to react.
## `actor` is whoever caused the event, for conversation conditions.
func trigger_any(event: StringName, exclude: Battler = null, target: Battler = null, actor: Battler = null) -> void:
	var speakers := _ctx.party().filter(func(b: Battler) -> bool: return b != exclude and b.data.is_raider())
	if speakers.is_empty():
		return
	_fire(event, speakers[_ctx.rng.randi_range(0, speakers.size() - 1)], actor, target)


func _fire(event: StringName, speaker: Battler, actor: Battler, target: Battler) -> void:
	if _in_conversation:
		return
	if speaker == null or not speaker.is_alive() or not speaker.data.is_raider():
		return
	if speaker.side != Battler.Side.PARTY:
		return
	var priority: int = PRIORITIES.get(event, 1)
	if _cooldown > 0 and priority < 3 and not force_lines:
		return
	if not force_lines and _ctx.rng.randf() > CHANCES.get(event, 0.0):
		return

	var conversations := matching_conversations(event, actor, target)
	if not conversations.is_empty() and (force_conversations or _ctx.rng.randf() < CONVERSATION_SHARE):
		_play_conversation(conversations[_ctx.rng.randi_range(0, conversations.size() - 1)])
		return

	var lines: PackedStringArray = speaker.data.battle_lines.get(String(event), PackedStringArray())
	if lines.is_empty():
		return
	var parsed := parse_line(BattleText.pick(lines, _ctx.rng))
	_cooldown = COOLDOWN_TURNS
	line_shown.emit(event, speaker.data.text_id, parsed.text)
	_ctx.view.show_dialogue(speaker, parsed.text, parsed.expression, speaker == _ctx.current_actor, priority)


# --- Conversations -----------------------------------------------------------

## Entries from game_text.json whose event and conditions match right now.
func matching_conversations(event: StringName, actor: Battler, target: Battler) -> Array:
	var result := []
	for entry in GameText.conversations():
		if entry is Dictionary and StringName(entry.get("event", "")) == event and _conditions_met(entry, actor, target):
			result.append(entry)
	return result


func _conditions_met(entry: Dictionary, actor: Battler, target: Battler) -> bool:
	if entry.get("once", false) and GameState.seen_conversations.has(entry.get("id", "")):
		return false
	var conditions: Dictionary = entry.get("conditions", {}) if entry.get("conditions") is Dictionary else {}
	var want_actor: Variant = conditions.get("actor")
	if want_actor is String and not want_actor.is_empty():
		if actor == null or String(actor.data.text_id) != want_actor:
			return false
	var want_target: Variant = conditions.get("target")
	if want_target is String and not want_target.is_empty():
		if target == null or not _matches(target, want_target):
			return false
	var active := _ctx.party()
	for id in _as_strings(conditions.get("requires_in_active_party")):
		if _find_member(active, id) == null:
			return false
	for id in _as_strings(conditions.get("excludes_in_active_party")):
		if _find_member(_ctx.party(false), id) != null:
			return false
	var flag: Variant = conditions.get("story_flag")
	if flag is String and not flag.is_empty() and not GameState.story_flags.has(flag):
		return false
	return true


## "bo", "big_frog" or "race:souls".
static func _matches(battler: Battler, wanted: String) -> bool:
	if wanted.begins_with("race:"):
		var race := wanted.substr(5).to_lower()
		for r in battler.data.races:
			if String(r).to_lower() == race:
				return true
		return false
	return String(battler.data.text_id) == wanted


func _play_conversation(entry: Dictionary) -> void:
	_in_conversation = true
	_cooldown = COOLDOWN_TURNS
	var id: String = entry.get("id", "")
	GameState.seen_conversations[id] = true
	conversation_played.emit(id)
	for line in entry.get("lines", []):
		if not line is Dictionary or not is_instance_valid(_ctx.view):
			continue
		var speaker := _find_member(_ctx.party(), line.get("speaker", ""))
		if speaker == null:
			continue
		var parsed := parse_line(line.get("text", ""))
		line_shown.emit(StringName(entry.get("event", "")), speaker.data.text_id, parsed.text)
		var as_thought: bool = line.get("style", "speech") == "thought"
		await _ctx.view.show_dialogue(speaker, parsed.text, parsed.expression, as_thought, CONVERSATION_PRIORITY, true)
	_in_conversation = false
	_cooldown = COOLDOWN_TURNS


static func _find_member(members: Array[Battler], id: String) -> Battler:
	for battler in members:
		if String(battler.data.text_id) == id:
			return battler
	return null


static func _as_strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			if item is String:
				result.append(item)
	return result


## "[smug] Ugh. Fine." -> {expression = &"smug", text = "Ugh. Fine."}
## Tags come from meta.expression_tags in game_text.json.
static func parse_line(line: String) -> Dictionary:
	var expression := &"neutral"
	var text := line.strip_edges()
	if text.begins_with("["):
		var close := text.find("]")
		if close > 0:
			var tag := StringName(text.substr(1, close - 1).to_lower())
			if GameText.expression_tags().has(tag):
				expression = tag
			text = text.substr(close + 1).strip_edges()
	return {"expression": expression, "text": text}
