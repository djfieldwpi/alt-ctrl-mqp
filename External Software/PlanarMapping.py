
import cv2
import numpy as np

cap = cv2.VideoCapture(1)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)

corners = []
normalCorners = [[0, 0], [1920, 0], [1920, 1080], [0, 1080]]

def click_event(event, x, y, flags, params):
    if event == cv2.EVENT_LBUTTONDOWN:
        print(f"Clicked at: ({x}, {y})")
        corners.append([x, y])

while True:
    _, frame = cap.read()
    frame_copy = frame.copy()
    cv2.imshow("Frame", frame)

    cv2.setMouseCallback("Frame", click_event)

    if len(corners) == 4:
        H, mask = cv2.findHomography(np.array(corners), np.array(normalCorners), cv2.RANSAC, 5.0)
        warped_frame = cv2.warpPerspective(frame_copy, H, (1920, 1080))
        cv2.imshow("Warped Frame", warped_frame)
   
    if cv2.waitKey(1) & 0xFF == 27:
        break

cap.release()
cv2.destroyAllWindows()