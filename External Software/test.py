import socket
import struct
import cv2
import numpy as np

HOST = '127.0.0.1'
PORT = 5000

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind((HOST, PORT))
server.listen(1)
print(f"Waiting for Godot on {HOST}:{PORT}...")

conn, addr = server.accept()
print(f"Streaming from: {addr}")

try:
    while True:
        # Read the 4-byte size header
        header = conn.recv(4)
        if not header:
            break
            
        image_size = struct.unpack('<i', header)[0]
        
        # Read the image data based on the size received
        data = b''
        while len(data) < image_size:
            packet = conn.recv(min(image_size - len(data), 8192))
            if not packet:
                break
            data += packet
            
        # Decode and Display
        nparr = np.frombuffer(data, np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if frame is not None:
            print("test")
            cv2.imshow("Godot Live Stream", frame)
        
        # Press 'q' in the CV2 window to stop
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

finally:
    conn.close()
    server.close()
    cv2.destroyAllWindows()