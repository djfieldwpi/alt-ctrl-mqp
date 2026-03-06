extends Node2D

var last_linear_velocity: Vector2
var last_angular_velocity: float

# Call this to freeze
func freeze_body():
	last_linear_velocity = find_child("RigidBody2D").linear_velocity
	last_angular_velocity = find_child("RigidBody2D").angular_velocity
	find_child("RigidBody2D").freeze = true

# Call this to unfreeze
func unfreeze_body():
	find_child("RigidBody2D").freeze = false
	find_child("RigidBody2D").linear_velocity = last_linear_velocity
	find_child("RigidBody2D").angular_velocity = last_angular_velocity


func _on_rigid_body_2d_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		GlobalVariables.is_actors_locked = true
		await get_tree().process_frame
		var value = get_parent().find_child("Triggers").check_beach[3]
		get_parent().find_child("CharacterBody2D").global_position = value
		var timer: SceneTreeTimer = get_tree().create_timer(2)
		await timer.timeout
		GlobalVariables.is_actors_locked = false
		self.queue_free()
