# Chunk
extends Node3D

@export var chunk_size: int = 5
@export var chunk_q: int = 0
@export var chunk_r: int = 0

# --- Materials ---
@export var water_material: Material
@export var sand_material: Material
@export var grass_material: Material
@export var snow_material: Material

var world_seed: int = 12345
const HEX_SIZE = 1.0

# Signal to notify the main thread when the chunk data is ready
signal chunk_generated(data)

var rng: RandomNumberGenerator
var height_noise: FastNoiseLite
var biome_noise: FastNoiseLite  # For biome variation

# Public function WorldManager will call.
func generate():
	chunk_generated.connect(_on_chunk_generated, CONNECT_ONE_SHOT)
	var thread = Thread.new()
	thread.start(_thread_generate_data)

# function runs ON A SEPARATE THREAD.
func _thread_generate_data():
	# Initial Setup
	rng = RandomNumberGenerator.new()
	rng.seed = world_seed + (chunk_q * 73856093) + (chunk_r * 19349663)

	height_noise = FastNoiseLite.new()
	height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	height_noise.seed = world_seed
	height_noise.frequency = 0.02  # Lower for larger, smoother features
	height_noise.fractal_octaves = 4  
	height_noise.fractal_lacunarity = 2.0
	height_noise.fractal_gain = 0.5

	biome_noise = FastNoiseLite.new()  # Biome noise for plains/hills/mountains
	biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	biome_noise.seed = world_seed + 42
	biome_noise.frequency = 0.005  # Very low for large biomes
	biome_noise.fractal_octaves = 2
	biome_noise.fractal_lacunarity = 2.0
	biome_noise.fractal_gain = 0.4

	# Prepare Data Containers
	var surfaces = {
		"water": SurfaceTool.new(),
		"sand": SurfaceTool.new(),
		"grass": SurfaceTool.new(),
		"snow": SurfaceTool.new()
	}
	for type in surfaces:
		surfaces[type].begin(Mesh.PRIMITIVE_TRIANGLES)

	var vertex_counts = {
		"water": 0,
		"sand": 0,
		"grass": 0,
		"snow": 0
	}

	var trees_to_spawn = []

	# Loop through all hexes and generate vertex data 
	for dq in range(-chunk_size, chunk_size + 1):
		for dr in range(max(-chunk_size, -dq - chunk_size), min(chunk_size, -dq + chunk_size) + 1):
			var q = chunk_q * (chunk_size*2+1) + dq
			var r = chunk_r * (chunk_size*2+1) + dr
			
			var hex_center_pos = _axial_to_world(q, r)
			var noise_val = (height_noise.get_noise_2d(float(q), float(r)) + 1.0) / 2.0
			var biome_val = (biome_noise.get_noise_2d(float(q), float(r)) + 1.0) / 2.0
			
			# Biome-based height for varied terrain (plains flat, mountains tall)
			var base_height = 0.5
			var height_amp = 1.0
			var tree_prob = 0.1
			if biome_val < 0.4:  # flat for easy movement
				base_height = 1.0
				height_amp = 0.5
				tree_prob = 0.05  # Fewer trees in open plains
			elif biome_val < 0.7:  # Hills: rolling, forested
				base_height = 1.0
				height_amp = 2.0
				tree_prob = 0.15  # More trees for forests
			else:  # Mountains: tall and dramatic
				base_height = 1.5
				height_amp = 4.0
				tree_prob = 0.08  # Sparse trees on heights
			
			var height = base_height + noise_val * height_amp
			
			# Terrain type based on height (natural: snow on peaks)
			var terrain_type: String
			if height < 1.0:
				terrain_type = "water"
				height = 1.0  # Flat sea level for lakes/oceans (no deep holes)
			elif height < 1.5:
				terrain_type = "sand"
			elif height < 4.0:
				terrain_type = "grass"
			else:
				terrain_type = "snow"
			
			
			var st = surfaces[terrain_type]
			var base_idx = vertex_counts[terrain_type]
			_add_hex_prism_to_surface(st, hex_center_pos, height, base_idx)
			vertex_counts[terrain_type] += 14  

			# Trees (fixed size, only on grass)
			if terrain_type == "grass" && rng.randf() < tree_prob:
				trees_to_spawn.append({"pos": hex_center_pos, "height": height})

	# Meshes and Package Data
	var mesh_data = {}
	for type in surfaces:
		var st = surfaces[type]
		st.generate_normals()
		mesh_data[type] = st.commit()

	var final_data = {
		"meshes": mesh_data,
		"trees": trees_to_spawn
	}
	
	call_deferred("emit_signal", "chunk_generated", final_data)

