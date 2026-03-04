extends CharacterBody2D

const SPEED = 10000.0
var right = true
var dir

@onready var ray: RayCast2D = $RayCast2D
@onready var line: Line2D = $Line2D
@onready var player: CharacterBody2D = %CharacterBody2D

func _physics_process(_delta: float) -> void:
	if GlobalVariables.is_near_soldier:
		ray.target_position = ray.to_local(player.global_position)
		line.points[1] = to_local(player.global_position)
		line.visible = true
		
		if ray.is_colliding():
			var collider = ray.get_collider()
			
			if collider == player:
				print("I see the player!")
				GlobalVariables.is_actors_locked = true
				var timer: SceneTreeTimer = get_tree().create_timer(2)
				await timer.timeout
				GlobalVariables.is_near_soldier = false
				player.global_position = %Triggers.checkpoints[3]
				line.points[1] = line.points[0]
				timer = get_tree().create_timer(2)
				await timer.timeout
				GlobalVariables.is_actors_locked = false
			else:
				line.visible = false
				print("No player in sight.")

# Could remove movement? 

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not GlobalVariables.is_actors_locked:
		if right and global_position.x > 6515:
			right = false
		elif not right and global_position.x < 5570:
			right = true
		
		if right:
			dir = 1.0
		else:
			dir = -1.0
		
		velocity.x = SPEED * delta * dir
			
		move_and_slide()
