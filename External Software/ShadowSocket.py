import cv2
import numpy as np
import threading
import socket
import json
import os

# Storage for detected shadow vertices and request flag
vertices = []
request_pending = False

# Threaded socket server to handle requests from Godot
def socket_server():
    # Allows cross-thread access to request_pending
    global request_pending
    # Opens the TCP socket server
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(('localhost', 65432))
        s.listen()
        connection, address = s.accept()
        with connection:
            while True:
                # Waits for a request from Godot
                data = connection.recv(1024).decode('utf-8')
                print(data)
                if not data:
                    break
                # Check for request from Godot
                if data == "GET_ARRAY":
                    request_pending = True
                    while request_pending: 
                        pass
                    
                    # Sends the vertices as a JSON string to Godot
                    packet = json.dumps(vertices.tolist())
                    print(vertices)
                    connection.sendall(packet.encode('utf-8'))

# Opens the camera and sets the resolution to match the Godot resolution
cap = cv2.VideoCapture(1)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)

# Charuco board parameters
squaresX = 16
squaresY = 9
squareLength = 0.02
markerLength = 0.015  

# Storage for calibration points
all_object_points = []
all_image_points = []

# Warped image dimensions
WARP_W = 1920
WARP_H = 1080

# Variables for homography and warp
bestInliers = 0
bestH = None
warpFound = False

# Background model and parameters for shadow detection
bg = None
BG_ALPHA = 0.01

MIN_AREA = 1500
MIN_EXTENT = 0.30

kernel_open = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
kernel_close = cv2.getStructuringElement(cv2.MORPH_RECT, (11, 7))

# Create the Charuco board and detector
dictionary = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_6X6_250)
board = cv2.aruco.CharucoBoard((squaresX, squaresY), squareLength, markerLength, dictionary)
detector_parameters = cv2.aruco.DetectorParameters()
charuco_parameters = cv2.aruco.CharucoParameters()
charuco_parameters.tryRefineMarkers = True
charuco_detector = cv2.aruco.CharucoDetector(board, charuco_parameters, detector_parameters)

imageSize = None

# Loop to detect the Charuco board and capture calibration frames
while True:
    ok, frame = cap.read()
    if not ok:
        break

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
    if markerIds is not None:
        cv2.aruco.drawDetectedMarkers(debug, markerCorners, markerIds)
    if charucoIds is not None:
        cv2.aruco.drawDetectedCornersCharuco(debug, charucoCorners, charucoIds)

    cv2.imshow("Calibration (SPACE to capture, ESC to finish)", debug)

    # Spacebar press to capture calibration frames
    key = cv2.waitKey(1) & 0xFF
    if key == ord(' ') and charucoIds is not None and len(charucoIds) >= 12:
        objPts, imgPts = board.matchImagePoints(charucoCorners, charucoIds)
        all_object_points.append(objPts.astype(np.float32))
        all_image_points.append(imgPts.astype(np.float32))

    # ESC to exit camera calibration loop
    if key == 27:
        break

# Gets rid of the calibration windows
cv2.destroyAllWindows()

# Calculates the camera matrix and distortion coefficients from the captured calibration frames
ret, camMatrix, distCoeffs, rvecs, tvecs = cv2.calibrateCamera(
    all_object_points, all_image_points, imageSize, None, None
)

# Starts the socket server in a separate thread to handle requests from Godot
threading.Thread(target=socket_server, daemon=True).start()

# Gets the relative path to the reference image for shadow detection
script_dir = os.path.dirname(os.path.abspath(__file__))
print(script_dir)
image_path = os.path.join(script_dir, "Test Images", "GodotFrame.png")

