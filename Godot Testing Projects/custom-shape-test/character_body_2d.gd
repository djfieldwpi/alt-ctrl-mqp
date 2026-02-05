extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -425.0


func _physics_process(delta: float) -> void:
	# Skips physics processing if actors are locked
	if not GlobalVariables.is_actors_locked:
			
		# Add the gravity.
		if not is_on_floor():
			velocity += get_gravity() * delta

		# Handle jump.
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		# Get the input direction and handle the movement/deceleration.
		# As good practice, you should replace UI actions with custom gameplay actions.
		var direction := Input.get_axis("ui_left", "ui_right")
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
		
		if Input.is_action_just_pressed("Crawl"):
			$SubViewport/AnimationPlayer.play("crawl")
			$CollisionShape2D.scale.x = 2
			$CollisionShape2D.scale.y = 1

		move_and_slide()
