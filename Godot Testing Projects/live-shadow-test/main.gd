extends Node2D

var tcp_client := StreamPeerTCP.new()
var host := "127.0.0.1"
var port := 5000
var connected := false

func _ready() -> void:
	tcp_client.connect_to_host(host, port)

func _process(_delta: float) -> void:
	tcp_client.poll()
	var status = tcp_client.get_status()
	
	if status == StreamPeerTCP.STATUS_CONNECTED:
		if not connected:
			print("Connected to Python!")
			connected = true
		send_frame()
	elif status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
		print("Disconnected. Retrying...")
		tcp_client.connect_to_host(host, port)
		connected = false

func send_frame() -> void:
	# 1. Capture Viewport
	var img = $SubViewport.get_texture().get_image()
	
	# 2. Compress to JPG (Faster than PNG for streaming)
	# Quality 0.8 is a good balance
	var buffer = img.save_jpg_to_buffer(0.8) 
	
	# 3. Send Size (Little Endian)
	tcp_client.put_32(buffer.size())
	
	# 4. Send Data
	tcp_client.put_data(buffer)
	
