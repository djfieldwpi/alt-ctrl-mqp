extends Node2D

# 3689.0, 1851.0

var animPlayer: AnimationPlayer
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animPlayer = $SubViewport/awfulHandBonesAction/AnimationPlayer


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	#if Input.is_action_just_pressed("Test Animation"):
	#	animPlayer.play("Grab")
