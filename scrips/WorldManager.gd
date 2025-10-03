#worldmanager
extends Node3D

@export var chunk_radius: int = 3
@export var chunk_size: int = 5
@export var player: Node3D

var world_seed: int = 12345

const ChunkScene = preload("res://Chunk.tscn")
const HEX_SIZE = 1.0

var loaded_chunks := {}
var last_player_chunk := Vector2i(9999, 9999)


@onready var seed_input: LineEdit = $CanvasLayer/SeedInput
@onready var generate_button: Button = $CanvasLayer/GenerateButton

func _ready():
	if not player:
		push_error("Assign a Player node to WorldManager!")
		set_process(false)
		return
	
	generate_button.pressed.connect(_on_generate_pressed)
	seed_input.text = str(world_seed)
	
	_update_chunks()

func _process(_delta):
	if not is_instance_valid(player): return
	var current_chunk = _world_to_chunk_coords(player.global_position)
	if current_chunk != last_player_chunk:
		_update_chunks()
		last_player_chunk = current_chunk

func regenerate_world(new_seed: int):
	world_seed = new_seed
	seed_input.text = str(new_seed)
	
	for chunk in loaded_chunks.values():
		if is_instance_valid(chunk):
			chunk.queue_free()
	loaded_chunks.clear()
	
	last_player_chunk = Vector2i(9999, 9999)
	_update_chunks()

func _on_generate_pressed():
	var input_text = seed_input.text
	if input_text.is_valid_int():
		regenerate_world(input_text.to_int())
	else:
		print("Enter a valid number for the seed!")

func _update_chunks():
	if not is_instance_valid(player): return
	var player_chunk = _world_to_chunk_coords(player.global_position)
	var required_chunks := {}

	for q_offset in range(-chunk_radius, chunk_radius + 1):
		var r1 = max(-chunk_radius, -q_offset - chunk_radius)
		var r2 = min(chunk_radius, -q_offset + chunk_radius)
		for r_offset in range(r1, r2 + 1):
			var key = player_chunk + Vector2i(q_offset, r_offset)
			required_chunks[key] = true
			if not loaded_chunks.has(key):
				_load_chunk(key)

	var to_unload = []
	for key in loaded_chunks.keys():
		if not required_chunks.has(key):
			to_unload.append(key)
	for key in to_unload:
		_unload_chunk(key)

func _world_to_chunk_coords(world_pos: Vector3) -> Vector2i:
	var q_frac = (sqrt(3)/3.0 * world_pos.x - 1.0/3.0 * world_pos.z) / HEX_SIZE
	var r_frac = (2.0/3.0 * world_pos.z) / HEX_SIZE
	var chunk_width = float(chunk_size * 2 + 1)
	return Vector2i(floor(q_frac / chunk_width), floor(r_frac / chunk_width))

func _load_chunk(key: Vector2i):
	var chunk = ChunkScene.instantiate()
	chunk.name = "Chunk_%d_%d" % [key.x, key.y]
	chunk.chunk_q = key.x
	chunk.chunk_r = key.y
	chunk.world_seed = world_seed
	add_child(chunk)
	loaded_chunks[key] = chunk
	
	chunk.generate()

func _unload_chunk(key: Vector2i):
	if loaded_chunks.has(key) and is_instance_valid(loaded_chunks[key]):
		loaded_chunks[key].queue_free()
		loaded_chunks.erase(key)
