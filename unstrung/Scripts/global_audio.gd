extends Node

var music_player: AudioStreamPlayer
var current_music_path: String = ""

signal music_changed(new_path: String)

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)
	
	# Load saved volume
	_load_volume()
	
func play_music(path: String) -> void:
	if current_music_path == path and music_player.playing:
		return
	
	current_music_path = path
	music_player.stream = load(path)
	music_player.play()
	music_changed.emit(path)
	
func stop_music() -> void:
	music_player.stop()

func _on_music_finished() -> void:
	if current_music_path:
		play_music(current_music_path)
		
func _load_volume() -> void:
	var saved_volume = UserSettings.get_value("audio", "music_volume", 0.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), saved_volume)

	
	
