extends Node2D



func _on_bed_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		print("Bed area entered")

func _on_door_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		print("Door area entered")

func _on_transition_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		print("Transition area entered")
		
# Animation flow (locking):
#	GlobalVariables.is_actors_locked = true
#	$AnimationPlayer.play("animation-name")
#	await $AnimationPlayer.animation_finished
#	GlobalVariables.is_actors_locked = false
