extends Node

var items: Dictionary = {}
var rods: Dictionary = {}
var baits: Dictionary = {}
var tackle: Dictionary = {}
var fish: Dictionary = {}
var locations: Dictionary = {}

const ITEM_DIRS := [
	"res://src/resources/rods/",
	"res://src/resources/baits/",
	"res://src/resources/tackle/",
	"res://src/resources/fish/",
	"res://src/resources/locations/",
]

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	for dir_path in ITEM_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			push_error("ItemRegistry: cannot open " + dir_path)
			continue
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			# Skip templates (underscore prefix) and non-resource files
			var resource_name := _resource_name_from_dir_entry(file_name)
			if not resource_name.is_empty() and not resource_name.begins_with("_"):
				var res: Resource = load(dir_path + resource_name)
				if res is ItemData or res is FishingLocationData:
					_register(res)
			file_name = dir.get_next()
	print("ItemRegistry: loaded %d items (%d rods, %d baits, %d tackle, %d fish)" % [
		items.size(),
		rods.size(),
		baits.size(),
		tackle.size(),
		fish.size(),
	])

func _resource_name_from_dir_entry(file_name: String) -> String:
	if file_name.ends_with(".tres"):
		return file_name
	if file_name.ends_with(".tres.remap"):
		return file_name.trim_suffix(".remap")
	return ""

func _register(res: Resource) -> void:
	if res is FishingLocationData:
		locations[res.id] = res
		return
	items[res.id] = res
	if res is RodData:
		rods[res.id] = res
	elif res is BaitData:
		baits[res.id] = res
	elif res is TackleData:
		tackle[res.id] = res
	elif res is FishData:
		fish[res.id] = res

func get_item(id: String) -> ItemData:
	return items.get(id, null)

func get_location(id: String) -> FishingLocationData:
	return locations.get(id, null) as FishingLocationData

func get_location_for_zone(zone_name: String) -> FishingLocationData:
	for location: FishingLocationData in locations.values():
		if location.zone_name == zone_name:
			return location
	return null
