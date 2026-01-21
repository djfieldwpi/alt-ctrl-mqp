import cv2
import numpy as np
import imutils
import os

# Opens camera feed and sets resolution
# 0: laptop webcam
# 1: external camera
cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)

# Charuco Board's size parameters
squaresX = 13
squaresY = 9
squareLength = 0.02
markerLength = 0.0147  

all_object_points = []
all_image_points = []
SHOW_DEBUG = True

# Warped output's image size
WARP_W = 1920
WARP_H = 1080

#
def processShadowContours(difference):
    #
    cnts = cv2.findContours(difference.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    cnts = imutils.grab_contours(cnts)
    c = max(cnts, key=cv2.contourArea)

    # draw the shape of the contour on the output image, compute the
    # bounding box, and display the number of points in the contour
    output = difference.copy()
    cv2.drawContours(output, [c], -1, (0, 255, 0), 3)
    (x, y, w, h) = cv2.boundingRect(c)

    # approximate the contour
    peri = cv2.arcLength(c, True)
    approx = cv2.approxPolyDP(c, 0.001 * peri, True)

    #
    output = cv2.cvtColor(output, cv2.COLOR_GRAY2BGR)

    # draw the approximated contour on the image
    cv2.drawContours(output, [approx], -1, (0, 255, 0), 3)
    text = "eps={:.4f}, num_pts={}".format(0.001, len(approx))
    cv2.putText(output, text, (x, y - 15), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 0), 2)
    
    return output

# Testing frame for shadow detection
gameFrame = cv2.cvtColor(cv2.imread("C:/Users/sapar/Desktop/Test Aruco Marker/GameFrame.png"), cv2.COLOR_BGR2GRAY)

# CharUco board creation (same as printed one)
dictionary = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_6X6_250)
board = cv2.aruco.CharucoBoard((squaresX, squaresY), squareLength, markerLength, dictionary)
detector_parameters = cv2.aruco.DetectorParameters()
charuco_parameters = cv2.aruco.CharucoParameters()
charuco_detector = cv2.aruco.CharucoDetector(board, charuco_parameters, detector_parameters)

# Loop to process video capture for calibration
while True:
    ok, frame = cap.read()
    if not ok:
        break

    charucoCorners, charucoIds, markerCorners, markerIds = charuco_detector.detectBoard(frame)
    
    imageSize = None

    h, w = frame.shape[:2]
    if imageSize is None:
        imageSize = (w, h)

    if SHOW_DEBUG:
        test = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        if markerIds is not None and len(markerIds) > 0:
            cv2.aruco.drawDetectedMarkers(test, markerCorners, markerIds)
        if charucoIds is not None and len(charucoIds) > 0:
            cv2.aruco.drawDetectedCornersCharuco(test, charucoCorners, charucoIds)
            cv2.imshow("Detection debug (SPACE TO CAPTURE FRAME FOR CALIBRATION)", test)

    key = cv2.waitKey(1) & 0xFF
        
    # Space to calibrate camera with the current frame
    if key == ord(' '):

        if charucoIds is None or len(charucoCorners) < 4:
                continue

        objPoints, imgPoints = board.matchImagePoints(charucoCorners, charucoIds)  

        all_object_points.append(objPoints.astype(np.float32))
        all_image_points.append(imgPoints.astype(np.float32))

    # Esc to quit
    if key == 27:
        break
    
cv2.destroyAllWindows()
cap.release()

# Camera Calibration to then undistort the projector's screen when warping it
ret, camMatrix, distCoeffs, rvecs, tvecs = cv2.calibrateCamera(
        all_object_points,
        all_image_points,
        imageSize,
        None,
        None
    )

''' Save calibration data'''
'''path_to_save = "C:/"

file_name = "camera_params.npz"

np.savez(
    os.path.join(path_to_save, file_name),
    camMatrix=camMatrix,
    distCoeffs=distCoeffs,
    ret=ret
    )

print("RMS reprojection error:", ret)
print("\ncamMatrix:\n", camMatrix)
print("\ndistCoeffs:\n", distCoeffs)'''

# to get (X, Y) shaped 2D points from (X, Y, Z)
objPoints2d = objPoints[:, 0, :2]

# to get (x, y) shaped 2D points from imgPoints (x, y)
imgPoints2d = imgPoints[:, 0, :]

newcameramtx, roi = cv2.getOptimalNewCameraMatrix(camMatrix, distCoeffs, (w,h), 1, (w,h))
imgPoints2d_undist = cv2.undistortPoints(imgPoints2d.reshape(-1,1,2), camMatrix, distCoeffs, P=newcameramtx)
imgPoints2d_undist = imgPoints2d_undist.reshape(-1,2) # to make it (N, 2) shape from (N, 1, 2) again

boardWidth = squaresX * squareLength
boardHeight = squaresY * squareLength

warpPixelsX = WARP_W / boardWidth
warpPixelsY = WARP_H / boardHeight

# srcPoints and dstPoints for findHomography
srcPoints = imgPoints2d_undist.astype(np.float32)
dstPoints = np.column_stack ([objPoints2d[:, 0] * warpPixelsX, objPoints2d[:, 1] * warpPixelsY]).astype(np.float32)

# Loop for shadow detection
while True:
    ok, frame = cap.read()
    if not ok:
        break
                                                          
    H, inliers = cv2.findHomography(srcPoints, dstPoints, cv2.RANSAC, 3.0)

    if H is not None:
        numInliers = int(inliers.sum())
        print("\nGood points:", numInliers, "out of", len(inliers), "\n")
        warped_frame = cv2.warpPerspective(frame, H, (WARP_W, WARP_H))
        cv2.imshow("Game Screen View", warped_frame)

    # Convert to grayscale and blur to reduce noise
    gray = cv2.cvtColor(warped_frame, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (3, 3), 0)

    # Snaps colors to extre
    threshold = cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY)[1]

    # Finds difference between current frame and reference frame
    # Results in white shapes where shadows are detected
    difference = cv2.subtract(gameFrame, threshold)

    # Shadow detection through contour processing
    output = processShadowContours(difference)

    # Current endpoint for testing
    cv2.imshow("Current", output)

    # Exits on 'ESC' key press
    if cv2.waitKey(1) & 0xFF == 27:
        break

# Clean up
cap.release()
cv2.destroyAllWindows()