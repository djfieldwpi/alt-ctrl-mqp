import time
import cv2 
import numpy as np

dictionary = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_6X6_250)
squares_horiz = 16
squares_vert = 9
square_length_meters = 0.02
marker_length_meters = 0.015

board = cv2.aruco.CharucoBoard((squares_horiz, squares_vert), square_length_meters, marker_length_meters, dictionary)

image_size = (1280, 720)

board_image = board.generateImage(image_size)

if board_image is not None:
    cv2.imshow("Charuco Board", board_image)
    cv2.waitKey(0)
    cv2.destroyAllWindows()
