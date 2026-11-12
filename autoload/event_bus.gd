extends Node
## Global signals that connect systems which should stay unaware of each other.
## Example: a hologram asks for a battle, and the Game scene answers it.

## A roaming hologram touched the player (or got hit first).
## advantage uses EncounterData.Advantage.
signal encounter_requested(hologram: Node, advantage: int)

## The overworld wants to show a message box (signs, NPCs, the snack stand).
signal world_message_requested(lines: PackedStringArray)
