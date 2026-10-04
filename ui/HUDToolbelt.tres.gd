extends Control

signal slot_changed(index)

var current_slot = 0
@onready var container = $HBoxContainer

func _ready():
	setup_extra_slots()
	update_visuals()
	call_deferred("emit_initial_signal")

func emit_initial_signal():
	slot_changed.emit(current_slot)

func setup_extra_slots():
	# Ensure Slot 2 has the ramp
	# Check if Slot 1 exists (it has the setup we want to copy)
	if container.get_child_count() > 2:
		var slot1 = container.get_child(1)
		var slot2 = container.get_child(2)
		
		# Check if Slot 2 already has a viewport
		if not slot2.has_node("SubViewportContainer"):
			var source_svc = slot1.get_node_or_null("SubViewportContainer")
			if source_svc:
				var new_svc = source_svc.duplicate()
				slot2.add_child(new_svc)
				
				# Find the Node3D holding the object
				# Structure: SubViewportContainer -> SubViewport -> Node3D
				var viewport = new_svc.get_child(0)
				var node3d = viewport.get_node("Node3D")
				
				# Remove the copied Block/Pistol
				for child in node3d.get_children():
					if child is StaticBody3D or child.name.begins_with("Block") or child.name.begins_with("Sketchfab"):
						child.queue_free()
				
				# Add the Ramp
				var ramp_scene = load("res://Block_ramp.tscn")
				if ramp_scene:
					var ramp = ramp_scene.instantiate()
					node3d.add_child(ramp)
				
				# The preview is a static icon: render it once instead of every frame.
				viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _input(event):
	var changed = false
	
	# Scroll wheel logic for slot switching (Only if CTRL is NOT held)
	if event is InputEventMouseButton and event.pressed:
		if not Input.is_key_pressed(KEY_CTRL):
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				current_slot = (current_slot - 1 + 9) % 9
				changed = true
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				current_slot = (current_slot + 1) % 9
				changed = true
	
	# Supports number keys 1-9
	if event is InputEventKey and event.pressed:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			current_slot = event.keycode - KEY_1
			changed = true
	
	if changed:
		update_visuals()
		slot_changed.emit(current_slot)

func update_visuals():
	if not container: return
	
	for i in range(container.get_child_count()):
		var slot = container.get_child(i)
		var border = slot.get_node_or_null("Border")
		
		if i == current_slot:
			slot.color = Color(0.3, 0.3, 0.3, 0.9) # Light up active slot
			if border: border.visible = true
		else:
			slot.color = Color(0.1, 0.1, 0.1, 0.6) # Dim inactive slots
			if border: border.visible = false
