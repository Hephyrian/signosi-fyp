import cv2
import mediapipe as mp
import numpy as np
import os
import argparse

# --- Path-robust defaults ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_VIDEO_PATH = os.path.join(SCRIPT_DIR, "sinhala_alphabet.f605.mp4")
DEFAULT_OUTPUT_DIR = os.path.join(SCRIPT_DIR, "output_signs_large")

def process_video(video_path: str, output_dir: str, min_detection_confidence: float = 0.6, padding: int = 70):
    """
    Processes a video to detect hands, crop them with a transparent background,
    and save them as individual PNG files.
    """
    mp_hands = mp.solutions.hands
    hands = mp_hands.Hands(
        static_image_mode=False,
        max_num_hands=2,
        min_detection_confidence=min_detection_confidence
    )
    mp_drawing = mp.solutions.drawing_utils

    # Create output directory if it doesn't exist
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        print(f"Created directory: {output_dir}")

    # Check if video file exists
    if not os.path.exists(video_path):
        print(f"Error: Video file not found at '{video_path}'")
        return

    cap = cv2.VideoCapture(video_path)
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
                
                x_min = int(min(x_coords) * frame_width) - padding
                y_min = int(min(y_coords) * frame_height) - padding
                x_max = int(max(x_coords) * frame_width) + padding
                y_max = int(max(y_coords) * frame_height) + padding

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
                output_filename = os.path.join(output_dir, f"frame_{frame_count:04d}_hand_{hand_id}.png")
                cv2.imwrite(output_filename, bgra_hand)

        if frame_count % 30 == 0:
            print(f"Processed {frame_count} frames...")

    # --- CLEANUP ---
    hands.close()
    cap.release()
    print("Video processing complete.")
    print(f"Cropped hand images are saved in the '{output_dir}' folder.")

def parse_args():
    parser = argparse.ArgumentParser(description="Process a video to extract hand crops with transparency.")
    parser.add_argument("--video", "-v", default=DEFAULT_VIDEO_PATH, help="Path to input video file")
    parser.add_argument("--out", "-o", default=DEFAULT_OUTPUT_DIR, help="Directory to save output PNGs")
    parser.add_argument("--conf", type=float, default=0.6, help="Min detection confidence for hands")
    parser.add_argument("--pad", type=int, default=70, help="Padding around detected hand bbox")
    return parser.parse_args()

if __name__ == '__main__':
    args = parse_args()
    process_video(args.video, args.out, args.conf, args.pad)


