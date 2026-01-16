import cv2 
import numpy as np
import os

# Charuco Board's size parameters
squaresX = 8
squaresY = 11
squareLength = 0.04
markerLength = 0.025  
all_object_points = []
all_image_points = []
SHOW_DEBUG = True

def main():
    # Create the board that is the same as printed one, to detect it with CharucoDetector to then use detectBoard
    dictionary = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_6X6_250)
    board = cv2.aruco.CharucoBoard((squaresX, squaresY), squareLength, markerLength, dictionary)
    detector_parameters = cv2.aruco.DetectorParameters()
    charuco_parameters = cv2.aruco.CharucoParameters()
    charuco_detector = cv2.aruco.CharucoDetector(board, charuco_parameters, detector_parameters)
    imageSize = None

    cap = cv2.VideoCapture(0) 
    if not cap.isOpened():
        print("Webcam not open")
        return

    while True:
        ok, img = cap.read()
        if not ok:
            break
        
        h, w = img.shape[:2]
        if imageSize is None:
            imageSize = (w, h)
    
        charucoCorners, charucoIds, markerCorners, markerIds = charuco_detector.detectBoard(img)

        if SHOW_DEBUG:
            test = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            if markerIds is not None and len(markerIds) > 0:
                cv2.aruco.drawDetectedMarkers(test, markerCorners, markerIds)
            if charucoIds is not None and len(charucoIds) > 0:
                cv2.aruco.drawDetectedCornersCharuco(test, charucoCorners, charucoIds)
            cv2.imshow("Detection debug (SPACE TO CAPTURE FRAME FOR CALIBRATION)", test)

        key = cv2.waitKey(1) & 0xFF

        # Esc to quit
        if key == 27:
            break
        
        # Space to calibrate camera with the current frame
        if key == ord(' '):

            if charucoIds is None or len(charucoCorners) < 4:
                continue
            
            objPoints, imgPoints = board.matchImagePoints(charucoCorners, charucoIds)  

            all_object_points.append(objPoints.astype(np.float32))
            all_image_points.append(imgPoints.astype(np.float32))
    
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

    np.savez(
        "camera_calib.npz",
        camMatrix=camMatrix,
        distCoeffs=distCoeffs,
        ret=ret
    )

if __name__ == "__main__":

    main()

