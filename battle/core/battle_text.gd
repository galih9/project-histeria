class_name BattleText
extends RefCounted
## All the battle narration in one file, so tone and wording are easy to edit.
## Placeholders in {braces} are filled by fill().

const BATTLE_START := "{target} blocks the way!"
const BATTLE_START_MANY := "{target} and friends block the way!"
const BOSS_START := "{target} looms over everyone!"
const FIRST_STRIKE_PARTY := "You got the jump on them! The party feels speedy!"
const FIRST_STRIKE_ENEMY := "Yikes! You got ambushed from behind!"

const MISS := "{target} dodged it!"
const DAMAGE := "{target} takes {amount} damage!"
const CRIT := "SMAAAASH!!"
const CRIT_BLOCKED := "{target}'s guard stops a critical hit!"
const LUCKY_STRIKE := "LUCKY! The attack still lands!"
const LUCKY_DODGE := "LUCKY! {target} slips out of the way!"
const LUCKY_CRIT := "LUCKY! A wild critical hit!"
const LUCKY_GUARD := "LUCKY! {target} shrugs off half of it!"
const DEFEATED_ENEMY := "{target} is defeated!"
const DEFEATED_PARTY := "{target} is knocked out!"

const HEAL := "{target} recovers {amount} HP!"
const REVIVE := "{target} is back on their feet!"
const HEAL_NOTHING := "Nothing happens..."
const MP_RESTORE := "{target} recovers {amount} MP!"
const CLEANSE := "{target}'s debuffs vanish!"
const CLEANSE_NOTHING := "{target} feels extra tidy."
const STATUS_MAXED := "{target}'s {status} can't stack any higher!"

const DEFEND := "{user} gets ready to block!"
const NOT_ENOUGH_MP := "{user} tries, but runs out of MP!"

const RECRUIT_ASK := "{user} asks {target} to join the party."
const RECRUIT_JOIN := "{target} joins the party!"
const RECRUIT_REFUSE := "{target} refuses!"
const RECRUIT_NO_ROOM := "The party is full! There's no room for {target}."

const RUN_TRY := "{user} tries to run away..."
const RUN_SUCCESS := "The party escaped!"
const RUN_FAIL := "...but got blocked!"
const RUN_BOSS := "There is no escaping {target}!"

const VICTORY := "YOU WON!"
const DEFEAT := "The party blacked out..."
const DROP := "The party found a {item}!"

const SUB_ACTION_OPEN := "{user} sees an opening! ({action})"


## Fills {placeholders} and capitalizes the start of each sentence, so a
## monster name with a lowercase article ("the Big Frog") reads right anywhere.
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
