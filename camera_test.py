import cv2
import numpy as np

cap = cv2.VideoCapture(0)          # open default camera

for _ in range(30):                # stable exposure
    ret, frame = cap.read()
    if not ret:
        break

bg = None                          # bg (gray)
diff_gain = 2.0                    # diff amplification
min_area = 1500                    # minimum valid area

while True:
    ret, frame = cap.read()        # read  the every frame
    if not ret:
        break

    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)   # to grayscale
    gray = cv2.GaussianBlur(gray, (3, 3), 0)         # reduce noise

    if bg is None:                 # if no bg
        bg = gray.copy()           # set bg
        continue

    diff = cv2.absdiff(gray, bg)   # bg diff
    diff = cv2.convertScaleAbs(diff, alpha=diff_gain)  # amplify diff

    m = float(np.mean(diff))       # mean diff
    s = float(np.std(diff))        # ddiff variance
    thr = int(np.clip(m + 0.8 * s, 12, 60))  # adaptive threshold

    _, mask = cv2.threshold(diff, thr, 255, cv2.THRESH_BINARY)  # binary mask

    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))  # morphology kernel
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)       # remove small noise

    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE) # find contours

    vis = frame.copy()             # visualization
    best = None
    best_area = 0

    for cnt in contours:
        area = cv2.contourArea(cnt)
        if area < min_area:
            continue
        if area > best_area:
            best_area = area
            best = cnt

    if best is not None:
        x, y, w, h = cv2.boundingRect(best)           # bounding box
        cv2.rectangle(vis, (x, y), (x+w, y+h), (0,255,0), 2)
        (cx, cy), r = cv2.minEnclosingCircle(best)    # enclosing circle
        cv2.circle(vis, (int(cx), int(cy)), int(r), (0,0,255), 2)

    cv2.imshow("mask", mask)       # show mask
    cv2.imshow("vis", vis)         # show result

    key = cv2.waitKey(1) & 0xFF
    if key == 27:                  # ESC  quit
        break
    if key == ord('b'):            # reset bg
        bg = gray.copy()

cap.release()                      # release camera
cv2.destroyAllWindows()            # close windows
