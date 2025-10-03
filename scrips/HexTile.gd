# hextile
extends Node3D

@export var q: int = 0
@export var r: int = 0
@export var terrain_type: String = "grass" 
@export var has_tree: bool = false
@export var height: float = 0.5  # Height of the 3D hex prism

const HEX_SIZE = 1.0 

func _ready():
	# Set position (with Y = half-height, so the prism sits on Y=0)
	position = axial_to_world(q, r)
	position.y = height / 2
	update_visual()

func axial_to_world(hex_q: int, hex_r: int) -> Vector3:
	# Pointy-top hex position logic 
	var x = HEX_SIZE * (sqrt(3) * hex_q + sqrt(3)/2.0 * hex_r)
	var z = HEX_SIZE * (3.0/2.0 * hex_r)
	return Vector3(x, 0, z)

func update_visual():
	
	for child in get_children():
		child.queue_free()

	# Set terrain color
	var material_color: Color
	match terrain_type:
		"water":
			material_color = Color.DODGER_BLUE
			height = max(height, 0.2) # Water is short
		"sand":
			material_color = Color.BEIGE
		"snow":
			material_color = Color.WHITE
		_:
			material_color = Color.FOREST_GREEN

	# 3D EXTRUDED HEX PRISM
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = _create_hex_prism(material_color, height)
	add_child(mesh_instance)
	
	# Add collision for the hex prism
	var static_body = StaticBody3D.new()
	add_child(static_body)
	var collision_shape = CollisionShape3D.new()
	static_body.add_child(collision_shape)
	collision_shape.shape = mesh_instance.mesh.create_convex_shape()

	# Add tree (scaled to hex height)
	if has_tree:
		var trunk_mat = StandardMaterial3D.new()
		trunk_mat.albedo_color = Color.SADDLE_BROWN
		var leaves_mat = StandardMaterial3D.new()
		leaves_mat.albedo_color = Color.DARK_GREEN

		# Tree visuals
		var trunk = CSGCylinder3D.new()
		trunk.radius = 0.2
		trunk.height = 1.5 * height
		trunk.material = trunk_mat
		trunk.position = Vector3(0, height + (trunk.height / 2), 0)
		add_child(trunk)

		var leaves = CSGSphere3D.new()
		leaves.radius = 0.8
		leaves.position = Vector3(0, height + trunk.height, 0)
		leaves.material = leaves_mat
		add_child(leaves)
		
		# Tree collisions (approximated with simple shapes for performance)
		var tree_body = StaticBody3D.new()
		add_child(tree_body)
		
		var trunk_collision = CollisionShape3D.new()
		trunk_collision.shape = CylinderShape3D.new()
		trunk_collision.shape.radius = 0.2
		trunk_collision.shape.height = 1.5 * height
		trunk_collision.position = Vector3(0, height + (trunk.height / 2), 0)
		tree_body.add_child(trunk_collision)
		
		var leaves_collision = CollisionShape3D.new()
		leaves_collision.shape = SphereShape3D.new()
		leaves_collision.shape.radius = 0.8
		leaves_collision.position = Vector3(0, height + trunk.height, 0)
		tree_body.add_child(leaves_collision)

# 3D hex prism (extruded up by 'prism_height')
func _create_hex_prism(color: Color, prism_height: float) -> ArrayMesh:
	var points = PackedVector3Array()
	var indices = PackedInt32Array()

	#  TOP outer vertices (Y = prism_height)
	for i in 6:
		var angle = PI/3 * i
		points.append(Vector3(cos(angle)*HEX_SIZE, prism_height, sin(angle)*HEX_SIZE))
	# BOTTOM outer vertices (Y = 0)
	for i in 6:
		var angle = PI/3 * i
		points.append(Vector3(cos(angle)*HEX_SIZE, 0, sin(angle)*HEX_SIZE))
	# 3. TOP center + BOTTOM center
	points.append(Vector3(0, prism_height, 0)) # Index 12
	points.append(Vector3(0, 0, 0)) # Index 13

	# Make TOP face (triangles from center)
	for i in 6:
		indices.append(12)
		indices.append(i)
		indices.append((i+1)%6)
	# Make BOTTOM face (triangles from center)
	for i in 6:
		indices.append(13)
		indices.append(6 + ((i+1)%6))
		indices.append(6 + i)
	# Make SIDE walls (quads split into triangles)
	for i in 6:
		var top_curr = i
		var top_next = (i+1)%6
		var bot_curr = 6 + i
		var bot_next = 6 + ((i+1)%6)
		indices.append(top_curr); indices.append(top_next); indices.append(bot_curr)
		indices.append(top_next); indices.append(bot_next); indices.append(bot_curr)

	# Build the mesh
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# Add material
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0 # Matte look for terrain
	mesh.surface_set_material(0, mat)
	return mesh
