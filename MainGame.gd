extends Node3D

@onready var player = $PlayerCharacter3D
@onready var terrain_manager = $TerrainManager
@onready var loading_screen = $LoadingLayer
@onready var bg_music_player = $AudioStreamPlayer

const GAME_MUSIC = preload("res://sfx/forest-birds-55305.mp3")

# Optional periodic performance log, enabled with bestgame/debug/perf_log.
# Uses the engine's own Performance monitors so frame cost can be tracked from
# the console instead of re-running a GPU profile.
var _perf_log_enabled: bool = false
var _perf_log_timer: float = 0.0

func _process(delta):
	if not _perf_log_enabled:
		return
	_perf_log_timer += delta
	if _perf_log_timer < 2.0:
		return
	_perf_log_timer = 0.0
	print("[perf] fps=%d draws=%d objects=%d nodes=%d physics=%.2fms process=%.2fms mem=%.0fMB" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
	])

func _ready():
	_perf_log_enabled = bool(ProjectSettings.get_setting("bestgame/debug/perf_log", false))
	set_process(_perf_log_enabled)

	# Start in Loading State
	if loading_screen:
		loading_screen.visible = true
	
	# Disable player movement/input
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Ensure cursor is visible during loading (overriding Player's _ready)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Listen for terrain completion
	if terrain_manager:
		terrain_manager.initial_generation_finished.connect(_on_terrain_ready)

func _on_terrain_ready():
	print("Terrain Ready!")
	
	# Hide Loading Screen
	if loading_screen:
		loading_screen.visible = false
		# Optional: Queue free if you never want it back
		# loading_screen.queue_free()
	
	# Enable Player
	if player:
		player.process_mode = Node.PROCESS_MODE_INHERIT
		
	# Switch to game music
	if bg_music_player:
		bg_music_player.stream = GAME_MUSIC
		bg_music_player.play()
		
	# Capture Mouse for Gameplay
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
