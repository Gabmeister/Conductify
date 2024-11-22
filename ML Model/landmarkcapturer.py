import mediapipe as mp
import csv
import numpy as np
import cv2
import os

capture_flag = False
mp_hands = mp.solutions.hands
hands = mp_hands.Hands(static_image_mode=True, max_num_hands=1, min_detection_confidence=0.5)
mp_drawing = mp.solutions.drawing_utils

cap = cv2.VideoCapture(0)

csv_file = 'hand_landmarks.csv'
# check if the csv file exists and is not empty
file_exists = os.path.isfile(csv_file) and os.path.getsize(csv_file) > 0

# add header if the file is new or empty
with open(csv_file, 'a', newline='') as file:
    writer = csv.writer(file)
    if not file_exists:
        header = ['x{}'.format(i) for i in range(1, 22)] + ['y{}'.format(i) for i in range(1, 22)] + ['z{}'.format(i) for i in range(1, 22)] + ['gesture_label']
        writer.writerow(header)

# image processing mechanism
def capture_landmarks(image):
    global capture_flag
    if capture_flag:  # prevent processing 'c' if capture is already in progress
        return
    capture_flag = True  # indicate capture processing start
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB) # convert image to RGB 
    results = hands.process(image_rgb) # process image to find landmarks
    
    if results.multi_hand_landmarks: # if landmarks detected
        for hand_landmarks in results.multi_hand_landmarks:
            # extract image dimensions
            h, w, _ = image.shape 
            # get coordinates of landmarks from image
            landmark_coords = [(landmark.x * w, landmark.y * h) for landmark in hand_landmarks.landmark]
            # calculate bounding box around hand
            min_x, min_y = min(landmark_coords)[0], min(landmark_coords, key=lambda x: x[1])[1]
            max_x, max_y = max(landmark_coords)[0], max(landmark_coords, key=lambda x: x[1])[1]
            # crop new image using bounding box 
            cropped_image = image[int(min_y):int(max_y), int(min_x):int(max_x)]
            # create fixed sized image 400x400 for backdrop
            fixed_size_image = np.zeros((400, 400, 3), dtype=np.uint8)
            
            # calculate the offsets for centering cropped image onto fixed size image 
            fixed_h, fixed_w, _ = fixed_size_image.shape
            x_offset = max((fixed_w - cropped_image.shape[1]) // 2, 0)
            y_offset = max((fixed_h - cropped_image.shape[0]) // 2, 0)
            x_end = min(x_offset + cropped_image.shape[1], fixed_w)
            y_end = min(y_offset + cropped_image.shape[0], fixed_h)
            
            # center the cropped image onto the fixed size image
            cropped_fit = cropped_image[0:(y_end-y_offset), 0:(x_end-x_offset)]
            fixed_size_image[y_offset:y_end, x_offset:x_end] = cropped_fit
            # process new fixed size image for updated hand landmarks
            fixed_size_image_rgb = cv2.cvtColor(fixed_size_image, cv2.COLOR_BGR2RGB)
            results_fixed = hands.process(fixed_size_image_rgb)

            if results_fixed.multi_hand_landmarks:
                for fixed_hand_landmarks in results_fixed.multi_hand_landmarks:
                    normalized_landmarks = []
                    # extract and store landmarks from fixed size image
                    for landmark in fixed_hand_landmarks.landmark:
                        normalized_x = landmark.x
                        normalized_y = landmark.y
                        normalized_z = landmark.z
                        normalized_landmarks.extend([normalized_x, normalized_y, normalized_z])
                    # append gesture_label to end of array 
                    normalized_landmarks.append('nextsong')
                    # write landmarks to csv 
                    with open(csv_file, 'a', newline='') as file:
                        writer = csv.writer(file)
                        writer.writerow(normalized_landmarks)
                    # display landmarks and fixed size image to user
                    mp_drawing.draw_landmarks(fixed_size_image, fixed_hand_landmarks, mp_hands.HAND_CONNECTIONS)
                    cv2.imshow('Fixed Size Frame with Landmarks', fixed_size_image)
    # indicate processing finished
    capture_flag = False

while cap.isOpened():
    success, image = cap.read()
    if not success:
        print("empty camera frame")
        continue

    cv2.imshow('Frame', image)
    if cv2.waitKey(1) & 0xFF == ord('c'):
        capture_landmarks(image)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()