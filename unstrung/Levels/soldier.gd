extends CharacterBody2D

const SPEED = 10000.0
var right = true
var dir

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not GlobalVariables.is_actors_locked:
		if right and global_position.x > 6830:
			right = false
		elif not right and global_position.x < 5400:
			right = true
		
		if right:
			dir = 1.0
		else:
			dir = -1.0
		
		velocity.x = SPEED * delta * dir
			
		move_and_slide()
