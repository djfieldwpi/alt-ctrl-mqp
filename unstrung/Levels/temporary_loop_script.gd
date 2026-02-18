extends AudioStreamPlayer

func _ready() -> void:
	finished.connect(_on_finished)

func _on_finished() -> void:
	play()  
