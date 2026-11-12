class_name BattleResult
extends RefCounted
## What a finished battle hands back to the overworld.

enum Outcome { VICTORY, DEFEAT, ESCAPED }

var outcome := Outcome.VICTORY
## Party battlers at the end (HP and MP already written back to their PartyMember).
var party: Array[Battler] = []
## Monsters that joined during the fight.
var recruited: Array[Battler] = []
var drives: Array[DriveData] = []
