extends Node2D

@onready var area: Area2D = %Chain

var checkpoints: Array[Vector2] = [Vector2(-891.0, 96.0),
								  Vector2(960, 226.0),
								  Vector2(960+1920, 226.0),
								  Vector2(960+1920+1920, 226.0),
								  Vector2(960+1920+1920+1920, 284.0)]
var check_beach:	 Array[Vector2] = [Vector2(-654, 2759.0),
								  Vector2(3100, 2732.0),
								  Vector2(4950, 2732.0),
								  Vector2(6760, 2732.0)]
								
func _physics_process(_delta: float) -> void:
	if not GlobalVariables.is_chain_broken and GlobalVariables.is_chain_breakable:
		var bodies = %Chain.get_overlapping_bodies()
		if bodies:
			for b in bodies:
				print(b)
				if b is not CharacterBody2D:
					GlobalVariables.is_chain_broken = true
					%Chain.get_parent().queue_free()
					queue_redraw()
	var bodies = %Pipe.get_overlapping_bodies()
	if bodies:
		for b in bodies:
			if b is not CharacterBody2D:
				%GPUParticles2D.emitting = false
				var timer = get_tree().create_timer(0.5)
				await timer.timeout
				GlobalVariables.is_pipe_blocked = true
	else:
		%GPUParticles2D.emitting = true
		var timer = get_tree().create_timer(0.5)
		await timer.timeout
		GlobalVariables.is_pipe_blocked = false
				
		
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


func _on_activate_chain_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		GlobalVariables.is_chain_breakable = true

func _on_finish_body_entered(body: Node2D) -> void:
	if GlobalVariables.is_chain_broken and body is CharacterBody2D:
		GlobalVariables.is_actors_locked = true
		GlobalVariables.is_system_lock = true
		%Label.visible = true
		var timer = get_tree().create_timer(2)
		await timer.timeout
		%CharacterBody2D.global_position = check_beach[0]
		%Camera2D.global_position.y += 2500
		timer = get_tree().create_timer(2)
		await timer.timeout
		GlobalVariables.is_actors_locked = false
		GlobalVariables.is_system_lock = false
		GlobalVariables.is_level_two = true


func _on_death_rocks_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		GlobalVariables.is_actors_locked = true
		%CharacterBody2D.global_position = check_beach[0]
		var timer: SceneTreeTimer = get_tree().create_timer(2)
		await timer.timeout
		GlobalVariables.is_actors_locked = false


func _on_death_hand_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		GlobalVariables.is_actors_locked = true
		%CharacterBody2D.global_position = check_beach[1]
		var timer: SceneTreeTimer = get_tree().create_timer(2)
		await timer.timeout
		GlobalVariables.is_actors_locked = false


func _on_death_sewage_body_entered(body: Node2D) -> void:
	if not GlobalVariables.is_pipe_blocked and body is CharacterBody2D:
		GlobalVariables.is_actors_locked = true
		%CharacterBody2D.global_position = check_beach[2]
		var timer: SceneTreeTimer = get_tree().create_timer(2)
		await timer.timeout
		GlobalVariables.is_actors_locked = false
		
