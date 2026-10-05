extends Control

@onready var container = $ClippedArea/HBoxContainer
# Width in pixels between each 45-degree increment (N to NE)
const PX_PER_SECTION = 150.0 

# Last applied x so a stationary camera doesn't re-dirty (and re-draw) the
# 12-label strip every frame; only move it when the heading actually changes.
var _last_x: float = INF

func _ready():
	# Populate the compass strip
	# Sequence: N NE E SE S SW W NW (Repeat N NE E SE to allow smooth looping)
	var directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", "N", "NE", "E", "SE"]
	
	for dir in directions:
		var lbl = Label.new()
		lbl.text = dir
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Set fixed width for predictable sliding
		lbl.custom_minimum_size.x = PX_PER_SECTION
		lbl.custom_minimum_size.y = 40
		
		container.add_child(lbl)

func _process(_delta):
	var cam = get_viewport().get_camera_3d()
	if not cam: return
	
	# FIX: In Godot, Y-rotation is positive to the LEFT (Counter-Clockwise).
	# We want positive angles to be to the RIGHT (Clockwise/East).
	# So we negate the rotation angle.
	var angle = fmod(-cam.global_rotation_degrees.y, 360.0)
	if angle < 0: angle += 360.0
	
	# Calculate offset
	# 360 degrees = 8 sections * PX_PER_SECTION
	# angle / 45.0 gives us how many 'sections' we have rotated
	
	var offset = (angle / 45.0) * PX_PER_SECTION
	
	# Apply offset to the container.
	# We center the 'N' (first element) at angle 0.
	# The Container is centered in the parent Control.
	# We shift left as angle increases.
	
	# Offset correction:
	# The HBoxContainer starts at x=0 inside ClippedArea.
	# We want index 0 ("N") to be centered in ClippedArea (width=300).
	# So "N" center is at x=75 (half of 150).
	# We want that x=75 to coincide with ClippedArea center (x=150).
	# So initial start position of container should be +75.
	var start_x = 75.0 
	var new_x = start_x - offset
	if absf(new_x - _last_x) < 0.01:
		return
	_last_x = new_x
	container.position.x = new_x
