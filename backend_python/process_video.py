import cv2
import mediapipe as mp
import numpy as np
import os

# --- CONFIGURATION ---
VIDEO_PATH = "sinhala_alphabet.f605.mp4"  # The video file to process
OUTPUT_DIR = "output_signs_large"    # Using a new folder for the larger crops
MIN_DETECTION_CONFIDENCE = 0.6       # Minimum confidence to consider a hand detected

# --- ADJUST THIS VALUE TO CHANGE THE CAPTURE AREA ---
# Increase this value to capture a larger area around the hand.
# A smaller value creates a tighter crop. 70 is a good starting point for a larger area.
PADDING = 70

def process_video():
    """
    Processes a video to detect hands, crop them with a transparent background,
    and save them as individual PNG files.
    """
    # --- INITIALIZATION ---
    mp_hands = mp.solutions.hands
    hands = mp_hands.Hands(
        static_image_mode=False,
        max_num_hands=2,
        min_detection_confidence=MIN_DETECTION_CONFIDENCE
    )
    mp_drawing = mp.solutions.drawing_utils

    # Create output directory if it doesn't exist
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        print(f"Created directory: {OUTPUT_DIR}")

    # Check if video file exists
    if not os.path.exists(VIDEO_PATH):
        print(f"Error: Video file not found at '{VIDEO_PATH}'")
        return

    cap = cv2.VideoCapture(VIDEO_PATH)
    if not cap.isOpened():
        print("Error: Could not open video.")
        return

    frame_count = 0
    print("Starting video processing with larger padding...")

    # --- MAIN VIDEO PROCESSING LOOP ---
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break  # End of video

        frame_height, frame_width, _ = frame.shape
        frame_count += 1

        # To improve performance, optionally mark the image as not writeable
        frame.flags.writeable = False
        # Convert the BGR image to RGB
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

        # Process the frame and find hands
        results = hands.process(rgb_frame)
        
        frame.flags.writeable = True

        # If hands are detected
        if results.multi_hand_landmarks:
            for hand_id, hand_landmarks in enumerate(results.multi_hand_landmarks):
                
                # --- Create Bounding Box ---
                landmarks = hand_landmarks.landmark
                x_coords = [lm.x for lm in landmarks]
                y_coords = [lm.y for lm in landmarks]
                
                x_min = int(min(x_coords) * frame_width) - PADDING
                y_min = int(min(y_coords) * frame_height) - PADDING
                x_max = int(max(x_coords) * frame_width) + PADDING
                y_max = int(max(y_coords) * frame_height) + PADDING

                # Ensure bounding box is within frame boundaries
                x_min = max(0, x_min)
                y_min = max(0, y_min)
                x_max = min(frame_width, x_max)
                y_max = min(frame_height, y_max)
                
                # --- Crop the Hand from the Original Frame ---
                cropped_hand = frame[y_min:y_max, x_min:x_max]

                if cropped_hand.size == 0:
                    continue

                # --- Create Transparent Background Image ---
                # 1. Create a mask based on the hand landmarks
                mask = np.zeros(cropped_hand.shape[:2], dtype="uint8")
                
                # Get landmarks in pixel coordinates relative to the crop
                points = np.array([[(lm.x * frame_width) - x_min, (lm.y * frame_height) - y_min] for lm in landmarks], dtype=np.int32)
                
                # Create a convex hull around the hand points to form a tight mask
                convex_hull = cv2.convexHull(points)
                cv2.fillConvexPoly(mask, convex_hull, 255)

                # 2. Apply the mask to the cropped hand
                masked_hand = cv2.bitwise_and(cropped_hand, cropped_hand, mask=mask)

                # 3. Create a 4-channel BGRA image (for transparency)
                bgra_hand = cv2.cvtColor(masked_hand, cv2.COLOR_BGR2BGRA)
                
                # Set the alpha channel based on the mask
                bgra_hand[:, :, 3] = mask

                # --- Save the Final Image ---
                output_filename = os.path.join(OUTPUT_DIR, f"frame_{frame_count:04d}_hand_{hand_id}.png")
                cv2.imwrite(output_filename, bgra_hand)

        if frame_count % 30 == 0:
            print(f"Processed {frame_count} frames...")

    # --- CLEANUP ---
    hands.close()
    cap.release()
    print("Video processing complete.")
    print(f"Cropped hand images are saved in the '{OUTPUT_DIR}' folder.")

# --- RUN THE SCRIPT ---
if __name__ == '__main__':
    process_video()