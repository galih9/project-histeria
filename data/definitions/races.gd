class_name Races
extends RefCounted
## The six races from GDD 02. For now a race is a label with a description.

const RAIDERS := &"Raiders"
const LOOK_HUMAN := &"Look-Human"
const FERRAL := &"Ferral"
const MONUMENT := &"Monument"
const SPIRITS := &"Spirits"
const WARES := &"Wares"

const DESCRIPTIONS: Dictionary = {
	RAIDERS: "The playable characters. The only race that talks on its own in battle.",
	LOOK_HUMAN: "They look like humans, but slightly off.",
	FERRAL: "Basically wild animals.",
	MONUMENT: "How are these things even here?",
	SPIRITS: "They are transparent.",
	WARES: "Things that should belong in a warehouse.",
}
