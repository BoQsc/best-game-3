extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
const WATER_LEVEL = 15.0

@onready var camera = $Camera3D

# Weapon Sway & Bobbing
@onready var pistol = $Camera3D/Sketchfab_Scene
@onready var block_holding = $"Camera3D/MeshInstance3D BlockHolding"
@onready var hands = $"Camera3D/Sketchfab_Scene2 handsfists"
@onready var punch_sfx = $AudioStreamPlayerPunch

var pistol_origin: Vector3
var pistol_initial_rotation: Vector3
var hands_origin: Vector3

const PUNCH_SFX = preload("res://sfx/classic-punch-impact-352711.mp3")
# ADS Position: Centered X, slightly higher Y
@export var ads_origin: Vector3 = Vector3(0.002, -0.06, -0.19)
@export var ads_rotation: Vector3 = Vector3(-0.955, 180.735, 0.0) # Default straight forward if model is standard
@export var debug_keep_aim: bool = false
var block_origin: Vector3
var mouse_input: Vector2
var sway_time: float = 0.0
var current_slot: int = 0

# Sway Settings
const SWAY_AMOUNT = 0.002      # How much mouse movement affects position
const SWAY_SMOOTHING = 10.0    # How fast it returns to center
const BOB_FREQ = 10.0          # Speed of walking bob
const BOB_AMP = 0.01           # Distance of walking bob

var environment: Environment
var original_fog_enabled: bool = false
var original_fog_color: Color
var original_fog_density: float

var health: int = 10
var max_health: int = 10

func _ready():
	if DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("player")
	
	# Store initial positions for sway
	if pistol: 
		pistol_origin = pistol.position
		pistol_initial_rotation = pistol.rotation_degrees
		# Set default ads rotation to initial if not set, or maybe manually tune it
		# Let's guess the model needs roughly 180 or 0. 
		# Looking at the Transform3D in previous turn, it seemed complex.
		# We'll stick to interpolation from initial.
		
	if block_holding: block_origin = block_holding.position
	if hands: hands_origin = hands.position
	
	# Get the WorldEnvironment from the scene root
	var world_env = get_node("/root/Node3D/WorldEnvironment")
	if world_env and world_env.environment:
		environment = world_env.environment
		original_fog_enabled = environment.fog_enabled
		original_fog_color = environment.fog_light_color
		original_fog_density = environment.fog_density
		
	update_health_ui()
	
	# Connect to Toolbelt
	var toolbelt = get_node_or_null("/root/Node3D/HUDCanvasLayer/HUDToolbelt")
	if toolbelt:
		toolbelt.slot_changed.connect(_on_slot_changed)
		# Force update for initial state
		_on_slot_changed(0)
	
	if hands:
		var anim_player = hands.get_node_or_null("AnimationPlayer")
		if anim_player:
			anim_player.animation_finished.connect(_on_hands_animation_finished)

func _process(delta):
	handle_weapon_sway(delta)
	handle_hands_actions(delta)

func handle_weapon_sway(delta):
	# Determine Aiming State (Only for Pistol / Slot 0)
	var is_aiming = false
	var target_pistol_origin = pistol_origin
	var target_pistol_rotation = pistol_initial_rotation
	
	if debug_keep_aim or (current_slot == 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		# Check if we are NOT holding modifier keys (modifiers trigger tools)
		if debug_keep_aim or (not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_SHIFT)):
			is_aiming = true
			target_pistol_origin = ads_origin
			target_pistol_rotation = ads_rotation
	
	# 1. Mouse Sway (Lag)
	# Reduce sway significantly while aiming
	var current_sway_amount = SWAY_AMOUNT * 0.1 if is_aiming else SWAY_AMOUNT
	
	# Invert mouse input for drag effect
	var target_sway = Vector3(
		-mouse_input.x * current_sway_amount,
		mouse_input.y * current_sway_amount,
		0
	)
	
	# 2. Movement Bobbing
	# Only bob when moving on floor
	var speed = velocity.length()
	var bob_offset = Vector3.ZERO
	
	# Reduce bobbing while aiming
	var current_bob_amp = BOB_AMP * 0.1 if is_aiming else BOB_AMP
	
	if is_on_floor() and speed > 1.0:
		sway_time += delta * speed
		bob_offset.y = sin(sway_time * BOB_FREQ * 0.5) * current_bob_amp
		bob_offset.x = cos(sway_time * BOB_FREQ) * current_bob_amp * 0.5
	else:
		# Reset time gently or just leave it, snapping back is fine
		pass

	# Combine
	var total_pistol_target = target_pistol_origin + target_sway + bob_offset
	var total_block_target = block_origin + target_sway + bob_offset
	var total_hands_target = hands_origin + target_sway + bob_offset
	
	# Apply with smoothing
	# Use faster smoothing for ADS transition
	var smooth_speed = 20.0 if is_aiming else SWAY_SMOOTHING
	
	if pistol:
		pistol.position = pistol.position.lerp(total_pistol_target, delta * smooth_speed)
		pistol.rotation_degrees = pistol.rotation_degrees.lerp(target_pistol_rotation, delta * smooth_speed)
		
	if block_holding:
		block_holding.position = block_holding.position.lerp(total_block_target, delta * SWAY_SMOOTHING)
		
	if hands:
		hands.position = hands.position.lerp(total_hands_target, delta * SWAY_SMOOTHING)
	
	# Reset mouse input frame-by-frame (otherwise it drifts if no input)
	mouse_input = Vector2.ZERO

