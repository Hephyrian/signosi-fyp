import cv2
import mediapipe as mp
import os
import argparse
import logging
import pandas as pd

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Initialize MediaPipe Hands
mp_hands = mp.solutions.hands
hands = mp_hands.Hands(static_image_mode=False,
                       max_num_hands=2,
                       min_detection_confidence=0.5,
                       min_tracking_confidence=0.5)
mp_drawing = mp.solutions.drawing_utils

def process_video(video_path, output_dir):
    """
    Processes a single video file to extract hand landmarks.

    Args:
        video_path (str): Path to the video file.
        output_dir (str): Directory to save the output CSV file.
    """
    video_name = os.path.splitext(os.path.basename(video_path))[0]
    output_csv_path = os.path.join(output_dir, f"{video_name}_hand_landmarks.csv")

    if not os.path.exists(video_path):
        logging.error(f"Video file not found: {video_path}")
        return

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        logging.error(f"Error opening video file: {video_path}")
        return

    landmarks_data = []
    frame_number = 0

    logging.info(f"Processing video: {video_path}")

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        # Convert the BGR image to RGB
        image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        image_rgb.flags.writeable = False # To improve performance

        # Process the image and find hands
        results = hands.process(image_rgb)

        image_rgb.flags.writeable = True # To draw annotations
        # image = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2BGR) # If you want to draw

        if results.multi_hand_landmarks:
            for hand_index, hand_landmarks in enumerate(results.multi_hand_landmarks):
                # Determine hand label (Left/Right)
                #handedness_list = results.multi_handedness[hand_index].classification
                #hand_label = handedness_list[0].label # 'Left' or 'Right'
                
                # Sometimes handedness is not perfectly reliable or might be missing in some versions/configurations
                # For simplicity, let's try to infer based on landmark positions or use a generic label if needed.
                # For this example, we'll use the index if label is tricky.
                # A more robust way might involve checking the handedness score or specific landmark patterns.
                hand_label = "Unknown"
                if results.multi_handedness and len(results.multi_handedness) > hand_index:
                    hand_label = results.multi_handedness[hand_index].classification[0].label


                for landmark_index, landmark in enumerate(hand_landmarks.landmark):
                    landmarks_data.append({
                        'frame_number': frame_number,
                        'hand_label': hand_label,
                        'landmark_index': landmark_index,
                        'x': landmark.x,
                        'y': landmark.y,
                        'z': landmark.z,
                        'visibility': landmark.visibility if hasattr(landmark, 'visibility') else None
                    })
        
        frame_number += 1

    cap.release()

    if landmarks_data:
        df = pd.DataFrame(landmarks_data)
        os.makedirs(output_dir, exist_ok=True)
        df.to_csv(output_csv_path, index=False)
        logging.info(f"Saved landmarks for {video_name} to {output_csv_path}")
    else:
        logging.info(f"No landmarks detected in {video_name}")

def main():
    parser = argparse.ArgumentParser(description="Extract hand landmarks from videos.")
    parser.add_argument("input_path", help="Path to a single video file or a directory of videos.")
    parser.add_argument("output_dir", help="Directory to save the output CSV files.")

    args = parser.parse_args()

    input_path = args.input_path
    base_output_dir_from_arg = args.output_dir # Renamed for clarity

    # Create the specific base subdirectory for all hand landmarks CSVs
    # This is where all CSVs (potentially in their own subfolders) will reside.
    hand_landmarks_base_output_dir = os.path.join(base_output_dir_from_arg, "hand_landmarks_csv")
    os.makedirs(hand_landmarks_base_output_dir, exist_ok=True)


    if not os.path.exists(input_path):
        logging.error(f"Input path does not exist: {input_path}")
        return

    if os.path.isfile(input_path):
        if input_path.lower().endswith(('.mp4', '.mov', '.avi')):
            # For a single file, CSV goes directly into the hand_landmarks_base_output_dir
            process_video(input_path, hand_landmarks_base_output_dir)
        else:
            logging.error(f"Unsupported file format: {input_path}. Please provide .mp4, .mov, or .avi files.")
    elif os.path.isdir(input_path):
        logging.info(f"Processing videos in directory (and subdirectories): {input_path}")
        for dirpath, _, filenames in os.walk(input_path):
            for filename in filenames:
                if filename.lower().endswith(('.mp4', '.mov', '.avi')):
                    video_file_full_path = os.path.join(dirpath, filename)
                    
                    # Determine the relative path of the current directory (dirpath)
                    # with respect to the initial input_path.
                    # This relative structure will be replicated in the output.
                    relative_subdir_structure = os.path.relpath(dirpath, input_path)
                    
                    # Construct the target output directory for this specific video's CSV.
                    # It combines the hand_landmarks_base_output_dir with the relative_subdir_structure.
                    if relative_subdir_structure == '.':
                        # Video is in the root of input_path, so CSV goes into hand_landmarks_base_output_dir
                        target_csv_output_dir_for_video = hand_landmarks_base_output_dir
                    else:
                        target_csv_output_dir_for_video = os.path.join(hand_landmarks_base_output_dir, relative_subdir_structure)
                    
                    # process_video will create target_csv_output_dir_for_video if it doesn't exist
                    # and save the CSV there.
                    process_video(video_file_full_path, target_csv_output_dir_for_video)
                else:
                    # Log only if it's not a hidden file or common non-video file type to reduce noise
                    if not filename.startswith('.') and not filename.lower().endswith(('.txt', '.csv', '.log', '.md', '.json', '.xml')):
                         logging.warning(f"Skipping unsupported file: {filename} in {dirpath}")
    else:
        logging.error(f"Invalid input path: {input_path}. Must be a file or directory.")

if __name__ == "__main__":
    main() 