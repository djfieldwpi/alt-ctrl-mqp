extends Camera2D

var character_start_x: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.make_current()
	character_start_x = %CharacterBody2D.global_position.x
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	if GlobalVariables.is_camera_follow:
		# Mid-screen tracking (right)
		if %CharacterBody2D.global_position.x > self.global_position.x:
			self.global_position.x = %CharacterBody2D.global_position.x
		# Starting position tracking (left)
		elif self.global_position.x - %CharacterBody2D.global_position.x > -character_start_x:
			self.global_position.x = %CharacterBody2D.global_position.x - character_start_x
