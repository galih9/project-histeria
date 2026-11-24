class_name OverhealTrait
extends TraitData
## Ale's Overheal passive (GDD 13, decided Nov 19): healing past max HP from
## her own skills becomes a Shield. Uncapped, one pool with no stacks, lasts
## the whole battle and does not regenerate.


func turns_overheal_into_shield() -> bool:
	return true
