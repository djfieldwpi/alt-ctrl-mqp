import cv2
import numpy as np
import time

cap = cv2.VideoCapture(0)

for _ in range(30):
    ret, _ = cap.read()
    if not ret:
        break

bg = None
diff_gain = 2.0

MIN_AREA = 1500
MIN_EXTENT = 0.30

kernel_open = cv2.getStructuringElement(
    cv2.MORPH_ELLIPSE, (3, 3)
)

kernel_close = cv2.getStructuringElement(
    cv2.MORPH_RECT, (11, 7)
)

bestH = np.eye(3, dtype=np.float32)

WARP_W = 1280
WARP_H = 720

while True:
    ret, frame = cap.read()
    if not ret:
        break

    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (5, 5), 0)
    gray = cv2.medianBlur(gray, 5)

    if bg is None:
        bg = gray.copy()
        continue

    diff = cv2.absdiff(gray, bg)
    diff = cv2.convertScaleAbs(diff, alpha=diff_gain)

    mean = float(np.mean(diff))
    std = float(np.std(diff))
    thresh_val = int(np.clip(mean + 0.8 * std, 12, 60))

    _, mask = cv2.threshold(
        diff, thresh_val, 255, cv2.THRESH_BINARY
    )

    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel_open)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel_close)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel_open)

    contours, _ = cv2.findContours(
        mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
    )

    best_cnt = None
    best_score = 0
    best_metrics = None

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
            best_metrics = (x, y, w, h, area, extent)

    warped_frame = cv2.warpPerspective(
        frame,
        bestH,
        (WARP_W, WARP_H)
    )

    if best_cnt is not None:
        x, y, w, h, area, extent = best_metrics
        is_walkable = extent >= MIN_EXTENT

        cx = x + w / 2
        cy = y + h / 2

        pt = np.array([[[cx, cy]]], dtype=np.float32)
        mapped = cv2.perspectiveTransform(pt, bestH)

        mx, my = mapped[0][0]

        color = (0, 255, 0) if is_walkable else (0, 0, 255)

        cv2.circle(
            warped_frame,
            (int(mx), int(my)),
            12,
            color,
            -1
        )

        cv2.putText(
            warped_frame,
            f"SHADOW EXT:{extent:.2f}",
            (int(mx) + 10, int(my)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.5,
            color,
            1
        )

    cv2.imshow("Raw Camera", frame)
    cv2.imshow("Mask", mask)
    cv2.imshow("Warped Frame", warped_frame)

    key = cv2.waitKey(1) & 0xFF
    if key == 27:
        break
    if key == ord('b'):
        bg = gray.copy()

cap.release()
cv2.destroyAllWindows()

