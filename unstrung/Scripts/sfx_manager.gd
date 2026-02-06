extends Node

@export var root_path: NodePath

@onready var sounds = {
	&"Button_Click": AudioStreamPlayer.new(),
	&"Button_Hover": AudioStreamPlayer.new(),
}

func _ready() -> void:
	for i in sounds.keys():
		sounds[i].stream = load("res://Audio/SFX/" + str(i) + ".mp3")
		sounds[i].bus = &"UI"
		add_child(sounds[i])
		
	install_sounds(get_node(root_path))
	
func install_sounds(node: Node):
	for i in node.get_children():
		if i is Button:
			i.mouse_entered.connect(ui_sfx_play.bind(&"Button_Hover"))
			i.pressed.connect(ui_sfx_play.bind(&"Button_Click"))
			
		install_sounds(i)
		
func ui_sfx_play(sound: StringName) -> void:
	sounds[sound].play()
