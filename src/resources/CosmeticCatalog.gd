class_name CosmeticCatalog
extends RefCounted

const ITEMS := {
	"skin_default": {"category": "skins", "name": "Original Fisherman", "description": "The harbor's classic working look.", "default": true, "icon": preload("res://assets/free-fishing-game-assets-pixel-art-pack/1 Fisherman/Fisherman_idle.png"), "region": Rect2(0, 0, 48, 48)},
	"skin_deep_sea_diver": {"category": "skins", "name": "Deep Sea Diver", "description": "Brass, pressure, and the deep blue unknown.", "price": 500, "icon": preload("res://assets/skins/deep_sea_diver/DS_Diver_idle.png"), "region": Rect2(0, 0, 48, 48)},
	"skin_high_roller": {"category": "skins", "name": "High Roller", "description": "Royal purple, gold trim, and a crown that knows odds.", "price": 500, "icon": preload("res://assets/skins/high_roller/High_Roller_idle.png"), "region": Rect2(0, 0, 48, 48)},
	"bobber_default": {"category": "bobbers", "name": "Classic Red Bobber", "description": "The original. It still floats.", "default": true, "icon": preload("res://assets/props/bobber_candy_stripe.png")},
	"bobber_sapphire": {"category": "bobbers", "name": "Sapphire Bobber", "description": "Blue enough to make the water jealous.", "price": 75, "icon": preload("res://assets/props/bobber_sapphire.png")},
	"bobber_gilded": {"category": "bobbers", "name": "Gilded Bobber", "description": "A little gold where the fish can see it.", "price": 100, "icon": preload("res://assets/props/bobber_gilded.png")},
	"bobber_candy_stripe": {"category": "bobbers", "name": "Candy Stripe Bobber", "description": "Sweet-looking. Strictly business.", "price": 75, "icon": preload("res://assets/props/bobber_candy_stripe.png")},
	"bobber_lucky_clover": {"category": "bobbers", "name": "Lucky Clover Bobber", "description": "Luck is mostly presentation anyway.", "price": 125, "icon": preload("res://assets/props/bobber_lucky_clover.png")},
	"bobber_harbor_lantern": {"category": "bobbers", "name": "Harbor Lantern", "description": "A warm little beacon for cold water.", "price": 125, "icon": preload("res://assets/props/bobber_harbor_lantern.png")},
	"bobber_anchor_float": {"category": "bobbers", "name": "Anchor Float", "description": "Stubbornly nautical.", "price": 125, "icon": preload("res://assets/props/bobber_anchor_float.png")},
	"bobber_pearl_clam": {"category": "bobbers", "name": "Pearl Clam", "description": "Shell game, but charming.", "price": 150, "icon": preload("res://assets/props/bobber_pearl_clam.png")},
	"bobber_treasure_chest": {"category": "bobbers", "name": "Treasure Chest", "description": "Promises nothing. Implies everything.", "price": 175, "icon": preload("res://assets/props/bobber_treasure_chest.png")},
}

static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})

static func is_default(id: String) -> bool:
	return bool(get_item(id).get("default", false))

static func get_category(category: String) -> Array:
	var results: Array = []
	for id: String in ITEMS:
		var item: Dictionary = ITEMS[id].duplicate()
		if item.category == category:
			item.id = id
			results.append(item)
	return results

static func icon_for(item: Dictionary) -> Texture2D:
	var icon: Texture2D = item.get("icon")
	if not item.has("region"):
		return icon
	var atlas := AtlasTexture.new()
	atlas.atlas = icon
	atlas.region = item.region
	return atlas
