class_name DropRoller
extends RefCounted
## Drive drops after a won battle (GDD 07, "Getting drives").
## Party Luck nudges each tier step a little; the effect stays small by design.

const BASE_UPGRADE_CHANCE := 0.12
const UPGRADE_PER_LUCK := 0.003
const MAX_UPGRADE_CHANCE := 0.5
## Tier V (Quantum Core) stays a boss reward idea, so random drops stop at IV.
const MAX_RANDOM_TIER := 4


static func roll(rng: RandomNumberGenerator, encounter: EncounterData, party_luck: float) -> Array[DriveData]:
	var drops: Array[DriveData] = []
	if rng.randf() >= encounter.drive_drop_chance:
		return drops
	var upgrade := minf(BASE_UPGRADE_CHANCE + party_luck * UPGRADE_PER_LUCK, MAX_UPGRADE_CHANCE)
	var tier := 1
	while tier < MAX_RANDOM_TIER and rng.randf() < upgrade:
		tier += 1
	var color := rng.randi_range(0, DriveData.DriveColor.size() - 1) as DriveData.DriveColor
	drops.append(DriveData.create(color, tier))
	return drops
