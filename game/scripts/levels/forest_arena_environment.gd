@tool
extends Node2D

const TILE_SIZE := 32
const MAP_W := 72
const MAP_H := 46
const MAP_ORIGIN := Vector2(-MAP_W * TILE_SIZE * 0.5, -MAP_H * TILE_SIZE * 0.5)
const ATLAS_PATH := "res://assets/tiles/oozeborne_forest_atlas.png"
const PROP_ATLAS_PATH := "res://assets/tiles/oozeborne_swamp_props.png"

const GRASS := Vector2i(0, 0)
const GRASS_LIGHT := Vector2i(1, 0)
const GRASS_DARK := Vector2i(2, 0)
const GRASS_MOSS := Vector2i(4, 0)
const FOREST_SHADOW := Vector2i(5, 0)
const DIRT := Vector2i(0, 1)
const DIRT_LIGHT := Vector2i(1, 1)
const MUD := Vector2i(3, 1)
const STONE := Vector2i(4, 1)
const OOZE := Vector2i(1, 2)
const OOZE_DARK := Vector2i(2, 2)
const OOZE_EDGE := Vector2i(4, 2)
const FLOWERS := Vector2i(0, 3)
const ROOTS := Vector2i(1, 3)
const RUIN := Vector2i(2, 3)
const LEAVES := Vector2i(5, 3)

const TREE_TEXTURES := [
	preload("res://assets/sprites/Vegetation/spr_tree1.png"),
	preload("res://assets/sprites/Vegetation/spr_tree2.png"),
	preload("res://assets/sprites/Vegetation/spr_tree3.png"),
	preload("res://assets/sprites/Vegetation/tree.png"),
]
const BUSH_TEXTURES := [
	preload("res://assets/sprites/Vegetation/Bush.png"),
	preload("res://assets/sprites/Vegetation/Bush1.png"),
]

var _tile_set: TileSet
var _source_id := 0
var _prop_texture: Texture2D


func _ready() -> void:
	_build_scene()


func _build_scene() -> void:
	y_sort_enabled = true
	_clear_generated()
	_tile_set = _create_tile_set()
	_prop_texture = _load_image_texture(PROP_ATLAS_PATH)
	_build_tile_layers()
	_build_canopy_shapes()
	_build_tree_line()
	_build_landmark_props()
	_build_collision_bounds()
	_add_spawn_markers()


func _clear_generated() -> void:
	for child in get_children():
		if child.is_in_group("forest_arena_generated"):
			if Engine.is_editor_hint():
				child.free()
			else:
				child.queue_free()


func _create_tile_set() -> TileSet:
	var atlas_texture := _load_image_texture(ATLAS_PATH)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = atlas_texture
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for x in range(8):
		for y in range(4):
			atlas.create_tile(Vector2i(x, y))

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	_source_id = tile_set.add_source(atlas)
	return tile_set


func _load_image_texture(path: String) -> ImageTexture:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(image)