# Main loop for shadow detection and shape approximation
while True:
    # Gets current frame from the camera
    ok, frame = cap.read()
    if not ok:
        break
    
    # Converts the frame to grayscale
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

    # Finds the homography to map the projector's display area to a window that matches the Godot resolution
    charucoCorners, charucoIds, markerCorners, markerIds = charuco_detector.detectBoard(gray)
    if charucoIds is not None and len(charucoIds) >= 12:
        objPts, imgPts = board.matchImagePoints(charucoCorners, charucoIds)

        obj2d = objPts[:, 0, :2]
        img2d = imgPts[:, 0, :]

        newcameramtx, _ = cv2.getOptimalNewCameraMatrix(
            camMatrix, distCoeffs, imageSize, 1, imageSize
        )

        img2d_undist = cv2.undistortPoints(
            img2d.reshape(-1, 1, 2), camMatrix, distCoeffs, P=newcameramtx
        ).reshape(-1, 2)

        boardW = squaresX * squareLength
        boardH = squaresY * squareLength

        px = WARP_W / boardW
        py = WARP_H / boardH

        src = img2d_undist.astype(np.float32)
        dst = np.column_stack((obj2d[:, 0] * px, obj2d[:, 1] * py)).astype(np.float32)

        H, inliers = cv2.findHomography(src, dst, cv2.RANSAC, 3.0)
        if H is not None and inliers.sum() > bestInliers:
            bestInliers = inliers.sum()
            bestH = H
            warpFound = True

    # Failure condition if homography cannot be found, prevents further processing and shows raw camera feed
    if not warpFound:
        cv2.imshow("Raw Camera", frame)
        if cv2.waitKey(1) & 0xFF == 27:
            break
        continue

    # Uses the homography to warp the frame 
    undist = cv2.undistort(frame, camMatrix, distCoeffs, None, newcameramtx)
    warped = cv2.warpPerspective(undist, bestH, (WARP_W, WARP_H))

    # Blurs the frame to to reduce noice and prevent jagged edges
    gray_w = cv2.cvtColor(warped, cv2.COLOR_BGR2GRAY)
    gray_w = cv2.GaussianBlur(gray_w, (5, 5), 0)
    gray_w = cv2.medianBlur(gray_w, 5)

    # Makes the grayscale frame binary
    gray_w = cv2.threshold(gray_w, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)[1]

    # Loads the reference image from the relative path and converts it to grayscale
    reference = cv2.imread(image_path)
    if reference is None or reference.size == 0:
        print(f"Error: Reference image not found at {image_path}")
        continue
    bg = cv2.cvtColor(reference, cv2.COLOR_BGR2GRAY)
    bg = bg.astype(np.float32)
    bg_u8 = cv2.convertScaleAbs(bg)

    # Finds the difference between the reference image and the current frame
    diff = cv2.absdiff(gray_w, bg_u8)

    # Threshold minimun calculation, not currently used
    mean = np.mean(diff)
    std = np.std(diff)
    thresh_val = int(np.clip(mean + 0.8 * std, 12, 60))

    # Snaps image values back to either 0 or 255 (white or black)
    _, mask = cv2.threshold(diff, 200, 255, cv2.THRESH_BINARY)

    # Applies morphological operations to clean up the binary mask and reduce noise
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel_open)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel_close)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel_open)

    # Displays the processed frame before shadow detection for debugging purposes
    cv2.imshow("Shadow Mask Pre-Contour", mask)

    # Finds shadows through contour detection
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # Storage for best contour
    best_cnt = None
    best_score = 0

    # Finds best contour based on area and extent
    for cnt in contours:
        area = cv2.contourArea(cnt)
        if area < MIN_AREA:
            continue

        x, y, w, h = cv2.boundingRect(cnt)
        extent = area / float(w * h + 1e-5)
        score = area * extent

        if score > best_score:
            best_score = score
            best_cnt = cnt

    # Failure check for contours, ensures a contour was found
    if best_cnt is not None:
        # uses Ramer-Douglas-Peucker algorithm to approximate the contour to a polygon and saves the vertices
        vertices = cv2.approxPolyDP(best_cnt, 4, True)
        # Resets request_pending to allow the socket server to send the new vertices to Godot when requested
        if request_pending:
            request_pending = False

    # Debugging visualization of the best contour, not drawn currently
    if best_cnt is not None:
        x, y, w, h = cv2.boundingRect(best_cnt)
        cx = int(x + w / 2)
        cy = int(y + h / 2)
        cv2.circle(warped, (cx, cy), 10, (0, 255, 0), -1)

    # ESC to exit the loop
    if cv2.waitKey(1) & 0xFF == 27:
        break

# Cleanup after exiting the loop
cap.release()
cv2.destroyAllWindows()
