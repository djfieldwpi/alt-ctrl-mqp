extends Node2D



func _on_bed_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		print("Bed area entered")

func _on_door_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		print("Door area entered")

func _on_transition_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not GlobalVariables.is_camera_follow:
		print("Transition area entered")
		
		GlobalVariables.is_system_lock = true
		GlobalVariables.is_actors_locked = true
		var timer: SceneTreeTimer = get_tree().create_timer(0.5)
		await timer.timeout
		GlobalVariables.is_system_lock = false
		GlobalVariables.is_actors_locked = false
		GlobalVariables.is_camera_follow = true
		
# Animation flow (locking):
#	GlobalVariables.is_actors_locked = true
#	$AnimationPlayer.play("animation-name")
#	await $AnimationPlayer.animation_finished
#	GlobalVariables.is_actors_locked = false
