import cv2
import numpy as np
import threading
import socket
import json
import struct
import os

# --- Global Storage and Flags ---
vertices = np.array([])
request_pending = False
reference_frame = None
frame_lock = threading.Lock()

# Warped image dimensions
WARP_W = 1920
WARP_H = 1080

# --- Socket Server 1: Handles Vertex Requests from Godot ---
def socket_server():
    global request_pending
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind(('localhost', 65432))
        s.listen()
        print("Vertex Server: Waiting for Godot...")
        connection, address = s.accept()
        with connection:
            while True:
                data = connection.recv(1024).decode('utf-8')
                if not data:
                    break
                if data == "GET_ARRAY":
                    request_pending = True
                    # Wait for main loop to update vertices
                    while request_pending: 
                        pass
                    
                    packet = json.dumps(vertices.tolist())
                    connection.sendall(packet.encode('utf-8'))

# --- Socket Server 2: Handles Reference Image Stream from Godot ---
def godot_image_receiver():
    global reference_frame
    HOST = '127.0.0.1'
    PORT = 5000
    
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((HOST, PORT))
        server.listen(1)
        print(f"Image Receiver: Waiting for Godot on {PORT}...")
        conn, addr = server.accept()
        
        with conn:
            while True:
                header = conn.recv(4)
                if not header: break
                image_size = struct.unpack('<i', header)[0]
                
                data = b''
                while len(data) < image_size:
                    packet = conn.recv(min(image_size - len(data), 8192))
                    if not packet: break
                    data += packet
                
                nparr = np.frombuffer(data, np.uint8)
                img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                if img is not None:
                    with frame_lock:
                        reference_frame = img.copy()

# --- Initial Camera Setup ---
cap = cv2.VideoCapture(1)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)

# Charuco board parameters
squaresX, squaresY = 16, 9
squareLength, markerLength = 0.02, 0.015  

dictionary = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_6X6_250)
board = cv2.aruco.CharucoBoard((squaresX, squaresY), squareLength, markerLength, dictionary)
charuco_detector = cv2.aruco.CharucoDetector(board, cv2.aruco.CharucoParameters(), cv2.aruco.DetectorParameters())

all_object_points, all_image_points = [], []
imageSize = None

# --- Calibration Loop ---
while True:
    ok, frame = cap.read()
    if not ok: break

    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    charucoCorners, charucoIds, markerCorners, markerIds = charuco_detector.detectBoard(gray)

    if imageSize is None:
        imageSize = (frame.shape[1], frame.shape[0])
        board_image = board.generateImage(imageSize)
        if board_image is not None:
            cv2.namedWindow("Charuco Board", cv2.WINDOW_NORMAL)
            cv2.setWindowProperty("Charuco Board", cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)
            cv2.imshow("Charuco Board", board_image)

    debug = gray.copy()
    if markerIds is not None: cv2.aruco.drawDetectedMarkers(debug, markerCorners, markerIds)
    if charucoIds is not None: cv2.aruco.drawDetectedCornersCharuco(debug, charucoCorners, charucoIds)

    cv2.imshow("Calibration (SPACE to capture, ESC to finish)", debug)
    key = cv2.waitKey(1) & 0xFF
    if key == ord(' ') and charucoIds is not None and len(charucoIds) >= 12:
        objPts, imgPts = board.matchImagePoints(charucoCorners, charucoIds)
        all_object_points.append(objPts.astype(np.float32))
        all_image_points.append(imgPts.astype(np.float32))
    if key == 27: break

cv2.destroyAllWindows()

# Calculate Camera Matrix
ret, camMatrix, distCoeffs, rvecs, tvecs = cv2.calibrateCamera(
    all_object_points, all_image_points, imageSize, None, None
)

# --- Start Threads ---
threading.Thread(target=socket_server, daemon=True).start()
threading.Thread(target=godot_image_receiver, daemon=True).start()

# --- Main Shadow Detection Loop ---
bestInliers = 0
bestH = None
warpFound = False
kernel_open = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
kernel_close = cv2.getStructuringElement(cv2.MORPH_RECT, (11, 7))

while True:
    ok, frame = cap.read()
    if not ok: break
    
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

    # 1. Update Homography
    charucoCorners, charucoIds, markerCorners, markerIds = charuco_detector.detectBoard(gray)
    if charucoIds is not None and len(charucoIds) >= 12:
        objPts, imgPts = board.matchImagePoints(charucoCorners, charucoIds)
        obj2d = objPts[:, 0, :2]
        img2d = imgPts[:, 0, :]

        newcameramtx, _ = cv2.getOptimalNewCameraMatrix(camMatrix, distCoeffs, imageSize, 1, imageSize)
        img2d_undist = cv2.undistortPoints(img2d.reshape(-1, 1, 2), camMatrix, distCoeffs, P=newcameramtx).reshape(-1, 2)

        px, py = WARP_W / (squaresX * squareLength), WARP_H / (squaresY * squareLength)
        src = img2d_undist.astype(np.float32)
        dst = np.column_stack((obj2d[:, 0] * px, obj2d[:, 1] * py)).astype(np.float32)

        H, inliers = cv2.findHomography(src, dst, cv2.RANSAC, 3.0)
        if H is not None and inliers.sum() > bestInliers:
            bestInliers, bestH, warpFound = inliers.sum(), H, True

    if not warpFound:
        cv2.imshow("Raw Camera", frame)
        if cv2.waitKey(1) & 0xFF == 27: break
        continue

    # 2. Warp and Pre-process
    undist = cv2.undistort(frame, camMatrix, distCoeffs, None, newcameramtx)
    warped = cv2.warpPerspective(undist, bestH, (WARP_W, WARP_H))
    gray_w = cv2.cvtColor(warped, cv2.COLOR_BGR2GRAY)
    gray_w = cv2.GaussianBlur(gray_w, (5, 5), 0)
    gray_w = cv2.threshold(gray_w, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)[1]

    # 3. Shadow Detection (Using thread-safe reference frame)
    with frame_lock:
        if reference_frame is not None:
            bg_gray = cv2.cvtColor(reference_frame, cv2.COLOR_BGR2GRAY)
            diff = cv2.absdiff(gray_w, cv2.convertScaleAbs(bg_gray))
            _, mask = cv2.threshold(diff, 200, 255, cv2.THRESH_BINARY)
            
            mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel_open)
            mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel_close)
            cv2.imshow("Shadow Mask", mask)

            contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            
            best_cnt = None
            max_score = 0
            for cnt in contours:
                area = cv2.contourArea(cnt)
                if area < 1500: continue
                x, y, w, h = cv2.boundingRect(cnt)
                score = area * (area / float(w * h + 1e-5))
                if score > max_score:
                    max_score, best_cnt = score, cnt

            if best_cnt is not None:
                vertices = cv2.approxPolyDP(best_cnt, 4, True)
                if request_pending:
                    request_pending = False

    cv2.imshow("Main Output", warped)
    if cv2.waitKey(1) & 0xFF == 27: break

cap.release()
cv2.destroyAllWindows()