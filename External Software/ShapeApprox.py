
import cv2
import imutils
import numpy as np

###
### To get all contours, switch cv2.RETR_EXTERNAL to cv2.RETR_LIST and loop through cnts
###

# Import Frames
gameFrame = cv2.imread("Test Images\\GameFrame.png")
cameraFrame = cv2.imread("Test Images\\CameraFrame4.png")

# Subtract Frames to Find Difference and Invert
difference = cv2.bitwise_not(cv2.subtract(gameFrame, cameraFrame))

def locateEShadows():
    ### https://pyimagesearch.com/2021/10/06/opencv-contour-approximation/
    # The following two locate shadow functions use the method defined in the above link.
    # The second function is modified to display all contours instead of the largest external contour.
    gray = cv2.cvtColor(difference, cv2.COLOR_BGR2GRAY)
    thresh = cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY_INV)[1]

    cnts = cv2.findContours(thresh.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    cnts = imutils.grab_contours(cnts)
    c = max(cnts, key=cv2.contourArea)
    # draw the shape of the contour on the output image, compute the
    # bounding box, and display the number of points in the contour
    output = difference.copy()
    cv2.drawContours(output, [c], -1, (0, 255, 0), 3)
    (x, y, w, h) = cv2.boundingRect(c)
    text = "original, num_pts={}".format(len(c))
    cv2.putText(output, text, (x, y - 15), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 0), 2)

    """
    for eps in np.linspace(0.001, 0.07, 10):
        # approximate the contour
        peri = cv2.arcLength(c, True)
        approx = cv2.approxPolyDP(c, eps * peri, True)
        # draw the approximated contour on the image
        output = difference.copy()
        cv2.drawContours(output, [approx], -1, (0, 255, 0), 3)
        text = "eps={:.4f}, num_pts={}".format(eps, len(approx))
        cv2.putText(output, text, (x, y - 15), cv2.FONT_HERSHEY_SIMPLEX,
            0.9, (0, 255, 0), 2)
        # show the approximated contour image
        print("[INFO] {}".format(text))
        cv2.imshow("Approximated Contour", output)
        cv2.waitKey(0)
    """
    # approximate the contour
    peri = cv2.arcLength(c, True)
    approx = cv2.approxPolyDP(c, 0.001 * peri, True)
    # draw the approximated contour on the image
    output = difference.copy()
    cv2.drawContours(output, [approx], -1, (0, 255, 0), 3)
    text = "eps={:.4f}, num_pts={}".format(0.001, len(approx))
    cv2.putText(output, text, (x, y - 15), cv2.FONT_HERSHEY_SIMPLEX,
        0.9, (0, 255, 0), 2)
    # show the approximated contour image
    print("[INFO] {}".format(text))
    print(approx)
    cv2.imshow("Approximated Contour", output)
    cv2.waitKey(0)
    ###

def locateAShadows():
    gray = cv2.cvtColor(difference, cv2.COLOR_BGR2GRAY)
    thresh = cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY_INV)[1]

    cnts = cv2.findContours(thresh.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    cnts = imutils.grab_contours(cnts)

    output = difference.copy()
    for c in cnts:
        # draw the shape of the contour on the output image, compute the
        # bounding box, and display the number of points in the contour
        cv2.drawContours(output, [c], -1, (0, 255, 0), 3)
        (x, y, w, h) = cv2.boundingRect(c)

        # approximate the contour
        peri = cv2.arcLength(c, True)
        approx = cv2.approxPolyDP(c, 0.001 * peri, True)
        # draw the approximated contour on the image
        cv2.drawContours(output, [approx], -1, (0, 255, 0), 3)
        text = "eps={:.4f}, num_pts={}".format(0.001, len(approx))
        cv2.putText(output, text, (x, y - 15), cv2.FONT_HERSHEY_SIMPLEX,   0.9, (0, 255, 0), 2)
        # show the approximated contour image
        print("[INFO] {}".format(text))
    cv2.imshow("Approximated Contour", output)
    cv2.waitKey(0)
    ###

locateAShadows()
