class_name BattleText
extends RefCounted
## Battle narration. Every line comes from "battle_narration" in game_text.json;
## the copies below are used only when the JSON has no line for a key.
## Placeholders in {braces} are filled by fill().

const FALLBACK: Dictionary = {
	"BATTLE_START": "{target} blocks the way!",
	"BATTLE_START_MANY": "{target} and friends block the way!",
	"BOSS_START": "{target} looms over everyone!",
	"FIRST_STRIKE_PARTY": "You got the jump on them!",
	"FIRST_STRIKE_ENEMY": "You got ambushed from behind!",
	"MISS": "{target} dodged it!",
	"DAMAGE": "{target} takes {amount} damage!",
	"CRIT": "Critical hit!",
	"CRIT_BLOCKED": "{target}'s guard stops a critical hit!",
	"LUCKY_STRIKE": "LUCKY! The attack still lands!",
	"LUCKY_DODGE": "LUCKY! {target} slips out of the way!",
	"LUCKY_CRIT": "LUCKY! A critical hit!",
	"LUCKY_GUARD": "LUCKY! {target} takes half damage!",
	"DEFEATED_ENEMY": "{target} is defeated!",
	"DEFEATED_PARTY": "{target} is downed!",
	"HEAL": "{target} recovers {amount} HP!",
	"REVIVE": "{target} is back on their feet!",
	"HEAL_NOTHING": "Nothing happens.",
	"MP_RESTORE": "{target} recovers {amount} MP!",
	"CLEANSE": "{target}'s debuffs vanish!",
	"CLEANSE_NOTHING": "{target} has no debuffs.",
	"STATUS_MAXED": "{target}'s {status} is at its limit.",
	"DEFEND": "{user} gets ready to block!",
	"NOT_ENOUGH_MP": "{user} is short on MP.",
	"RECRUIT_ASK": "{user} asks {target} to join the party.",
	"RECRUIT_JOIN": "{target} joins the party!",
	"RECRUIT_REFUSE": "{target} refuses.",
	"RECRUIT_NO_ROOM": "The party is full.",
	"RUN_TRY": "{user} tries to run away...",
	"RUN_SUCCESS": "The party escaped!",
	"RUN_FAIL": "...but got blocked!",
	"RUN_BOSS": "{target} blocks the escape!",
	"VICTORY": "YOU WON!",
	"DEFEAT": "The party is down...",
	"DROP": "The party found a {item}!",
	"SUB_ACTION_OPEN": "{user} sees an opening! ({action})",
	"DEFAULT_SKILL_USE": "{user} uses {action}!",
}


## The narration line for `key` ("MISS", "DAMAGE"...).
static func line(key: String) -> String:
	return GameText.narration(key, FALLBACK.get(key, ""))


## Fills {placeholders} and capitalizes the start of each sentence, so a
## critter name with a lowercase article ("the Big Frog") reads right anywhere.
static func fill(template: String, values: Dictionary) -> String:
	return capitalize_sentences(template.format(values))


static func capitalize_sentences(text: String) -> String:
	var result := ""
	var capitalize_next := true
	for character in text:
		if capitalize_next and character.to_upper() != character.to_lower():
			result += character.to_upper()
			capitalize_next = false
		else:
			result += character
		if character in [".", "!", "?"]:
			# An ellipsis ("Hee hee... maybe?") keeps the sentence going.
			capitalize_next = not result.ends_with("..")
	return result


static func pick(lines: PackedStringArray, rng: RandomNumberGenerator, fallback := "") -> String:
	if lines.is_empty():
		return fallback
	return lines[rng.randi_range(0, lines.size() - 1)]
