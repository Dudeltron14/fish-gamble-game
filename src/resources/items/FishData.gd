class_name FishData extends ItemData

@export_enum("common", "uncommon", "rare", "legendary") var rarity: String = "common"
@export var base_coin_value: int = 5
@export var catch_difficulty: float = 1.0
@export var sprite_frame: int = 0
@export var min_length: float = 0.0 # inches; zero uses rarity defaults
@export var max_length: float = 0.0
@export var min_weight: float = 0.0 # pounds; junk uses weight instead
@export var max_weight: float = 0.0

const CATCH_RANGES := {
	"common_freshwater_snail": Vector2(0.5, 2.0), "common_tropical_bluegill": Vector2(4.0, 12.0),
	"common_perch": Vector2(6.0, 18.0), "common_mossback_bass": Vector2(10.0, 26.0),
	"uncommon_bass": Vector2(14.0, 32.0), "uncommon_silver_shad": Vector2(9.0, 24.0),
	"uncommon_red_dock_crab": Vector2(3.0, 10.0), "uncommon_sunset_conch": Vector2(2.0, 7.0),
	"rare_trout": Vector2(18.0, 38.0), "rare_pike": Vector2(22.0, 48.0),
	"rare_pearl_clam": Vector2(3.0, 9.0), "legendary_kraken": Vector2(36.0, 84.0),
	"junk_boot": Vector2(1.0, 8.0), "junk_can": Vector2(0.2, 20.0), "junk_seaweed": Vector2(0.1, 5.0),
}

func catch_range() -> Vector2:
	if id.begins_with("junk_"):
		return Vector2(min_weight, max_weight) if min_weight > 0.0 and max_weight > min_weight else CATCH_RANGES.get(id, Vector2(1.0, 20.0))
	if id == "legendary_chest" or id == "legendary_key": return Vector2.ZERO
	if min_length > 0.0 and max_length > min_length: return Vector2(min_length, max_length)
	var preset: Vector2 = CATCH_RANGES.get(id, Vector2.ZERO)
	if preset != Vector2.ZERO: return preset
	match rarity:
		"common": return Vector2(6.0, 18.0)
		"uncommon": return Vector2(10.0, 28.0)
		"rare": return Vector2(18.0, 42.0)
		_: return Vector2(30.0, 72.0)
