class_name RecruitBank
extends RefCounted
## The recruit talk's question bank (GDD 18), read from game_text.json at
## recruiting.negotiation. Each question points every race at one of its
## reaction sets through "race_set", so races that share a set share their
## lines and outcomes. A race missing from a question's race_set has no
## reaction for that question yet, and the critter skips it.

const JOIN := &"join"
const ATTACK := &"attack"
const LEAVE := &"leave"
const ASK_AGAIN := &"ask_again"
const GIVE_MONEY := &"give_money"
const GIVE_ITEM := &"give_item"
const HEAL_PARTY := &"heal_party"

## Reactions that a high Luck can soften into ASK_AGAIN, and that add a mood stack.
const HOSTILE: Array[StringName] = [ATTACK, LEAVE]

const PATH := "recruiting.negotiation"


## Race label ("Idols") as the key the JSON uses ("idols").
static func race_key(race: StringName) -> String:
	return String(race).to_lower()


static func questions() -> Array:
	var value: Variant = GameText.value(PATH + ".questions")
	return value if value is Array else []


## The first of `races` that this question has reactions for, or "" when none.
static func race_in(question: Dictionary, races: Array[StringName]) -> String:
	var pointers: Variant = question.get("race_set", {})
	if not pointers is Dictionary:
		return ""
	for race in races:
		var key := race_key(race)
		if (pointers as Dictionary).has(key):
			return key
	return ""


## Every question with a reaction written for one of `races`.
static func questions_for(races: Array[StringName]) -> Array:
	return questions().filter(func(q: Variant) -> bool: return q is Dictionary and not race_in(q, races).is_empty())


## Answer keys in order ("A", "B", "C").
static func answer_keys(question: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	var answers: Variant = question.get("answers", {})
	if answers is Dictionary:
		for key: String in answers:
			keys.append(key)
	keys.sort()
	return keys


static func answer_text(question: Dictionary, key: String) -> String:
	var answers: Variant = question.get("answers", {})
	return (answers as Dictionary).get(key, key) if answers is Dictionary else key


## {"line": ..., "outcome": ...} for this race and answer, or {} when nothing is written.
static func reaction(question: Dictionary, races: Array[StringName], key: String) -> Dictionary:
	var race := race_in(question, races)
	if race.is_empty():
		return {}
	var set_name: String = (question.get("race_set", {}) as Dictionary).get(race, "")
	var sets: Variant = question.get("reaction_sets", {})
	if not sets is Dictionary:
		return {}
	var reaction_set: Variant = (sets as Dictionary).get(set_name, {})
	if not reaction_set is Dictionary:
		return {}
	var found: Variant = (reaction_set as Dictionary).get(key, {})
	return found if found is Dictionary else {}


## The line shown when the critter is too angry to respond.
static func too_angry_text() -> String:
	return GameText.text(PATH + ".too_angry_text", "{target} did not respond.")