func _build_tile_layers() -> void:
	var ground := _make_layer("GroundTileMap", -40)
	var detail := _make_layer("DetailTileMap", -39)
	var ooze := _make_layer("OozeStreamTileMap", -38)
	var path := _make_layer("PathTileMap", -37)
	var ruins := _make_layer("RuinTileMap", -36)

	for y in range(MAP_H):
		for x in range(MAP_W):
			var cell := Vector2i(x, y)
			ground.set_cell(cell, _source_id, _choose_ground_tile(x, y))
			if _is_noise_detail(x, y, 11):
				detail.set_cell(cell, _source_id, _choose_detail_tile(x, y))

	for y in range(3, MAP_H - 3):
		var cx := int(17 + sin(float(y) * 0.32) * 5.0 + float(y) * 0.36)
		for dx in range(-2, 3):
			var pos := Vector2i(cx + dx, y)
			if _inside(pos):
				ooze.set_cell(pos, _source_id, OOZE if abs(dx) <= 1 else OOZE_EDGE)
		if _inside(Vector2i(cx - 3, y)) and y % 3 != 0:
			ooze.set_cell(Vector2i(cx - 3, y), _source_id, OOZE_DARK)
		if _inside(Vector2i(cx + 3, y)) and y % 4 != 0:
			ooze.set_cell(Vector2i(cx + 3, y), _source_id, OOZE_DARK)

	for x in range(7, MAP_W - 7):
		var y1 := int(MAP_H * 0.50 + sin(float(x) * 0.18) * 3.5)
		_paint_path(path, Vector2i(x, y1), 2)

	for y in range(6, MAP_H - 6):
		var x1 := int(MAP_W * 0.53 + sin(float(y) * 0.22 + 1.7) * 3.0)
		_paint_path(path, Vector2i(x1, y), 1)

	for x in range(29, 39):
		for y in range(18, 28):
			var dist := Vector2(float(x - 34), float(y - 23)).length()
			if dist > 3.1 and dist < 6.8:
				ruins.set_cell(Vector2i(x, y), _source_id, RUIN if (x + y) % 3 != 0 else STONE)

	for x in range(30, 38):
		for y in range(21, 25):
			path.erase_cell(Vector2i(x, y))
			ooze.erase_cell(Vector2i(x, y))
			ruins.set_cell(Vector2i(x, y), _source_id, STONE)

	for x in range(18, 26):
		for y in range(8, 16):
			var local := Vector2(float(x - 22), float(y - 12))
			if local.length() < 4.7:
				ruins.set_cell(Vector2i(x, y), _source_id, MUD if int(local.length()) % 2 == 0 else STONE)

	for x in range(47, 60):
		for y in range(30, 40):
			var local := Vector2(float(x - 53), float(y - 35))
			if local.length() < 5.4 and _hash2(x, y) < 68:
				ruins.set_cell(Vector2i(x, y), _source_id, ROOTS if (x + y) % 2 == 0 else LEAVES)


