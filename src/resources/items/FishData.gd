class_name FishData extends ItemData

const FISH_SHEET := preload("res://assets/free fish/free fish.png")
const FISH_FRAME_SIZE := Vector2i(16, 16)
const FISH_SHEET_COLUMNS := 3

@export_enum("common", "uncommon", "rare", "legendary") var rarity: String = "common"
@export var base_coin_value: int = 5
@export var catch_difficulty: float = 1.0
@export var sprite_frame: int = 0

func get_display_texture() -> Texture2D:
	if icon:
		return icon
	if sprite_frame < 0:
		return null
	var atlas := AtlasTexture.new()
	var frame := maxi(sprite_frame, 0)
	var column := frame % FISH_SHEET_COLUMNS
	var row := floori(float(frame) / float(FISH_SHEET_COLUMNS))
	atlas.atlas = FISH_SHEET
	atlas.region = Rect2(
		Vector2(column * FISH_FRAME_SIZE.x, row * FISH_FRAME_SIZE.y),
		FISH_FRAME_SIZE
	)
	return atlas
