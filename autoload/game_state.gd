extends Node
## Everything that persists between battles: the party, the bag, coins, drives
## found, languages unlocked, which holograms have been beaten, story flags and
## conversations already seen.

const MAX_PARTY_SIZE := 4

const STARTING_PARTY: Array[CombatantData] = [
	preload("res://data/characters/bo.tres"),
	preload("res://data/characters/ale.tres"),
]

const STARTING_ITEMS: Dictionary = {
	preload("res://data/items/cookie.tres"): 3,
	preload("res://data/items/fizzy_pop.tres"): 2,
	preload("res://data/items/mystery_sandwich.tres"): 1,
}

var party: Array[PartyMember] = []
var inventory := Inventory.new()
var drives: Array[DriveData] = []
var coins := 0
## Critter languages the party can read (race label -> true). Souls and
## Electronics talk only after their unlock (GDD 02, 18; Yoon's books later).
var unlocked_languages: Dictionary = {}
## DEV menu switch: every language counts as unlocked. Survives new_game().
var dev_all_languages := false
## Hologram ids (see Hologram.hologram_id) that stay gone for this run.
var cleared_holograms: Dictionary = {}
## Story points reached ("willhelm_joined"), for conversation conditions.
var story_flags: Dictionary = {}
## Conversation ids already played, for conversations marked "once".
var seen_conversations: Dictionary = {}


func _ready() -> void:
	# Lets you press F6 on any scene and still have a party to fight with.
	new_game()


func new_game() -> void:
	party.clear()
	for data in STARTING_PARTY:
		party.append(PartyMember.new(data))
	inventory = Inventory.new()
	for item: ItemData in STARTING_ITEMS:
		inventory.add(item, STARTING_ITEMS[item])
	drives.clear()
	coins = 0
	unlocked_languages.clear()
	cleared_holograms.clear()
	story_flags.clear()
	seen_conversations.clear()


func has_room_in_party() -> bool:
	return party.size() < MAX_PARTY_SIZE


func unlock_language(race: StringName) -> void:
	unlocked_languages[race] = true


## False while the critter speaks a language the party hasn't unlocked yet.
func can_understand(data: CombatantData) -> bool:
	if dev_all_languages:
		return true
	for race in data.races:
		if Races.OWN_LANGUAGE.has(race) and not unlocked_languages.has(race):
			return false
	return true


func add_party_member(data: CombatantData) -> PartyMember:
	var member := PartyMember.new(data)
	party.append(member)
	return member


## Full HP and MP for everyone, downed members included.
func restore_party() -> void:
	for member in party:
		member.restore()


func mark_hologram_cleared(hologram_id: StringName) -> void:
	cleared_holograms[hologram_id] = true


func is_hologram_cleared(hologram_id: StringName) -> bool:
	return cleared_holograms.has(hologram_id)


## Sum of the party's Luck, used to nudge drive drops (GDD 04, "Luck and drops").
func party_luck() -> float:
	var total := 0.0
	for member in party:
		total += member.data.stats.luck
	return total
