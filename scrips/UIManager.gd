#UIManager
extends Control

@export var seed_input: LineEdit 
@export var world_manager: Node3D 

func _on_generate_button_pressed():
	if not world_manager or not seed_input:
		print("ERROR: WorldManager or SeedInput not assigned in UIManager inspector!")
		return

	var seed_text = seed_input.text
	
	var new_seed = int(seed_text) if seed_text.is_valid_int() else hash(seed_text)
	
	world_manager.regenerate_world(new_seed)
