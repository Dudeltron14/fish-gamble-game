class_name FishingLocationData extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var zone_name: String = ""
@export var biome: String = "harbor"
@export var fish_ids: Array[String] = []
@export var rarity_weights: Dictionary = {"common": 0.95, "uncommon": 0.05, "rare": 0.0, "legendary": 0.0}
@export var day_modifiers: Dictionary = {}
@export var night_modifiers: Dictionary = {}
@export var allowed_tags: Array[String] = []
