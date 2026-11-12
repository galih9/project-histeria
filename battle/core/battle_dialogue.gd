class_name BattleDialogue
extends RefCounted
## Random Raider lines during battle (GDD 03, Character Dialogue).
## A line costs no turn. Most turns carry no line: each event rolls a chance,
## and a cooldown keeps lines rare. Only Raiders speak.

const TURN_START := &"turn_start"
const BATTLE_START := &"battle_start"
const BOSS_START := &"boss_start"
const CRIT := &"crit"
const MISS := &"miss"
const LUCKY := &"lucky"
const HUMILIATE := &"humiliate"
const ALLY_LOW_HP := &"ally_low_hp"
const ALLY_KO := &"ally_ko"
const ENEMY_DEFEATED := &"enemy_defeated"
const RECRUIT_SUCCESS := &"recruit_success"
const RECRUIT_FAIL := &"recruit_fail"

const CHANCES: Dictionary = {
	TURN_START: 0.12,
	BATTLE_START: 0.5,
	BOSS_START: 1.0,
	CRIT: 0.5,
	MISS: 0.35,
	LUCKY: 0.6,
	HUMILIATE: 0.6,
	ALLY_LOW_HP: 0.5,
	ALLY_KO: 0.9,
	ENEMY_DEFEATED: 0.25,
	RECRUIT_SUCCESS: 0.8,
	RECRUIT_FAIL: 0.5,
}

## A higher priority line can replace one already on screen.
const PRIORITIES: Dictionary = {
	BOSS_START: 3,
	ALLY_KO: 3,
	ALLY_LOW_HP: 2,
	RECRUIT_SUCCESS: 2,
}

## Turns to wait after any line before the next one can roll.
const COOLDOWN_TURNS := 2

const EXPRESSIONS: Array[StringName] = [&"neutral", &"happy", &"worried", &"smug", &"surprised"]

var _ctx: BattleContext
var _cooldown := 0


func _init(ctx: BattleContext) -> void:
	_ctx = ctx


func on_turn_passed() -> void:
	_cooldown = maxi(_cooldown - 1, 0)


## Rolls for a line from `speaker`. Shown as a self thought when the speaker is
## the active character, otherwise as party dialogue at the side of the screen.
func trigger(event: StringName, speaker: Battler) -> void:
	if speaker == null or not speaker.is_alive() or not speaker.data.is_raider():
		return
	if speaker.side != Battler.Side.PARTY:
		return
	var priority: int = PRIORITIES.get(event, 1)
	if _cooldown > 0 and priority < 3:
		return
	if _ctx.rng.randf() > CHANCES.get(event, 0.0):
		return
	var lines: PackedStringArray = speaker.data.battle_lines.get(String(event), PackedStringArray())
	if lines.is_empty():
		return
	var parsed := parse_line(BattleText.pick(lines, _ctx.rng))
	_cooldown = COOLDOWN_TURNS
	_ctx.view.show_dialogue(speaker, parsed.text, parsed.expression, speaker == _ctx.current_actor, priority)


## Picks a random Raider in the party (other than `exclude`) to react.
func trigger_any(event: StringName, exclude: Battler = null) -> void:
	var speakers := _ctx.party().filter(func(b: Battler) -> bool: return b != exclude and b.data.is_raider())
	if speakers.is_empty():
		return
	trigger(event, speakers[_ctx.rng.randi_range(0, speakers.size() - 1)])


## "[smug] Ugh. Fine." -> {expression = &"smug", text = "Ugh. Fine."}
static func parse_line(line: String) -> Dictionary:
	var expression := &"neutral"
	var text := line.strip_edges()
	if text.begins_with("["):
		var close := text.find("]")
		if close > 0:
			var tag := StringName(text.substr(1, close - 1).to_lower())
			if EXPRESSIONS.has(tag):
				expression = tag
			text = text.substr(close + 1).strip_edges()
	return {"expression": expression, "text": text}
