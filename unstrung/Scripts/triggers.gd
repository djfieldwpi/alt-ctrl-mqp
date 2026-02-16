extends Node2D

var checkpoints: Array[Vector2] = [Vector2(960, 255),
								  Vector2(960+1920, 255),
								  Vector2(960+1920+1920, 255),
								  Vector2(960+1920+1920+1920, 312)]

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
		%Camera2D.slide_to_position(Vector2(%CharacterBody2D.global_position.x, %Camera2D.global_position.y), 2)
		var timer: SceneTreeTimer = get_tree().create_timer(2)
		await timer.timeout
		GlobalVariables.is_system_lock = false
		GlobalVariables.is_actors_locked = false
		GlobalVariables.is_camera_follow = true
		
# Animation flow (locking):
#	GlobalVariables.is_actors_locked = true
#	$AnimationPlayer.play("animation-name")
#	await $AnimationPlayer.animation_finished
#	GlobalVariables.is_actors_locked = false


func _on_death_pit_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		GlobalVariables.is_actors_locked = true
		%CharacterBody2D.global_position = checkpoints[0]
		var timer: SceneTreeTimer = get_tree().create_timer(2)
		await timer.timeout
		GlobalVariables.is_actors_locked = false


func _on_death_boiler_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		GlobalVariables.is_actors_locked = true
		%CharacterBody2D.global_position = checkpoints[1]
		var timer: SceneTreeTimer = get_tree().create_timer(2)
		await timer.timeout
		GlobalVariables.is_actors_locked = false


func _on_death_river_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		GlobalVariables.is_actors_locked = true
		%CharacterBody2D.global_position = checkpoints[3]
		var timer: SceneTreeTimer = get_tree().create_timer(2)
		await timer.timeout
		GlobalVariables.is_actors_locked = false


func _on_death_soldier_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		GlobalVariables.is_near_soldier = true


func _on_death_soldier_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		GlobalVariables.is_near_soldier = false
