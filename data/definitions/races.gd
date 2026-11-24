class_name Races
extends RefCounted
## Race labels (GDD 02 and game_text.json "races"). Descriptions live in the JSON.

const RAIDERS := &"Raiders"
const GUARDIANS := &"Guardians"
const HOFFLERS := &"Hofflers"
const FERRALS := &"Ferrals"
const KITS := &"Kits"
const WANDERERS := &"Wanderers"
const SOULS := &"Souls"
const MONUMENTS := &"Monuments"
const ELECTRONICS := &"Electronics"
const IDOLS := &"Idols"

## Races with their own language: the recruit talk opens only after its unlock.
const OWN_LANGUAGE: Array[StringName] = [SOULS, ELECTRONICS]


static func description(race: StringName) -> String:
	return GameText.race_description(race)
