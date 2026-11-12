class_name HitResult
extends RefCounted
## Outcome of one attack roll, filled in by CombatMath.

var hit := false
var crit := false
var damage := 0
var lucky_strike := false ## a miss turned into a hit by the attacker's Luck
var lucky_dodge := false ## a hit turned into a miss by the defender's Luck
var lucky_crit := false ## the attacker's Luck turned a normal hit into a critical
var lucky_guard := false ## the defender's Luck halved the damage
var crit_blocked := false ## Defend stopped a critical


func any_lucky() -> bool:
	return lucky_strike or lucky_dodge or lucky_crit or lucky_guard