func handle_hands_actions(delta):
	if not hands or not hands.visible:
		return
	
	var anim_player = hands.get_node_or_null("AnimationPlayer")
	if not anim_player:
		return
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# Only play if not already playing punch to avoid restarting mid-punch
		if anim_player.current_animation != "arms_armature|Combat_punch_right":
			anim_player.play("arms_armature|Combat_punch_right")
			if punch_sfx:
				punch_sfx.stream = PUNCH_SFX
				punch_sfx.pitch_scale = randf_range(0.9, 1.1)
				punch_sfx.play()
			
			# Perform Raycast for Hit Detection
			var space_state = get_world_3d().direct_space_state
			var center_screen = get_viewport().get_visible_rect().size / 2
			var from = camera.project_ray_origin(center_screen)
			var to = from + camera.project_ray_normal(center_screen) * 2.5 # Short range for melee (2.5m)
			var query = PhysicsRayQueryParameters3D.create(from, to)
			var result = space_state.intersect_ray(query)
			
			if result:
				if result.collider.is_in_group("zombies") and result.collider.has_method("take_damage"):
					result.collider.take_damage(1)
				elif result.collider.is_in_group("blocks") and result.collider.has_method("take_damage"):
					result.collider.take_damage(1)
				else:
					# Terrain Interaction (Digging)
					var tm = get_node_or_null("/root/Node3D/TerrainManager")
					if tm:
						tm.modify_terrain(result.position, 1.5, "sphere", 1.0) # Smaller hole than pistol

func _on_hands_animation_finished(anim_name):
	if anim_name == "arms_armature|Combat_punch_right":
		if hands and hands.visible: # Ensure hands are still active
			var anim_player = hands.get_node_or_null("AnimationPlayer")
			if anim_player:
				anim_player.play("arms_armature|Combat_idle")

func _on_slot_changed(index):
	current_slot = index
	if index == 0:
		# Pistol
		if pistol: pistol.visible = true
		if block_holding: block_holding.visible = false
		if hands: hands.visible = false
	elif index == 1:
		# Block (Box)
		if pistol: pistol.visible = false
		if block_holding:
			block_holding.visible = true
			block_holding.mesh = BoxMesh.new()
		if hands: hands.visible = false
	elif index == 2:
		# Ramp (Prism)
		if pistol: pistol.visible = false
		if block_holding:
			block_holding.visible = true
			var prism = PrismMesh.new()
			prism.left_to_right = 0.0 # Ramp shape
			block_holding.mesh = prism
		if hands: hands.visible = false
	else:
		# Hands (Fists)
		if pistol: pistol.visible = false
		if block_holding: block_holding.visible = false
		if hands:
			hands.visible = true
			var anim_player = hands.get_node_or_null("AnimationPlayer")
			if anim_player:
				anim_player.play("arms_armature|Combat_idle")

func take_damage(amount: int):
	health -= amount
	update_health_ui()
	
	if health <= 0:
		die()

func die():
	# Simple respawn
	get_tree().reload_current_scene()

func update_health_ui():
	var health_bar = get_node_or_null("/root/Node3D/CanvasLayer/HUDToolbelt/HealthBar")
	if health_bar:
		# Assume initial width is full health. 
		# Wait, HealthBar is a ColorRect. We can scale its x-size or pivot.
		# Or better, set its anchor_right.
		var pct = float(health) / float(max_health)
		# HealthBar was anchor_right=1.0. We can change anchor_right to pct.
		health_bar.anchor_right = pct

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		mouse_input = event.relative # Capture for sway
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

	# Touch controls (mobile and touch-capable web):
	# left half of the screen = walk forward, right half = jump/swim up,
	# dragging anywhere = look around.
	elif event is InputEventScreenDrag:
		mouse_input = event.relative
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	elif event is InputEventScreenTouch:
		var half_width = get_viewport().get_visible_rect().size.x * 0.5
		if event.pressed:
			if event.position.x < half_width:
				Input.action_press("move_forward")
			else:
				Input.action_press("ui_accept")
		else:
			Input.action_release("move_forward")
			Input.action_release("ui_accept")
	
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	var is_underwater = global_position.y < WATER_LEVEL - 1.0 # Slight buffer
	
	if is_underwater:
		handle_swimming(delta)
		if environment:
			environment.fog_enabled = true
			environment.fog_light_color = Color(0.0, 0.1, 0.4) # Deep Blue
			environment.fog_density = 0.05 # Thick water
	else:
		handle_walking(delta)
		if environment:
			environment.fog_enabled = original_fog_enabled
			environment.fog_light_color = original_fog_color
			environment.fog_density = original_fog_density

	move_and_slide()

func handle_swimming(delta):
	# Buoyancy: Gravity is greatly reduced or reversed
	velocity.y = move_toward(velocity.y, 0.0, 0.1) # Natural drag stopping vertical movement
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Vertical Swim
	if Input.is_action_pressed("ui_accept"): # Space
		velocity.y = SPEED * 0.5
	elif Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT):
		velocity.y = -SPEED * 0.5
	
	# Horizontal Swim (Slower)
	if direction:
		velocity.x = direction.x * (SPEED * 0.6)
		velocity.z = direction.z * (SPEED * 0.6)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 0.1)
		velocity.z = move_toward(velocity.z, 0, SPEED * 0.1)

func handle_walking(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