# This function runs ON THE MAIN THREAD after the signal is received.
func _on_chunk_generated(data: Dictionary):
	if not is_instance_valid(self): return

	var all_terrain_meshes = []

	# Create MeshInstances for terrain
	for type in data.meshes:
		var mesh: ArrayMesh = data.meshes[type]
		all_terrain_meshes.append(mesh)

		var mi = MeshInstance3D.new()
		mi.mesh = mesh
		add_child(mi)

		match type:
			"water": mi.material_override = water_material
			"sand": mi.material_override = sand_material
			"grass": mi.material_override = grass_material
			"snow": mi.material_override = snow_material

	# Create a single StaticBody for all terrain collision
	if not all_terrain_meshes.is_empty():
		var terrain_body = StaticBody3D.new()
		var collision_shape = CollisionShape3D.new()
		
		# Merge all meshes into one for the collision shape generation using SurfaceTool
		var merge_tool = SurfaceTool.new()
		merge_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mesh_to_merge in all_terrain_meshes:
			# Append the geometry from each mesh into our tool
			merge_tool.append_from(mesh_to_merge, 0, Transform3D())
		
		var combined_mesh = merge_tool.commit()

		# create_trimesh_shape is good for complex, static ground
		collision_shape.shape = combined_mesh.create_trimesh_shape()
		terrain_body.add_child(collision_shape)
		add_child(terrain_body)

	#  visuals and collision for trees 
	if not data.trees.is_empty():
		var tree_body = StaticBody3D.new()
		add_child(tree_body)

		for tree_info in data.trees:
			var pos: Vector3 = tree_info.pos
			var hex_height: float = tree_info.height
			
			var trunk_height = 2.0  
			var trunk_radius = 0.2
			var leaves_radius = 0.8
			
			var trunk_mi = MeshInstance3D.new()
			trunk_mi.mesh = CylinderMesh.new()
			trunk_mi.mesh.top_radius = trunk_radius
			trunk_mi.mesh.bottom_radius = trunk_radius
			trunk_mi.mesh.height = trunk_height
			trunk_mi.position = pos + Vector3(0, hex_height + trunk_height / 2.0, 0)
			add_child(trunk_mi)
			
			var leaves_mi = MeshInstance3D.new()
			leaves_mi.mesh = SphereMesh.new()
			leaves_mi.mesh.radius = leaves_radius
			leaves_mi.mesh.height = leaves_radius * 2.0
			leaves_mi.position = pos + Vector3(0, hex_height + trunk_height + leaves_radius * 0.5, 0)  
			add_child(leaves_mi)

			var trunk_coll = CollisionShape3D.new()
			trunk_coll.shape = CylinderShape3D.new()
			trunk_coll.shape.radius = trunk_radius
			trunk_coll.shape.height = trunk_height
			trunk_coll.position = trunk_mi.position
			tree_body.add_child(trunk_coll)
			
			var leaves_coll = CollisionShape3D.new()
			leaves_coll.shape = SphereShape3D.new()
			leaves_coll.shape.radius = leaves_radius
			leaves_coll.position = leaves_mi.position
			tree_body.add_child(leaves_coll)

#Helper functions
func _axial_to_world(q: int, r: int) -> Vector3:
	var x = HEX_SIZE * (sqrt(3.0) * q + sqrt(3.0)/2.0 * r)
	var z = HEX_SIZE * (3.0/2.0 * r)
	return Vector3(x, 0, z)

func _add_hex_prism_to_surface(st: SurfaceTool, center_pos: Vector3, height: float, base_idx: int):
	# Bottom at y=0, top at y=height (no holes)
	# TOP outer vertices (indices 0-5)
	for i in 6:
		var angle = PI/3.0 * i
		st.add_vertex(center_pos + Vector3(cos(angle) * HEX_SIZE, height, sin(angle) * HEX_SIZE))
	# BOTTOM outer vertices (indices 6-11)
	for i in 6:
		var angle = PI/3.0 * i
		st.add_vertex(center_pos + Vector3(cos(angle) * HEX_SIZE, 0, sin(angle) * HEX_SIZE))
	# TOP center (index 12)
	st.add_vertex(center_pos + Vector3(0, height, 0))
	# BOTTOM center (index 13)
	st.add_vertex(center_pos + Vector3(0, 0, 0))

	# Top face (triangles from center)
	for i in 6:
		st.add_index(base_idx + 12)
		st.add_index(base_idx + i)
		st.add_index(base_idx + (i + 1) % 6)

	# Bottom face (triangles from center, reversed winding)
	for i in 6:
		st.add_index(base_idx + 13)
		st.add_index(base_idx + 6 + (i + 1) % 6)
		st.add_index(base_idx + 6 + i)

	# Side walls (quads split into triangles)
	for i in 6:
		var top_curr = base_idx + i
		var top_next = base_idx + (i + 1) % 6
		var bot_curr = base_idx + 6 + i
		var bot_next = base_idx + 6 + (i + 1) % 6
		
		st.add_index(top_curr)
		st.add_index(top_next)
		st.add_index(bot_curr)
		
		st.add_index(top_next)
		st.add_index(bot_next)
		st.add_index(bot_curr)
