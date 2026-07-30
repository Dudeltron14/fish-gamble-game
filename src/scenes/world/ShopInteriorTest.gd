extends Node2D

const TILES := preload("res://assets/shop_interior/ShopInteriorTileset.tres")
const PROPS := preload("res://assets/shop_interior/ShopInteriorProps.tres")
const FISHERMAN := preload("res://assets/free-fishing-game-assets-pixel-art-pack/1 Fisherman/Fisherman_idle.png")
const ORIGIN := Vector2i(14, 7)

func _ready() -> void:
	var room := TileMapLayer.new()
	room.tile_set = TILES
	add_child(room)
	var props := TileMapLayer.new()
	props.tile_set = PROPS
	add_child(props)
	for y: int in 8:
		for x: int in 11:
			_place(room, Vector2i(x, y), Vector2i((x + y) % 4, 0))
	for x: int in 11:
		_place(room, Vector2i(x, 0), Vector2i(4, 1))
		_place(room, Vector2i(x, 1), Vector2i(4, 1))
	for y: int in 8:
		_place(room, Vector2i(0, y), Vector2i(5, 1))
		_place(room, Vector2i(10, y), Vector2i(5, 1))
	for x: int in 3:
		_place(room, Vector2i(4 + x, 3), Vector2i(1 + x, 2))
	_place(room, Vector2i(2, 2), Vector2i(5, 2))
	_place(room, Vector2i(8, 2), Vector2i(6, 2))
	_place(room, Vector2i(1, 1), Vector2i(4, 2))
	_place(room, Vector2i(9, 1), Vector2i(7, 2))
	_place(room, Vector2i(5, 7), Vector2i(0, 2))
	_prop(props, Vector2i(1, 6), Vector2i(0, 0))
	_prop(props, Vector2i(2, 6), Vector2i(2, 0))
	_prop(props, Vector2i(8, 6), Vector2i(1, 0))
	_prop(props, Vector2i(4, 6), Vector2i(4, 0))
	_prop(props, Vector2i(1, 4), Vector2i(0, 1))
	_prop(props, Vector2i(7, 4), Vector2i(3, 1))
	_prop(props, Vector2i(4, 2), Vector2i(6, 0))

	var player := Sprite2D.new()
	player.texture = FISHERMAN
	player.region_enabled = true
	player.region_rect = Rect2(0, 0, 48, 48)
	player.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player.position = Vector2(ORIGIN + Vector2i(5, 5)) * 32.0 + Vector2(16, 16)
	add_child(player)

func _place(room: TileMapLayer, cell: Vector2i, atlas: Vector2i) -> void:
	room.set_cell(ORIGIN + cell, 0, atlas)

func _prop(props: TileMapLayer, cell: Vector2i, atlas: Vector2i) -> void:
	props.set_cell(ORIGIN + cell, 0, atlas)