func _make_layer(layer_name: String, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = _tile_set
	layer.position = MAP_ORIGIN
	layer.z_index = z
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_to_group("forest_arena_generated")
	add_child(layer)
	return layer


func _choose_ground_tile(x: int, y: int) -> Vector2i:
	var border: int = mini(mini(x, MAP_W - 1 - x), mini(y, MAP_H - 1 - y))
	if border < 5:
		return FOREST_SHADOW
	if border < 8:
		return GRASS_DARK if (x + y) % 3 else ROOTS
	var n := _hash2(x, y)
	if n < 9:
		return GRASS_LIGHT
	if n < 18:
		return GRASS_MOSS
	if n < 27:
		return LEAVES
	return GRASS


func _choose_detail_tile(x: int, y: int) -> Vector2i:
	var n := _hash2(x * 3, y * 5)
	if n < 28:
		return FLOWERS
	if n < 54:
		return ROOTS
	return LEAVES


func _paint_path(path: TileMapLayer, center: Vector2i, radius: int) -> void:
	for ox in range(-radius, radius + 1):
		for oy in range(-radius, radius + 1):
			var pos := center + Vector2i(ox, oy)
			if _inside(pos) and abs(ox) + abs(oy) <= radius + 1:
				path.set_cell(pos, _source_id, DIRT_LIGHT if _hash2(pos.x, pos.y) < 45 else DIRT)
	if _inside(center + Vector2i(0, radius + 1)):
		path.set_cell(center + Vector2i(0, radius + 1), _source_id, MUD)


func _build_canopy_shapes() -> void:
	var shadow := Node2D.new()
	shadow.name = "CanopyShadowMasses"
	shadow.z_index = -35
	shadow.add_to_group("forest_arena_generated")
	add_child(shadow)

	_add_shadow_poly(shadow, PackedVector2Array([
		Vector2(-1120, -720), Vector2(-530, -720), Vector2(-620, -520), Vector2(-790, -430),
		Vector2(-1120, -470),
	]), Color(0.0, 0.08, 0.05, 0.42))
	_add_shadow_poly(shadow, PackedVector2Array([
		Vector2(1120, -720), Vector2(580, -720), Vector2(690, -520), Vector2(940, -415),
		Vector2(1120, -500),
	]), Color(0.0, 0.08, 0.05, 0.38))
	_add_shadow_poly(shadow, PackedVector2Array([
		Vector2(-1120, 720), Vector2(-360, 720), Vector2(-460, 510), Vector2(-840, 440),
		Vector2(-1120, 520),
	]), Color(0.0, 0.07, 0.045, 0.43))
	_add_shadow_poly(shadow, PackedVector2Array([
		Vector2(1120, 720), Vector2(410, 720), Vector2(520, 500), Vector2(900, 455),
		Vector2(1120, 545),
	]), Color(0.0, 0.07, 0.045, 0.36))


func _add_shadow_poly(parent: Node, points: PackedVector2Array, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	poly.add_to_group("forest_arena_generated")
	parent.add_child(poly)


func _build_tree_line() -> void:
	var trees := Node2D.new()
	trees.name = "ForestWallDecor"
	trees.y_sort_enabled = true
	trees.add_to_group("forest_arena_generated")
	add_child(trees)

	for x in range(-1050, 1051, 128):
		if abs(x) > 250:
			_add_tree(trees, Vector2(x + _jitter(x, -18, 18), -620 + _jitter(x, -22, 26)), abs(x) % 4)
		if abs(x) > 360:
			_add_tree(trees, Vector2(x + _jitter(x + 9, -26, 20), 620 + _jitter(x, -30, 14)), abs(x + 1) % 4)

	for y in range(-520, 521, 128):
		if abs(y) > 110:
			_add_tree(trees, Vector2(-1030 + _jitter(y, -20, 24), y + _jitter(y + 2, -20, 20)), abs(y + 2) % 4)
		if abs(y) > 170:
			_add_tree(trees, Vector2(1030 + _jitter(y, -24, 20), y + _jitter(y + 4, -20, 20)), abs(y + 3) % 4)

	var clusters := [
		Vector2(-470, -250), Vector2(445, -305), Vector2(-585, 250), Vector2(600, 285),
		Vector2(-210, -430), Vector2(270, 405), Vector2(-820, -40), Vector2(835, 40),
	]
	for i in range(clusters.size()):
		_add_tree(trees, clusters[i], i % 4, 1.35)
		_add_bush(trees, clusters[i] + Vector2(42, 34), i % 2)
		_add_bush(trees, clusters[i] + Vector2(-46, 42), (i + 1) % 2)


func _build_landmark_props() -> void:
	var props := Node2D.new()
	props.name = "ShrineAndSwampProps"
	props.y_sort_enabled = true
	props.add_to_group("forest_arena_generated")
	add_child(props)

	_add_prop(props, Vector2(0, 0), Vector2i(7, 0), 1.7)
	var ring := [
		Vector2(-205, -92), Vector2(0, -145), Vector2(205, -88),
		Vector2(-235, 95), Vector2(235, 95), Vector2(-80, 160), Vector2(92, 158),
	]
	for i in range(ring.size()):
		_add_prop(props, ring[i], Vector2i(0 if i % 2 == 0 else 1, 0), 1.2)

	_add_prop(props, Vector2(-455, -265), Vector2i(6, 0), 1.35)
	_add_prop(props, Vector2(475, 275), Vector2i(6, 0), 1.25)
	_add_prop(props, Vector2(-650, 295), Vector2i(0, 1), 1.6)
	_add_prop(props, Vector2(660, -310), Vector2i(7, 1), 1.45)

	_add_prop(props, Vector2(-505, -60), Vector2i(2, 0), 1.45)
	_add_prop(props, Vector2(470, 66), Vector2i(3, 0), 1.45)

	var mushrooms := [
		Vector2(-730, -335), Vector2(-685, -286), Vector2(-610, -340),
		Vector2(730, 350), Vector2(790, 305), Vector2(665, 300),
		Vector2(420, -470), Vector2(485, -435), Vector2(-390, 475),
	]
	for i in range(mushrooms.size()):
		_add_prop(props, mushrooms[i], Vector2i(4 + (i % 2), 0), 0.85 + float(i % 3) * 0.12)

	var bones_and_stumps := [
		[Vector2(-180, 345), Vector2i(2, 1)],
		[Vector2(195, -350), Vector2i(2, 1)],
		[Vector2(-870, 82), Vector2i(1, 1)],
		[Vector2(880, -96), Vector2i(1, 1)],
	]
	for item in bones_and_stumps:
		_add_prop(props, item[0], item[1], 1.0)

	for i in range(7):
		_add_prop(props, Vector2(-360 + i * 115, 210 + sin(float(i)) * 26.0), Vector2i(i % 8, 2), 0.78)


func _add_prop(parent: Node, pos: Vector2, atlas_coord: Vector2i, scale_mul := 1.0) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _prop_texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(atlas_coord.x * 64, atlas_coord.y * 64, 64, 64)
	sprite.position = pos
	sprite.scale = Vector2.ONE * scale_mul
	sprite.add_to_group("forest_arena_generated")
	parent.add_child(sprite)


func _add_tree(parent: Node, pos: Vector2, texture_index: int, scale_mul := 1.0) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = TREE_TEXTURES[texture_index % TREE_TEXTURES.size()]
	sprite.position = pos
	sprite.scale = Vector2.ONE * (1.35 + float(_hash2(int(pos.x), int(pos.y)) % 35) / 100.0) * scale_mul
	sprite.flip_h = _hash2(int(pos.y), int(pos.x)) % 2 == 0
	sprite.add_to_group("forest_arena_generated")
	parent.add_child(sprite)


func _add_bush(parent: Node, pos: Vector2, texture_index: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = BUSH_TEXTURES[texture_index % BUSH_TEXTURES.size()]
	sprite.position = pos
	sprite.scale = Vector2.ONE * (1.55 + float(_hash2(int(pos.x), int(pos.y)) % 30) / 100.0)
	sprite.flip_h = _hash2(int(pos.x), int(pos.y)) % 2 == 0
	sprite.add_to_group("forest_arena_generated")
	parent.add_child(sprite)


func _build_collision_bounds() -> void:
	var body := StaticBody2D.new()
	body.name = "ArenaBounds"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("forest_arena_generated")
	add_child(body)

	_add_wall(body, "NorthWall", Vector2(0, -736), Vector2(2304, 96))
	_add_wall(body, "SouthWall", Vector2(0, 736), Vector2(2304, 96))
	_add_wall(body, "WestWall", Vector2(-1152, 0), Vector2(96, 1472))
	_add_wall(body, "EastWall", Vector2(1152, 0), Vector2(96, 1472))


func _add_wall(parent: Node, wall_name: String, pos: Vector2, size: Vector2) -> void:
	var shape := CollisionShape2D.new()
	shape.name = wall_name
	shape.position = pos
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	parent.add_child(shape)


func _add_spawn_markers() -> void:
	var player_spawn := Marker2D.new()
	player_spawn.name = "PlayerSpawn"
	player_spawn.position = Vector2(-120, 64)
	player_spawn.add_to_group("forest_arena_generated")
	add_child(player_spawn)

	var enemy_ring := Node2D.new()
	enemy_ring.name = "EnemySpawnRing"
	enemy_ring.add_to_group("forest_arena_generated")
	add_child(enemy_ring)
	for i in range(8):
		var marker := Marker2D.new()
		marker.name = "EnemySpawn%02d" % (i + 1)
		var angle := TAU * float(i) / 8.0
		marker.position = Vector2(cos(angle), sin(angle)) * Vector2(650, 360)
		enemy_ring.add_child(marker)


func _inside(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < MAP_W and pos.y < MAP_H


func _is_noise_detail(x: int, y: int, threshold: int) -> bool:
	var border: int = mini(mini(x, MAP_W - 1 - x), mini(y, MAP_H - 1 - y))
	return _hash2(x, y) < threshold and border > 7


func _hash2(x: int, y: int) -> int:
	return int(abs((x * 928371 + y * 689287 + 1376312589) % 100))


func _jitter(seed_value: int, min_value: int, max_value: int) -> int:
	return min_value + int(abs((seed_value * 1103515245 + 12345) % maxi(1, max_value - min_value + 1)))
