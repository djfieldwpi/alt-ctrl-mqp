import cv2
import numpy as np
import time
import json


#
# Camera setup
#

cap = cv2.VideoCapture(0)      # open default camera

# warm up camera for stable exposure
for _ in range(30):
    ret, _ = cap.read()
    if not ret:
        break


#
# bg & parameters
#

bg = None                      # bg reference frame
diff_gain = 2.0                # amplify difference signal

MIN_AREA = 1500                # minimum region area to be considered
MIN_EXTENT = 0.30              # how filled the bounding box must be
EVENT_COOLDOWN = 0.6           # minimum time between ShadowEvents (seconds)

last_event_time = 0            # timestamp of last triggered event


#
# Morphology kernels
#

# remove small speckle noise
kernel_open = cv2.getStructuringElement(
    cv2.MORPH_ELLIPSE, (3, 3)
)

# connect irregular hand-shaped shadows
kernel_close = cv2.getStructuringElement(
    cv2.MORPH_RECT, (11, 7)
)


#
# Main loop
#

while True:
    ret, frame = cap.read()    # read next camera frame
    if not ret:
        break


    #
    # 1. Grayscale + filtering
    #

    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)   # convert to grayscale
    gray = cv2.GaussianBlur(gray, (5, 5), 0)         # reduce high-frequency noise
    gray = cv2.medianBlur(gray, 5)                   # suppress salt-and-pepper noise


    #
    # 2. bg reference
    #

    if bg is None:              # no bg
        bg = gray.copy()        # initialize bg
        continue


    #
    # 3. bg subtraction
    #

    diff = cv2.absdiff(gray, bg)                      # compute frame difference
    diff = cv2.convertScaleAbs(diff, alpha=diff_gain) # amplify difference


    #
    # 4. Adaptive threshold
    #

    mean = float(np.mean(diff))                       # mean difference
    std = float(np.std(diff))                         # difference variance
    thresh_val = int(np.clip(mean + 0.8 * std, 12, 60))

    _, mask = cv2.threshold(
        diff, thresh_val, 255, cv2.THRESH_BINARY
    )                                                  # binary motion mask


    #
    # 5. Morphological cleanup
    #

    # remove isolated noise
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel_open)

    # connect nearby shadow regions
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel_close)

    # final cleanup pass
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel_open)


    #
    # 6. Contour detection
    #

    contours, _ = cv2.findContours(
        mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
    )

    best_cnt = None
    best_score = 0
    best_metrics = None

    # select most plausible walkable region
    for cnt in contours:
        area = cv2.contourArea(cnt)
        if area < MIN_AREA:
            continue

        x, y, w, h = cv2.boundingRect(cnt)
        extent = area / float(w * h + 1e-5)

        # prefer large and reasonably filled regions (white)
        score = area * extent

        if score > best_score:
            best_score = score
            best_cnt = cnt
            best_metrics = (x, y, w, h, area, extent)


    vis = frame.copy()          # visualization frame


    #
    # 7. Walkable region + ShadowEvent
    #

    if best_cnt is not None:
        x, y, w, h, area, extent = best_metrics
        is_walkable = extent >= MIN_EXTENT

        now = time.time()
        if is_walkable and (now - last_event_time) > EVENT_COOLDOWN:
            cx = x + w / 2
            cy = y + h / 2

            shadow_event = {
                "type": "WALKABLE_REGION",
                "center": [float(cx), float(cy)],
                "size": [int(w), int(h)],
                "area": int(area),
                "confidence": round(min(1.0, extent), 2),
                "timestamp": round(now, 2)
            }

            last_event_time = now
            print("ShadowEvent:", shadow_event)

            # write event for integration
            try:
                with open("shadow_event.json", "w") as f:
                    json.dump(shadow_event, f)
            except:
                pass


        # visualization overlay
        color = (0, 255, 0) if is_walkable else (0, 0, 255)

        cv2.rectangle(vis, (x, y), (x + w, y + h), color, 2)
        (cx, cy), r = cv2.minEnclosingCircle(best_cnt)
        cv2.circle(vis, (int(cx), int(cy)), int(r), color, 2)

        cv2.putText(
            vis,
            f"WALKABLE EXT:{extent:.2f}",
            (x, y - 10),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.5,
            (0, 255, 255),
            1
        )


    #
    # 8. Debug display
    #

    cv2.imshow("diff", diff)    # raw difference signal
    cv2.imshow("mask", mask)    # cleaned binary mask
    cv2.imshow("vis", vis)      # final visualization


    #
    # 9. Controls
    #

    key = cv2.waitKey(1) & 0xFF
    if key == 27:               # ESC  quit
        break
    if key == ord('b'):         # reset bg
        bg = gray.copy()


#
# to cleanup
#

cap.release()
cv2.destroyAllWindows()
