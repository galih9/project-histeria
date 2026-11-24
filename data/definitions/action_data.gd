class_name ActionData
extends Resource
## Anything a battler can use from the menu: weapon attacks, skills and items.
## An action is a list of effects applied to each target in order, which keeps
## new skills a data job: combine DamageEffect, ApplyStatusEffect, HealEffect...

enum Target { SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, ALL_ALLIES, SELF }

## Hints for the enemy AI so it picks sensible moves.
enum AiHint {
	ALWAYS,
	WHEN_ALLY_HURT, ## an ally is under 60% HP
	WHEN_ALLY_DEBUFFED, ## an ally carries any debuff
	WHEN_TARGET_LACKS_STATUS, ## skips targets that already have this action's status
}

## Matches the skill or move "id" in game_text.json, where its name and text live.
@export var text_id: StringName
@export var display_name := ""
## Shown in menus. Leave empty to use display_name (weapons use "Melee", "Throw Book"...).
@export var menu_label := ""
@export_multiline var description := ""
@export var target := Target.SINGLE_ENEMY
@export var effects: Array[EffectData] = []
## Placeholders: {user}, {action}, {target}.
@export var use_text := "{user} uses {action}!"
## Lines shown after a chance-based effect rolls (Sit Down). Filled from
## battle_text_chances_success / battle_text_chances_failed in game_text.json.
var outcome_success_lines := PackedStringArray()
var outcome_fail_lines := PackedStringArray()

@export_group("Signature weapon")
## Weapon-bound (GDD 07): belongs to the signature weapon, so it locks while
## the weapon is out of the user's hands (Ale's thrown book).
@export var requires_weapon := false
## The weapon leaves the user's hands after this action (Book Throw).
@export var throws_weapon := false
## Takes the weapon back; only offered while the weapon is away (Collect Book).
@export var retrieves_weapon := false

@export_group("Enemy AI")
@export var ai_weight := 1.0
@export var ai_hint := AiHint.ALWAYS


func get_menu_label() -> String:
	return menu_label if not menu_label.is_empty() else display_name


func targets_allies() -> bool:
	return target in [Target.SINGLE_ALLY, Target.ALL_ALLIES, Target.SELF]


func targets_many() -> bool:
	return target in [Target.ALL_ENEMIES, Target.ALL_ALLIES]


## The first status this action applies, used by the AI hint above.
func first_applied_status() -> StatusData:
	for effect in effects:
		if effect is ApplyStatusEffect:
			return effect.status
	return null
