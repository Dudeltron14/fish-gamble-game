class_name BaitData extends ItemData

## Keys: "common", "uncommon", "rare", "legendary". Values should sum to 1.0.
@export var rarity_weights: Dictionary = {
	"common": 0.65,
	"uncommon": 0.25,
	"rare": 0.09,
	"legendary": 0.01,
}
@export var uses_per_stack: int = 10
