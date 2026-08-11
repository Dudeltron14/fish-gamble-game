class_name FishingEventData extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var active_locations: Array[String] = []
@export var duration_seconds: int = 600
@export var family_modifiers: Dictionary = {}
@export var rarity_modifiers: Dictionary = {}
@export var reward_multiplier: float = 1.0
