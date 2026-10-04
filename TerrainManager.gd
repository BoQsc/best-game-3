extends Node3D

const WATER_SHADER = preload("res://water.gdshader")
const WATER_LEVEL := 15.0

@export var chunk_scene: PackedScene # Assign MarchingCubesChunk.tscn here
@export var player: Node3D # Assign your Player node here

@export_group("Settings")
@export var render_distance: int = 8 # Increased default
@export var max_concurrent_tasks: int = 4 # Limit threads to prevent freezing (mobile/low-end friendly)
@export var grid_size: int = 32
@export var scale_factor: float = 1.0
@export var terrain_height: float = 30.0

var noise = FastNoiseLite.new()
var active_chunks = {} # Key: Vector3i, Value: Chunk Instance
var chunks_in_queue = {} # Key: Vector3i, Value: true (Fast lookup)
var chunks_to_generate = [] # Array of Vector3i for ordering
var current_active_tasks: int = 0
var _last_coord: Vector3i = Vector3i.ZERO
var has_last_coord: bool = false
var _water: MeshInstance3D
var _water_mesh: PlaneMesh
var _max_render_distance: int = 8
var _quality_check_timer: float = 0.0

const MIN_RENDER_DISTANCE := 4
const QUALITY_CHECK_INTERVAL := 3.0

func _ready():
	noise.seed = randi()
	noise.frequency = 0.02
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_max_render_distance = render_distance

	# A single water plane for the whole visible area (one draw call instead
	# of one transparent plane per chunk).
	_water = MeshInstance3D.new()
	var water_mesh = PlaneMesh.new()
	water_mesh.size = Vector2(1, 1) # sized to the render area in update_chunks()
	_water_mesh = water_mesh
	_water.mesh = water_mesh
	var water_mat = ShaderMaterial.new()
	water_mat.shader = WATER_SHADER
	_water.material_override = water_mat
	add_child(_water)

signal initial_generation_finished

var initial_load_done: bool = false

func _process(delta):
	if not player: return
	
	update_chunks()
	process_generation_queue()
	
	if not initial_load_done and not active_chunks.is_empty() and chunks_to_generate.is_empty() and current_active_tasks == 0:
		initial_load_done = true
		initial_generation_finished.emit()

	# Adaptive quality once the world has settled.
	if initial_load_done:
		_quality_check_timer += delta
		if _quality_check_timer >= QUALITY_CHECK_INTERVAL:
			_quality_check_timer = 0.0
			_adjust_render_distance()

func _adjust_render_distance():
	# Step the view distance down when the frame rate is poor and back up when
	# there is headroom (uses the engine's own FPS reading).
	var fps = Engine.get_frames_per_second()
	if fps < 30 and render_distance > MIN_RENDER_DISTANCE:
		render_distance -= 1
		has_last_coord = false
	elif fps > 55 and render_distance < _max_render_distance:
		render_distance += 1
		has_last_coord = false

