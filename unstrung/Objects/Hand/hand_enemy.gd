extends Node2D

# 3689.0, 1851.0

@onready var hand_jumpscare: AudioStreamPlayer = $"../../../HandJumpscare"

var start_position : Vector2
var move_distance := 1350
var move_time := 3.0

var animPlayer: AnimationPlayer
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animPlayer = $SubViewport/awfulHandBonesAction/AnimationPlayer


func run_sequence() -> void:
	start_position = global_position
	self.visible = true
	await move_down()
	await play_grab_animation()
	await move_up()
	self.visible = false
	
func move_down() -> void:
	animPlayer.play("ArmatureAction")
	hand_jumpscare.play()

	var tween = create_tween()
	tween.tween_property(
		self,
		"global_position:y",
		start_position.y + move_distance,
		move_time
	)

	await tween.finished
	
func play_grab_animation() -> void:
	animPlayer.play("Grab")
	var timer : SceneTreeTimer = get_tree().create_timer(1.5)
	await timer.timeout
	%CharacterBody2D.visible = false
	await animPlayer.animation_finished

func move_up() -> void:
	var tween = create_tween()
	tween.tween_property(
		self,
		"global_position:y",
		start_position.y,
		move_time
	)

	await tween.finished
