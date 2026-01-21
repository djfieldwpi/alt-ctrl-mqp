
import cv2
import numpy as np
import imutils

# Opens camera feed and sets resolution
# 0: laptop webcam
# 1: external camera
cap = cv2.VideoCapture(1)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)

# Corner arrays for planar mapping
corners = []
normalCorners = [[0, 0], [1920, 0], [1920, 1080], [0, 1080]]

# Event for mouse clicks to store corner points
# Select corners in clockwise order starting from top-left
def click_event(event, x, y, flags, params):
    if event == cv2.EVENT_LBUTTONDOWN:
        print(f"Clicked at: ({x}, {y})")
        corners.append([x, y])
        if len(corners) == 4:
            cv2.destroyWindow("Frame")

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
    
    return output, approx

# Testing frame for shadow detection
gameFrame = cv2.cvtColor(cv2.imread("C:/Users/field/Desktop/College Documents/MQP/alt-ctrl-mqp/External Software/Test Images/GameFrame.png"), cv2.COLOR_BGR2GRAY)

# Main loop to process video capture
while True:
    # Branch for corner selection and shadow detection
    # Corner Selection
    if len(corners) < 4:
        # Shows natural frames for corner selection
        _, frame = cap.read()
        frame_copy = frame.copy()
        cv2.imshow("Frame", frame)

        cv2.setMouseCallback("Frame", click_event)

    # Shadow detection
    else:
        # Uses selected corners to perform planar mapping
        H, mask = cv2.findHomography(np.array(corners), np.array(normalCorners), cv2.RANSAC, 5.0)
        _, frame = cap.read()
        warped_frame = cv2.warpPerspective(frame, H, (1920, 1080))

        # Convert to grayscale and blur to reduce noise
        gray = cv2.cvtColor(warped_frame, cv2.COLOR_BGR2GRAY)
        gray = cv2.GaussianBlur(gray, (3, 3), 0)

        # Snaps colors to extre
        threshold = cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY)[1]

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
print(approx)

# Clean up
cap.release()
cv2.destroyAllWindows()