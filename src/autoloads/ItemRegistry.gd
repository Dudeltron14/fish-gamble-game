extends Node

var items: Dictionary = {}
var rods: Dictionary = {}
var baits: Dictionary = {}
var tackle: Dictionary = {}
var fish: Dictionary = {}

const ITEM_DIRS := [
	"res://src/resources/rods/",
	"res://src/resources/baits/",
	"res://src/resources/tackle/",
	"res://src/resources/fish/",
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
			if file_name.ends_with(".tres") and not file_name.begins_with("_"):
				var res: Resource = load(dir_path + file_name)
				if res is ItemData:
					_register(res)
			file_name = dir.get_next()

func _register(res: ItemData) -> void:
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
