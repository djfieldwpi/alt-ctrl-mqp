import cv2
import numpy as np
import imutils
import os

SIGNAL_PATH = "D:/MQP/alt-ctrl-mqp/signal.txt"

cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)

squaresX = 13
squaresY = 9
squareLength = 0.02
markerLength = 0.0147  

WARP_W = 1920
WARP_H = 1080

bestInliers = 0
bestH = None
warpFound = False

bg = None
BG_ALPHA = 0.01

BG_ALPHA_RECOVER = 0.25  # fast background recovery after UNLOCK
RECOVER_FRAMES = 45      # frames to use BG_ALPHA_RECOVER after UNLOCK/ 
FORCE_CLEAR_DELTA = 12   # if old shadow region becomes brighter, force-clear residue/ reduce = intense

LOCK_CMDS = {"GO", "LOCK", "LOCKED"}

locked = False
recovery_frames = 0
last_locked_mask = None

MIN_AREA = 1500
MIN_EXTENT = 0.30

kernel_open = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
kernel_close = cv2.getStructuringElement(cv2.MORPH_RECT, (11, 7))

dictionary = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_6X6_250)
board = cv2.aruco.CharucoBoard((squaresX, squaresY), squareLength, markerLength, dictionary)
detector_parameters = cv2.aruco.DetectorParameters()
charuco_parameters = cv2.aruco.CharucoParameters()
charuco_parameters.tryRefineMarkers = True
charuco_detector = cv2.aruco.CharucoDetector(board, charuco_parameters, detector_parameters)

imageSize = None

all_object_points = []
all_image_points = []

while True:
    ok, frame = cap.read()
    if not ok:
        break

    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    charucoCorners, charucoIds, markerCorners, markerIds = charuco_detector.detectBoard(gray)

    if imageSize is None:
        imageSize = (frame.shape[1], frame.shape[0])

    debug = gray.copy()
    if markerIds is not None:
        cv2.aruco.drawDetectedMarkers(debug, markerCorners, markerIds)
    if charucoIds is not None:
        cv2.aruco.drawDetectedCornersCharuco(debug, charucoCorners, charucoIds)

    cv2.imshow("Calibration (SPACE to capture, ESC to finish)", debug)

    key = cv2.waitKey(1) & 0xFF
    if key == ord(' ') and charucoIds is not None and len(charucoIds) >= 12:
        objPts, imgPts = board.matchImagePoints(charucoCorners, charucoIds)
        all_object_points.append(objPts.astype(np.float32))
        all_image_points.append(imgPts.astype(np.float32))

    if key == 27:
        break

cv2.destroyAllWindows()

ret, camMatrix, distCoeffs, rvecs, tvecs = cv2.calibrateCamera(
    all_object_points, all_image_points, imageSize, None, None
)

while True:
    ok, frame = cap.read()
    if not ok:
        break

    # --- signal handling (LOCK/UNLOCK) ---
    cmd = ""
    if os.path.exists(SIGNAL_PATH):
        try:
            with open(SIGNAL_PATH, "r") as f:
                cmd = f.read().strip()
        except Exception:
            cmd = ""

    cmd_u = cmd.upper()
    # detect GO request

   # transition-based recovery trigger (GO -> DONE/anything else)
    prev_locked = locked
    locked = lock_event

    # when we leave locked state, start fast recovery + residue cleanup window
    if prev_locked and (not locked):
      recovery_frames = RECOVER_FRAMES

    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
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

    if not warpFound:
        cv2.imshow("Raw Camera", frame)
        if cv2.waitKey(1) & 0xFF == 27:
            break
        continue

    undist = cv2.undistort(frame, camMatrix, distCoeffs, None, newcameramtx)
    warped = cv2.warpPerspective(undist, bestH, (WARP_W, WARP_H))

    gray_w = cv2.cvtColor(warped, cv2.COLOR_BGR2GRAY)
    gray_w = cv2.GaussianBlur(gray_w, (5, 5), 0)
    gray_w = cv2.medianBlur(gray_w, 5)

    if bg is None:
        bg = gray_w.astype(np.float32)
        continue

    bg_u8 = cv2.convertScaleAbs(bg)

    diff = cv2.absdiff(gray_w, bg_u8)
    signed_delta = gray_w.astype(np.int16) - bg_u8.astype(np.int16)

    mean = np.mean(diff)
    std = np.std(diff)
    thresh_val = int(np.clip(mean + 0.8 * std, 12, 60))

    _, mask = cv2.threshold(diff, thresh_val, 255, cv2.THRESH_BINARY)

    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel_open)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel_close)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel_open)

    # --- background update ---
    # Freeze background while locked. When unlocked, recover fast then return to normal.
    if not locked:
        alpha = BG_ALPHA_RECOVER if recovery_frames > 0 else BG_ALPHA
        update_mask = (mask == 0)
        # Force-clear old shadow residue in the last locked region when it becomes brighter than bg.
        if recovery_frames > 0 and last_locked_mask is not None:
            force_mask = (last_locked_mask > 0) & (signed_delta > FORCE_CLEAR_DELTA)
            update_mask = update_mask | force_mask
        if np.any(update_mask):
            bg[update_mask] = (1.0 - alpha) * bg[update_mask] + alpha * gray_w[update_mask]
        if recovery_frames > 0:
            recovery_frames -= 1

    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    best_cnt = None
    best_score = 0

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

    # --- lock capture: freeze bg + send polygon (one-shot) ---
    if lock_event:
        # remember where the last locked shadow was (to clear residue after UNLOCK)
        if best_cnt is not None:
            _lm = np.zeros_like(mask)
            cv2.drawContours(_lm, [best_cnt], -1, 255, thickness=-1)
            _lm = cv2.dilate(_lm, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)), iterations=1)
            last_locked_mask = _lm
        else:
            last_locked_mask = mask.copy()

        try:
            with open(SIGNAL_PATH, "w") as f:
                f.write("DONE\n")
                if best_cnt is not None:
                    approx = cv2.approxPolyDP(best_cnt, 4, True)
                    for p in approx:
                        x, y = p[0]
                        f.write(f"{x} {y}\n")
        except Exception:
            pass

    if best_cnt is not None:
        x, y, w, h = cv2.boundingRect(best_cnt)
        cx = int(x + w / 2)
        cy = int(y + h / 2)
        cv2.circle(warped, (cx, cy), 10, (0, 255, 0), -1)

    cv2.imshow("Warped Frame", warped)
    cv2.imshow("Shadow Mask", mask)

    if cv2.waitKey(1) & 0xFF == 27:
        break

cap.release()
cv2.destroyAllWindows()
