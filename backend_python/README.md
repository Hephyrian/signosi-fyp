# Python Backend for Signosi Speech-to-Text App

This directory contains the Python Flask backend for the Signosi application.

## Setup

1.  **Create a virtual environment (recommended):**
    ```bash
    python -m venv venv
    source venv/bin/activate  # On Windows use `venv\Scripts\activate`
    ```

2.  **Install dependencies:**
    ```bash
    pip install -r requirements.txt
    ```

3.  **Set up Environment Variables:**
    Create a `.env` file in this directory (`backend_python/.env`) with the following content. 
    Replace placeholder values with your actual credentials and paths.

    ```
    GOOGLE_APPLICATION_CREDENTIALS="path/to/your/service-account-file.json"
    FLASK_APP="app.py"
    FLASK_ENV="development"
    # PORT=8080 (Optional, defaults to 8080 if not set)
    ```

    *   `GOOGLE_APPLICATION_CREDENTIALS`: Path to the JSON file containing your Google Cloud service account key. This key should have permissions for the Speech-to-Text API.
    *   `FLASK_APP`: Tells Flask where your application is.
    *   `FLASK_ENV`: Sets the environment (e.g., `development`, `production`).

4.  **Run the application:**
    ```bash
    flask run
    ```
    Or directly:
    ```bash
    python app.py
    ```
    The backend will typically run on `http://127.0.0.1:8080/` (or the port you specified).

## Docker

To build and run the backend using Docker:

1.  **Build the Docker image:**
    Make sure you have your `service-account-file.json` in the `backend_python` directory, or adjust the `Dockerfile` and `ENV GOOGLE_APPLICATION_CREDENTIALS` path accordingly if you plan to mount it as a volume.
    ```bash
    docker build -t signosi-backend .
    ```

2.  **Run the Docker container:**
    If your `service-account-file.json` is in the `backend_python` directory and you want to include it in the image (as per the current Dockerfile `COPY . .` command and `ENV` var):
    ```bash
    docker run -p 8080:8080 -e PORT=8080 signosi-backend
    ```

    Alternatively, to mount the service account file from your host machine (recommended for local development to avoid rebuilding the image for credential changes):
    First, ensure the `GOOGLE_APPLICATION_CREDENTIALS` in your `.env` file (if used by Flask locally) or the `ENV` var in the `Dockerfile` points to where it will be *inside the container* (e.g., `/app/secrets/service-account-file.json`).
    Then, copy your service account file to a known location on your host, for example, `~/.gcp/service-account-file.json`.
    Run the container mounting this file:
    ```bash
    docker run -p 8080:8080 \
        -v ~/.gcp/service-account-file.json:/app/service-account-file.json:ro \
        -e GOOGLE_APPLICATION_CREDENTIALS="/app/service-account-file.json" \
        -e PORT=8080 \
        signosi-backend
    ```
    *(Note: The `:ro` makes the volume read-only in the container, which is good practice for credentials.)*

    Ensure the `GOOGLE_APPLICATION_CREDENTIALS` path in the container matches where you mount the file.

## API Endpoints

(Details to be added as they are implemented)

*   `/`: Health check.
*   `/api/speech-to-text/realtime` (POST): For real-time speech recognition.
*   `/api/speech-to-text/asynchronous` (POST): For asynchronous speech recognition of audio files.
*   `/api/auth/login` (POST): User login.
*   `/api/auth/register` (POST): User registration.
*   `/api/data` (GET, POST): Placeholder for data operations.

# Video Landmark Extraction Script

This script processes video files to extract hand landmarks using MediaPipe and OpenCV.

## Setup

1.  **Create a virtual environment (recommended):**
    ```bash
    python -m venv venv
    source venv/bin/activate  # On Windows: venv\Scripts\activate
    ```

2.  **Install dependencies:**
    Navigate to the `backend_python` directory and run:
    ```bash
    pip install -r requirements.txt
    ```

## Usage

The script is located in `backend_python/scripts/process_videos.py`.

Run the script from the command line, providing the path to an input video file or a directory containing video files, and the path to an output directory where the CSV files will be saved.

**Command:**

```bash
python backend_python/scripts/process_videos.py <input_path> <output_base_directory>
```

**Arguments:**

*   `<input_path>`: Path to a single video file (.mp4, .mov, .avi) or a directory containing video files.
*   `<output_base_directory>`: The base directory where a subfolder named `hand_landmarks_csv` will be created to store the output CSV files. For example, if you provide `backend_python/processed_data`, the CSVs will be saved in `backend_python/processed_data/hand_landmarks_csv/`.

**Examples:**

1.  **Processing a single video file:**
    ```bash
    python backend_python/scripts/process_videos.py backend_python/videos/my_video.mp4 backend_python/processed_data
    ```
    This will create `backend_python/processed_data/hand_landmarks_csv/my_video_hand_landmarks.csv`.

2.  **Processing all videos in a directory:**
    ```bash
    python backend_python/scripts/process_videos.py backend_python/videos/my_video_collection/ backend_python/processed_data
    ```
    This will process all supported video files in `backend_python/videos/my_video_collection/` and save the corresponding CSV files in `backend_python/processed_data/hand_landmarks_csv/`.

## Output

For each processed video, a CSV file is generated in the `<output_base_directory>/hand_landmarks_csv/` directory.

*   **Filename format:** `video_name_hand_landmarks.csv`
*   **CSV Columns:**
    *   `frame_number`: The frame number in the video (0-indexed).
    *   `hand_label`: Label of the hand ('Left' or 'Right', or 'Unknown' if not reliably determined).
    *   `landmark_index`: Index of the landmark (0-20) as defined by MediaPipe Hands.
    *   `x`: Normalized x-coordinate of the landmark.
    *   `y`: Normalized y-coordinate of the landmark.
    *   `z`: Normalized z-coordinate of the landmark (depth from the camera).
    *   `visibility`: Visibility of the landmark (a value typically between 0.0 and 1.0).

## Error Handling and Logging

*   The script includes basic error handling for file I/O and video processing.
*   Progress and error messages are logged to the console. 