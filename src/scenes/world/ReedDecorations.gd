extends Node2D

const REED_TILESET := preload("res://assets/ForgottenMemories/ReedTileset.tres")
const REED_SOURCE := 0

func _ready() -> void:
	var layer := TileMapLayer.new()
	layer.name = "ReedTileMap"
	layer.tile_set = REED_TILESET
	layer.z_index = 1268
	layer.z_as_relative = false
	add_child(layer)
	# Decorative only: sparse reedbank accents along the southern water edge.
	for cell in [Vector2i(-12, 22), Vector2i(-10, 22), Vector2i(-8, 22), Vector2i(8, 22), Vector2i(10, 22), Vector2i(12, 22), Vector2i(-13, 23), Vector2i(-9, 23), Vector2i(9, 23), Vector2i(13, 23)]:
		layer.set_cell(cell, REED_SOURCE, Vector2i(abs(cell.x) % 8, abs(cell.y) % 4))
