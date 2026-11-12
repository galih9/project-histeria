class_name DriveData
extends Resource
## A drive (GDD 07 pitch): storage media that changes effect by slot.
## The color picks the flavor, the tier picks the strength.
## Equipping comes later; for now drives drop from battles and fill the bag.

enum DriveColor { RED, BLUE, YELLOW }

const COLOR_NAMES: Array[String] = ["Red", "Blue", "Yellow"]
const TIER_NAMES: Array[String] = ["Floppy Disk", "Compact Disk", "USB Drive", "SSD", "Quantum Core"]
const TIER_MULTIPLIERS: Array[float] = [1.0, 2.0, 3.0, 4.0, 6.0]

@export var drive_color := DriveColor.RED
## 1 to 5.
@export_range(1, 5) var tier := 1


static func create(new_color: DriveColor, new_tier: int) -> DriveData:
	var drive := DriveData.new()
	drive.drive_color = new_color
	drive.tier = clampi(new_tier, 1, TIER_NAMES.size())
	return drive


func display_name() -> String:
	return "%s %s" % [COLOR_NAMES[drive_color], TIER_NAMES[tier - 1]]


func multiplier() -> float:
	return TIER_MULTIPLIERS[tier - 1]