func update_chunks():
	var p_pos = player.global_position
	var chunk_world_size = grid_size * scale_factor
	
	var current_chunk_x = int(floor(p_pos.x / chunk_world_size))
	var current_chunk_z = int(floor(p_pos.z / chunk_world_size))
	var current_coord = Vector3i(current_chunk_x, 0, current_chunk_z)

	# The target set only depends on the player's chunk, so skip the rebuild
	# (and the per-frame allocations) while the player stays in the same chunk.
	if has_last_coord and current_coord == _last_coord: return
	_last_coord = current_coord
	has_last_coord = true

	# Keep the shared water plane centred on the player's chunk.
	if _water:
		var span = (render_distance * 2 + 1) * chunk_world_size
		_water_mesh.size = Vector2(span, span)
		_water.position = Vector3(
			current_chunk_x * chunk_world_size + chunk_world_size / 2.0,
			WATER_LEVEL,
			current_chunk_z * chunk_world_size + chunk_world_size / 2.0
		)
	
	# 1. Identify chunks that should exist
	var target_chunks = {}
	for x in range(-render_distance, render_distance + 1):
		for z in range(-render_distance, render_distance + 1):
			var offset = Vector3i(x, 0, z)
			target_chunks[current_coord + offset] = true
	
	# 2. Remove far away chunks
	var chunks_to_remove = []
	for coord in active_chunks.keys():
		if not target_chunks.has(coord):
			chunks_to_remove.append(coord)
	
	for coord in chunks_to_remove:
		if active_chunks[coord]:
			active_chunks[coord].queue_free()
		active_chunks.erase(coord)
	
	# 3. Add new chunks to queue
	var new_chunks = []
	for coord in target_chunks.keys():
		if not active_chunks.has(coord) and not chunks_in_queue.has(coord):
			new_chunks.append(coord)
			chunks_in_queue[coord] = true
	
	if new_chunks.is_empty(): return

	# Sort by distance to player (nearest first)
	new_chunks.sort_custom(func(a, b):
		return a.distance_squared_to(current_coord) < b.distance_squared_to(current_coord)
	)
	
	chunks_to_generate.append_array(new_chunks)

func process_generation_queue():
	if chunks_to_generate.is_empty(): return
	
	# Only start new tasks if we have capacity, and at most two per frame so
	# streaming stays smooth instead of spiking on a single frame.
	var started_this_frame := 0
	while started_this_frame < 2 and current_active_tasks < max_concurrent_tasks and not chunks_to_generate.is_empty():
		var coord = chunks_to_generate.pop_front()
		chunks_in_queue.erase(coord) # Remove from queue lookup
		
		if active_chunks.has(coord): continue # Should not happen but safety check
		
		var chunk = chunk_scene.instantiate()
		add_child(chunk)
		
		var world_pos = Vector3(
			coord.x * grid_size * scale_factor,
			0,
			coord.z * grid_size * scale_factor
		)
		chunk.global_position = world_pos
		
		# Connect signal to release task slot
		chunk.generation_complete.connect(_on_chunk_generation_complete)
		current_active_tasks += 1
		
		# Store reference
		active_chunks[coord] = chunk
		
		# Start generation
		chunk.start_generation(coord, grid_size, 0.0, scale_factor, terrain_height, noise)

func _on_chunk_generation_complete(_coord):
	current_active_tasks -= 1

func modify_terrain(global_pos: Vector3, amount: float, shape: String = "sphere", radius: float = 3.0):
	var chunk_world_size = grid_size * scale_factor
	# radius passed as argument
	
	# Determine range of chunks affected
	var min_x = int(floor((global_pos.x - radius) / chunk_world_size))
	var max_x = int(floor((global_pos.x + radius) / chunk_world_size))
	var min_z = int(floor((global_pos.z - radius) / chunk_world_size))
	var max_z = int(floor((global_pos.z + radius) / chunk_world_size))
	
	for x in range(min_x, max_x + 1):
		for z in range(min_z, max_z + 1):
			var coord = Vector3i(x, 0, z)
			if active_chunks.has(coord):
				var chunk = active_chunks[coord]
				var local_pos = global_pos - chunk.global_position
				chunk.modify_terrain(local_pos, radius, amount, shape)

func modify_road(global_pos: Vector3, amount: float, radius: float = 3.0):
	var chunk_world_size = grid_size * scale_factor
	
	var min_x = int(floor((global_pos.x - radius) / chunk_world_size))
	var max_x = int(floor((global_pos.x + radius) / chunk_world_size))
	var min_z = int(floor((global_pos.z - radius) / chunk_world_size))
	var max_z = int(floor((global_pos.z + radius) / chunk_world_size))
	
	for x in range(min_x, max_x + 1):
		for z in range(min_z, max_z + 1):
			var coord = Vector3i(x, 0, z)
			if active_chunks.has(coord):
				var chunk = active_chunks[coord]
				var local_pos = global_pos - chunk.global_position
				if chunk.has_method("modify_road"):
					chunk.modify_road(local_pos, radius, amount)
