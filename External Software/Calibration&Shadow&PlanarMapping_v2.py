import cv2
import numpy as np
import imutils
import os

# Opens camera feed and sets resolution
# 0: laptop webcam
# 1: external camera
cap = cv2.VideoCapture(1)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

# Charuco Board's size parameters
squaresX = 16
squaresY = 9
squareLength = 0.02
markerLength = 0.015  

all_object_points = []
all_image_points = []
SHOW_DEBUG = True

# Warped output's image size
WARP_W = 1920
WARP_H = 1080

# To keep only the best for planar mapping
bestInliers = 0
bestDstPoints = None
bestSrcPoints = None
bestFrame = None
bestH = None

#
def processShadowContours(difference):
    #
    cnts = cv2.findContours(difference.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    cnts = imutils.grab_contours(cnts)
    if cnts:
        c = max(cnts, key=cv2.contourArea)
    else:
        return difference, np.array([])

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
    text = "eps={:.4f}, num_pts={}".format(0.002, len(approx))
    cv2.putText(output, text, (x, y - 15), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 0), 2)
    
    return output, approx

# Testing frame for shadow detection
gameFrame = cv2.cvtColor(cv2.imread("C:/Users/field/Desktop/College Documents/MQP/alt-ctrl-mqp/External Software/Test Images/GodotFrame.png"), cv2.COLOR_BGR2GRAY)
gameFrame = cv2.resize(gameFrame, (WARP_W, WARP_H))

# CharUco board creation (same as printed one)
dictionary = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_6X6_250)
board = cv2.aruco.CharucoBoard((squaresX, squaresY), squareLength, markerLength, dictionary)
detector_parameters = cv2.aruco.DetectorParameters()
charuco_parameters = cv2.aruco.CharucoParameters()
charuco_parameters.tryRefineMarkers = True
charuco_detector = cv2.aruco.CharucoDetector(board, charuco_parameters, detector_parameters)
imageSize = None

# Loop to process video capture for calibration
while True:
    ok, frame = cap.read()
    if not ok:
        break

    # For better detection give grayscale to detectBoard
    frame_gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

    charucoCorners, charucoIds, markerCorners, markerIds = charuco_detector.detectBoard(frame_gray)

    h, w = frame.shape[:2]
    if imageSize is None:
        imageSize = (w, h)
        board_image = board.generateImage(imageSize)
        if board_image is not None:
            cv2.namedWindow("Charuco Board", cv2.WINDOW_NORMAL)
            cv2.setWindowProperty("Charuco Board", cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)
            cv2.imshow("Charuco Board", board_image)

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

        if charucoIds is None or len(charucoIds) < 12:
                continue

        objPoints, imgPoints = board.matchImagePoints(charucoCorners, charucoIds)  

        all_object_points.append(objPoints.astype(np.float32))
        all_image_points.append(imgPoints.astype(np.float32))

    # Esc to quit
    if key == 27:
        break
    
cv2.destroyAllWindows()

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
warpFound = False

# Loop for shadow detection and homography
while True:
    ok, frame = cap.read()
    if not ok:
        break

    if charucoIds is not None and len(charucoIds) >= 12:

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
                                                          
        H, inliers = cv2.findHomography(srcPoints, dstPoints, cv2.RANSAC, 3.0) # Higher threshold than 5.0 might be better for projector screen since it can be far

        numInliers = int(inliers.sum())

        if H is not None and numInliers is not None:
            if numInliers > bestInliers:
                bestInliers = numInliers
                bestFrame = frame.copy()
                bestH = H
                bestSrcPoints = srcPoints
                bestDstPoints = dstPoints 

        if bestH is not None:
            warpFound = True

    if warpFound:
        bestFrame_undist = cv2.undistort(frame, camMatrix, distCoeffs, None, newcameramtx) # Undistort whole image before passing it to warpPerspective
        warped_frame = cv2.warpPerspective(bestFrame_undist, bestH, (WARP_W, WARP_H))
        cv2.imshow("Game Screen View", warped_frame) 

    gameFrame = cv2.cvtColor(cv2.imread("C:/Users/field/Desktop/College Documents/MQP/alt-ctrl-mqp/External Software/Test Images/GodotFrame.png"), cv2.COLOR_BGR2GRAY)
    gameFrame = cv2.resize(gameFrame, (WARP_W, WARP_H))

    # Convert to grayscale and blur to reduce noise
    gray = cv2.cvtColor(warped_frame, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (3, 3), 0)

    # Snaps colors to extre
    threshold = cv2.threshold(gray, 210, 255, cv2.THRESH_BINARY)[1]

    threshold = cv2.bitwise_not(threshold)

    # Finds difference between current frame and reference frame
    # Results in white shapes where shadows are detected
    difference = cv2.subtract(gameFrame, threshold)

    # Shadow detection through contour processing
    output, approx = processShadowContours(difference)

    # Current endpoint for testing
    cv2.imshow("Current", output)

    # Exits on 'ESC' key press
    if cv2.waitKey(1) & 0xFF == 27:
        break

    approx = '\n'.join([str(x).replace("[", "").replace("]", "") for x in approx])

    with open("C:\\Users\\field\\Desktop\\College Documents\\MQP\\alt-ctrl-mqp\\signal.txt", 'r') as f:
        if (f.readline().strip() == "GO"):
            f.close()
            with open("C:\\Users\\field\\Desktop\\College Documents\\MQP\\alt-ctrl-mqp\\signal.txt", 'w') as f:
                
                f.write("DONE\n" + approx)
                f.close()

# Clean up
cap.release()
cv2.destroyAllWindows()