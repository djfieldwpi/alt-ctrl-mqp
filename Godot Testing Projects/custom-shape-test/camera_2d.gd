extends Camera2D

@onready var character = %CharacterBody2D
var parent_start_x = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.make_current()
	self.global_position.x = 960
	self.global_position.y = 540
	parent_start_x = character.global_position.x
	print(parent_start_x)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	self.global_position.y = 540
	if (character.global_position.x > self.global_position.x):
		self.global_position.x = character.global_position.x
	elif (self.global_position.x - character.global_position.x > 960 - parent_start_x):
		self.global_position.x = character.global_position.x + (960 - parent_start_x)
