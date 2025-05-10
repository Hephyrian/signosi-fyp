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