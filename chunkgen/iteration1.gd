extends Node2D
# chunk generation/unloader holy moly this took 3 years and 15 tutorials

signal brick_broken(layer: TileMapLayer, cell: Vector2i)

@export var hand_layer: TileMapLayer
@export var glow_layer: TileMapLayer
@export var target: Node2D

@export_group("Tiles")
@export var auto_detect_tiles: bool = true
@export var brick_source: int = 0
@export var brick_atlas: Vector2i = Vector2i(12, 69)
@export var brick_alt: int = 0
@export var floor_source: int = 0
@export var floor_atlas: Vector2i = Vector2i(2, 27)
@export var floor_alt: int = 0

@export_group("Generation")
@export var world_seed: int = 1337
@export var chunk_size: int = 16
@export var load_radius: int = 2
@export var unload_radius: int = 4
@export var chunks_per_frame: int = 2
@export var floor_depth: int = 12
@export var debug_draw: bool = false
@export var noise_frequency: float = 0.08
@export_range(-1.0, 1.0) var hollow_threshold: float = 0.55

var brick_layer: TileMapLayer
var floor_layer: TileMapLayer
var noise := FastNoiseLite.new()
var hand_rect := Rect2i()
var floor_row: int = 0

var loaded: Dictionary = {}
# unloaded chunks reload properly 
var broken: Dictionary = {}
var pending: Array[Vector2i] = []
var center_chunk := Vector2i(1 << 30, 1 << 30)
var refresh_timer: float = 0.0

func _ready() -> void:
	add_to_group("chunk_world")

	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = noise_frequency

	if hand_layer == null:
		hand_layer = get_parent().get_node_or_null("TileMapLayer") as TileMapLayer
	if glow_layer == null:
		glow_layer = get_parent().get_node_or_null("actual glowy bedrock") as TileMapLayer
	if hand_layer == null or glow_layer == null:
		push_error("ChunkWorld: couldnt find hand_layer / glow_layer, assign them in the inspector")
		set_process(false)
		return

	hand_rect = hand_layer.get_used_rect().merge(glow_layer.get_used_rect())
	floor_row = hand_rect.end.y - 1
	if auto_detect_tiles:
		_detect_tiles()
	print("hand_rect (cells): ", hand_rect, "  floor_row: ", floor_row)
	print("brick tile: ", brick_source, " ", brick_atlas, "  floor tile: ", floor_source, " ", floor_atlas)
	queue_redraw()

	brick_layer = _make_layer(hand_layer, "GenBricks")
	brick_layer.add_to_group("generated_bricks")
	floor_layer = _make_layer(glow_layer, "GenFloor")

func _detect_tiles() -> void:
	for cell in hand_layer.get_used_cells():
		var data: TileData = hand_layer.get_cell_tile_data(cell)
		if data and data.get_custom_data("breakable"):
			brick_source = hand_layer.get_cell_source_id(cell)
			brick_atlas = hand_layer.get_cell_atlas_coords(cell)
			brick_alt = hand_layer.get_cell_alternative_tile(cell)
			break

	var lowest_y: int = -999999
	for cell in glow_layer.get_used_cells():
		if cell.y > lowest_y:
			lowest_y = cell.y
			floor_source = glow_layer.get_cell_source_id(cell)
			floor_atlas = glow_layer.get_cell_atlas_coords(cell)
			floor_alt = glow_layer.get_cell_alternative_tile(cell)

func _make_layer(source: TileMapLayer, layer_name: String) -> TileMapLayer:
	var layer := source.duplicate() as TileMapLayer
	layer.name = layer_name
	layer.clear()
	# godot yells at me so this i guess
	source.add_sibling.call_deferred(layer)
	return layer

func _process(delta: float) -> void:
	if target == null:
		target = get_tree().get_first_node_in_group("player") as Node2D
		if target == null:
			return
	if not brick_layer.is_inside_tree():
		return

	refresh_timer -= delta
	if refresh_timer <= 0.0:
		refresh_timer = 0.2
		var cell := brick_layer.local_to_map(brick_layer.to_local(target.global_position))
		var cc := _cell_to_chunk(cell)
		if cc != center_chunk:
			center_chunk = cc
			_refresh_chunks()

	var budget := chunks_per_frame
	while budget > 0 and not pending.is_empty():
		_generate_chunk(pending.pop_front())
		budget -= 1

func _cell_to_chunk(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / chunk_size), floori(float(cell.y) / chunk_size))

func _chunk_dist(cc: Vector2i) -> int:
	return maxi(absi(cc.x - center_chunk.x), absi(cc.y - center_chunk.y))

func _refresh_chunks() -> void:
	var wanted: Array[Vector2i] = []
	for dx in range(-load_radius, load_radius + 1):
		for dy in range(-load_radius, load_radius + 1):
			var cc := center_chunk + Vector2i(dx, dy)
			if not loaded.has(cc) and not pending.has(cc):
				wanted.append(cc)
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - center_chunk).length_squared() < (b - center_chunk).length_squared())
	pending.append_array(wanted)

	for key in loaded.keys():
		var cc: Vector2i = key
		if _chunk_dist(cc) > unload_radius:
			_unload_chunk(cc)

func _generate_chunk(cc: Vector2i) -> void:
	if loaded.has(cc) or _chunk_dist(cc) > load_radius:
		return
	loaded[cc] = true
	var origin := cc * chunk_size
	for x in range(chunk_size):
		for y in range(chunk_size):
			var cell := origin + Vector2i(x, y)
			# bounding box no spawny area
			if cell.y >= floor_row + floor_depth or hand_rect.has_point(cell):
				continue
			if cell.y >= floor_row:
				floor_layer.set_cell(cell, floor_source, floor_atlas, floor_alt)
			elif not broken.has(cell) and noise.get_noise_2d(cell.x, cell.y) < hollow_threshold:
				brick_layer.set_cell(cell, brick_source, brick_atlas, brick_alt)

func _unload_chunk(cc: Vector2i) -> void:
	loaded.erase(cc)
	var origin := cc * chunk_size
	for x in range(chunk_size):
		for y in range(chunk_size):
			var cell := origin + Vector2i(x, y)
			brick_layer.erase_cell(cell)
			floor_layer.erase_cell(cell)

func _draw() -> void:
	if not debug_draw or hand_layer == null:
		return
	var ts := Vector2(hand_layer.tile_set.tile_size)
	var top_left := to_local(hand_layer.to_global(Vector2(hand_rect.position) * ts))
	var bottom_right := to_local(hand_layer.to_global(Vector2(hand_rect.end) * ts))
	draw_rect(Rect2(top_left, bottom_right - top_left), Color.RED, false, 4.0)
	var floor_left := to_local(hand_layer.to_global(Vector2(hand_rect.position.x - 40, floor_row) * ts))
	var floor_right := to_local(hand_layer.to_global(Vector2(hand_rect.end.x + 40, floor_row) * ts))
	draw_line(floor_left, floor_right, Color.DEEP_SKY_BLUE, 4.0)

func notify_broken(layer: TileMapLayer, cell: Vector2i) -> void:
	if layer == brick_layer:
		broken[cell] = true
	brick_broken.emit(layer, cell)
