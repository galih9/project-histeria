class_name StatusLibrary
extends RefCounted
## Statuses the rules need by name (the Shield pool's text and color).

const SHIELD := preload("res://data/statuses/shield.tres")


static func shield() -> StatusData:
	return SHIELD
