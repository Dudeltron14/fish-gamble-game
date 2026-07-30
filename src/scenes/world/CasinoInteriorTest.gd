extends Node2D

const TILES := preload("res://assets/casino_interior/CasinoInteriorTileset.tres")
const FISHERMAN := preload("res://assets/free-fishing-game-assets-pixel-art-pack/1 Fisherman/Fisherman_idle.png")
const ORIGIN := Vector2i(14, 7)

func _ready() -> void:

	var room := TileMapLayer.new()
	room.tile_set = TILES
	add_child(room)
	for y: int in 9:
		for x: int in 13:
			_place(room, Vector2i(x, y), Vector2i((x + y) % 4, 0))
	for x: int in 13:
		_place(room, Vector2i(x, 0), Vector2i(x % 5, 1))
		_place(room, Vector2i(x, 1), Vector2i(x % 5, 1))
	for y: int in 9:
		_place(room, Vector2i(0, y), Vector2i(5, y % 2))
		_place(room, Vector2i(12, y), Vector2i(5, y % 2))
	for y: int in 2:
		for x: int in 2:
			_place(room, Vector2i(2 + x, 3 + y), Vector2i(x, 2 + y))
	for x: int in 3:
		_place(room, Vector2i(6 + x, 3), Vector2i(2 + x, 2))
	_place(room, Vector2i(7, 5), Vector2i(3, 3))
	_place(room, Vector2i(10, 2), Vector2i(4, 3))
	_place(room, Vector2i(6, 8), Vector2i(4, 4))
	_place(room, Vector2i(6, 7), Vector2i(0, 5))
	_place(room, Vector2i(7, 7), Vector2i(1, 5))

	var player := Sprite2D.new()
	player.texture = FISHERMAN
	player.region_enabled = true
	player.region_rect = Rect2(0, 0, 48, 48)
	player.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player.position = Vector2(ORIGIN + Vector2i(9, 6)) * 32.0 + Vector2(16, 16)
	add_child(player)

func _place(room: TileMapLayer, cell: Vector2i, atlas: Vector2i) -> void:
	room.set_cell(ORIGIN + cell, 0, atlas)
