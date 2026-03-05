extends CharacterBody2D

const SPEED = 10000.0
var right := true
var dir
var turning := false

@onready var ray: RayCast2D = $RayCast2D
@onready var line: Line2D = $Line2D
@onready var player: CharacterBody2D = %CharacterBody2D
@onready var animPlayer: AnimationPlayer = $"soldier_visual/SubViewport/Soldier animation 2/AnimationPlayer"

func _ready() -> void:
	animPlayer.play("walkLoop")

func _physics_process(_delta: float) -> void:
	if GlobalVariables.is_near_soldier:
		ray.target_position = ray.to_local(player.global_position)
		line.points[1] = to_local(player.global_position)
		line.visible = true
		
		if ray.is_colliding():
			var collider = ray.get_collider()
			
			if collider == player:
				if not GlobalVariables.is_soldier_kill:
					GlobalVariables.is_soldier_kill = true
					print("I see the player!")
					GlobalVariables.is_actors_locked = true
					var flipped = false
					if right and ray.target_position.x < 0:
						$soldier_visual.scale.x *= -1
						flipped = true
					elif not right and ray.target_position.x > 0:
						$soldier_visual.scale.x *= -1
						flipped = true
					animPlayer.play("AimRifle")
					await animPlayer.animation_finished
					var timer: SceneTreeTimer = get_tree().create_timer(0.5)
					await timer.timeout
					GlobalVariables.is_near_soldier = false
					player.global_position = %Triggers.checkpoints[3]
					GlobalVariables.is_soldier_kill = false
					line.points[1] = line.points[0]
					timer = get_tree().create_timer(2)
					await timer.timeout
					GlobalVariables.is_actors_locked = false
					if flipped:
						$soldier_visual.scale.x *= -1
					animPlayer.play("walkLoop")
			else:
				line.visible = false
				print("No player in sight.")

# Could remove movement? 

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not GlobalVariables.is_actors_locked:
		if right and global_position.x > 6515 and not turning:
			right = false
			animPlayer.play("Turn1")
			turning = true
			await animPlayer.animation_finished
			$soldier_visual.scale.x *= -1
			turning = false
			animPlayer.play("walkLoop")
		elif not right and global_position.x < 5570 and not turning:
			right = true
			animPlayer.play("Turn1")
			turning = true
			await animPlayer.animation_finished
			$soldier_visual.scale.x *= -1
			turning = false
			animPlayer.play("walkLoop")
		
		if right:
			dir = 1.0
		else:
			dir = -1.0
			
		if not turning:
			velocity.x = SPEED * delta * dir
			move_and_slide()
