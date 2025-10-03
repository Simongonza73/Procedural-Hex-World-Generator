Procedural Hex World Generator Godot 4.5

infinite procedural world generator for Godot 4.5 using hexagonal grids with dynamic chunk loading, multithreaded generation, and biome-based terrain.

It contains

- Infinite Hex-Based World: Seamless procedural generation using axial hexagonal coordinates
- Dynamic Chunk Loading: Loads/unloads chunks based on player position for optimal performance
- Multithreaded Generation: Non-blocking terrain generation using worker threads
- Biome System: Three distinct biomes (Plains, Hills, Mountains) with varying terrain characteristics (needs fixes)
- Procedural Vegetation: Trees spawn based on biome type with proper collision
- Seeded Generation: Reproducible worlds using custom seeds
- Optimized Collision: Efficient trimesh collision for terrain and separate tree collision bodies


    ![git1](https://github.com/user-attachments/assets/64cb7e3a-c0c3-4fed-8f24-0c2c91069ef8)


 Terrain Generation Pipeline

1. Noise Sampling: Dual-noise system (height + biome)
2. Biome Classification: 
   Plains (biome < 0.4): Flat, sparse trees, easy traversal
   Hills (0.4-0.7): Rolling terrain, dense forests
   Mountains (> 0.7): Dramatic peaks, sparse vegetation
3. Height Mapping:
   Water: < 1.0 units
   Sand: 1.0-1.5 units
   Grass: 1.5-4.0 units
   Snow: > 4.0 units
4. Mesh Construction: Hexagonal prisms with top, bottom, and side faces
5. Collision Generation: Trimesh for terrain, primitives for trees
6. Player movement(Enable Inputmap): W,A,S,D. toggle_mouse (Escape)
7. Seed: you can change seed when start the game and press generate

 Installation

1. Copy these scripts to your Godot project:
   - `WorldManager.gd`
   - `Chunk.gd`
   - `HexTile.gd` (optional, for reference)

2. Create required materials in Godot:
   - Water Material (Blue, transparent)   Water needs fixes
   - Sand Material (Beige)
   - Grass Material (Green)
   - Snow Material (White)

3. Set up the scene tree:
```
WorldManager (Node3D)
    ├── CanvasLayer
    │   ├── SeedInput (LineEdit)
    │   └── GenerateButton (Button)
    └── [Attach WorldManager.gd]
```

4. Assign:
   - Player node reference to WorldManager
   - Materials to Chunk.tscn exports

### Basic Usage

```gdscript
# Change world seed programmatically
$WorldManager.regenerate_world(42)

# Adjust chunk loading distance
$WorldManager.chunk_radius = 5  # More chunks = larger view distance

# Modify chunk density
$WorldManager.chunk_size = 7  # Larger chunks = fewer chunk transitions
```

Configuration

WorldManager Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `chunk_radius` | 3 | Number of chunks to load around player |
| `chunk_size` | 5 | Hexes per chunk (radius) |
| `world_seed` | 12345 | World generation seed |

### Chunk Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `height_noise.frequency` | 0.02 | Terrain feature size (lower = larger) |
| `biome_noise.frequency` | 0.005 | Biome region size |
| `fractal_octaves` | 4 | Detail level (higher = more detail) |

### Performance Tips

- **Lower `chunk_radius`** for better FPS on lower-end hardware
- **Increase `chunk_size`** to reduce chunk loading frequency
- Adjust `fractal_octaves` to balance detail vs. performance
- Tree density controlled via `tree_prob` (default: 0.05-0.15)

## Customization

### Adding New Terrain Types

```gdscript
# In Chunk.gd _thread_generate_data()
if height < YOUR_THRESHOLD:
    terrain_type = "lava"  # Add to surfaces dictionary
```

### Modifying Tree Generation

```gdscript
# In Chunk.gd after terrain type determination
if terrain_type == "snow" && rng.randf() < 0.2:
    trees_to_spawn.append({
        "pos": hex_center_pos, 
        "height": height,
        "type": "pine"  # Custom tree types
    })
```

### Thread Safety

- Chunk generation runs on separate threads
- Signal-based communication with main thread
- Deferred mesh instantiation for thread safety

Coordinate Systems

- **Axial Coordinates**: (q, r) hexagonal grid
- **World Coordinates**: 3D positions calculated from axial
- **Chunk Coordinates**: Grouping of hexes for efficient loading


## Troubleshooting

**Issue**: Holes/gaps in terrain  
**Solution**: Ensure `height` never goes below water level (min 1.0)

**Issue**: Poor performance  
**Solution**: Reduce `chunk_radius` or disable tree collision

**Issue**: Seams between chunks  
**Solution**: Verify `HEX_SIZE` constant matches across scripts
