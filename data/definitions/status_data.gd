class_name StatusData
extends Resource
## A buff, debuff, control or damage status (GDD 05). Stacks are the remaining
## duration. Countdown (decided Nov 19): damage over time ticks and loses a
## stack at the end of every turn; every other status loses a stack at the end
## of the affected character's own turn. Text comes from game_text.json.

enum Kind {
	## Changes one stat while active (Attack Up, Defense Down...).
	STAT_MODIFIER,
	## Deals fixed damage each trigger (Poison, Burned...).
	DAMAGE_OVER_TIME,
	## Single-target attacks and skills must target the one who applied it.
	TAUNT,
	## Skips the character's next turn. Diminishing returns (BattleRules).
	STUN,
	## Each own turn rolls a chance to lose that turn.
	PARALYZE,
	## Text and color for the Shield pool (Battler.shield). No stacks.
	SHIELD,
}

@export var id: StringName
@export var display_name := ""
@export var kind := Kind.STAT_MODIFIER
## Debuffs are what cleanses remove and what Humiliate applies.
@export var is_debuff := false
@export var max_stacks := 5
## Small color tag for the party window status pip and popups.
@export var color := Color.WHITE

@export_group("Stat modifier")
@export_enum("attack", "defense", "resistance", "speed", "accuracy", "evasion", "crit_chance") var stat := "attack"
## Multiplies core stats (Attack, Defense, Resistance, Speed). 1.25 = +25%.
@export var multiplier := 1.0
## Adds percentage points to secondary stats (Accuracy, Evasion, Critical chance).
@export var flat_bonus := 0.0

@export_group("Damage over time")
@export var damage_per_trigger := 0

@export_group("Battle text")
## Placeholders: {target} and {status}.
@export var apply_text := "{target} is affected by {status}!"
@export var trigger_text := "{target} takes {amount} damage from {status}!"
@export var expire_text := "{target}'s {status} wore off."
## Shown when Stun diminishing returns cut a stun down to 0.
@export var resisted_text := ""


func stat_name() -> StringName:
	return StringName(stat)


## Damage over time counts down on every turn; the rest on the owner's own turns.
func counts_every_turn() -> bool:
	return kind == Kind.DAMAGE_OVER_TIME
