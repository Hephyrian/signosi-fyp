# Signosi - Sign Language Translator App

A Flutter application for translating text to sign language videos or animations.

## Features

- Speech-to-text translation in multiple languages (Sinhala, English, Tamil)
- Sign language video playback
- Clean and modern UI following Material 3 design
- Single-letter fallback (Sinhala): if a word has no direct sign, the app renders per-letter landmark animations using only MAIN letters (base consonants and independent vowels)

## Setup

1. Ensure you have Flutter installed (Flutter 3.x or higher recommended)
2. Clone this repository
3. Create a `.env` file in the root directory with the following content:
```
BACKEND_URL=http://127.0.0.1:8080
ANIMATION_FPS=30
DEFAULT_LANGUAGE=si
```
4. Run `flutter pub get` to install dependencies
5. Make sure the backend server is running at the specified URL

## Configuration

The `.env` file contains the following settings:
- `BACKEND_URL`: The URL of the backend API server
- `ANIMATION_FPS`: Frames per second for landmark animations (if used)
- `DEFAULT_LANGUAGE`: Default language code (si=Sinhala, en=English, ta=Tamil)

## Running the Application

```bash
# Ensure the backend is running first
cd frontend_flutter
flutter run
```

## Testing with Mock Data

For testing without a backend:
1. Make sure you have sign language video files available
2. Update the translation service to use local files for testing

## Project Structure

- `/lib`: Main source code
  - `/controllers`: State management controllers
  - `/models`: Data models
  - `/screens`: App screens
  - `/services`: API and other services
  - `/widgets`: Reusable UI components
- `/assets`: Static assets like images

## Dependencies

- flutter_dotenv: Environment variable management
- video_player: Video playback
- speech_to_text: Speech recognition
- http: API requests
- provider: State management

## Single-Letter Recognition (Sinhala)

When the backend falls back to per-letter signs (Sinhala), each sign item in the response can include landmark data or a URL to fetch it. The Flutter app supports two cases via `Sign` model in `lib/models/translation_response.dart`:

- `landmarkData`: Inline list-of-frames of landmark coordinates
- `landmarkPath`: A URL or file path to a JSON with frames to be fetched

Rendering is handled by `lib/widgets/landmark_painter.dart` which draws a stylized hand from MediaPipe-style landmark frames. The painter accepts:

- `numberOfPoseLandmarks`: set to 0 for letter-only data
- `numberOfHandLandmarks`: 21 for MediaPipe Hands
- `numberOfHands`: 1 by default
- `isWorldLandmarks`: whether values are world or image coordinates
- `drawStylizedHands`: enables improved visual rendering of fingers and palm

Expected backend response for fallback (example):

```json
{
  "signs": [
    { "label": "letter_ක", "landmark_data": "https://.../ක.json", "media_type": "landmarks" },
    { "label": "letter_අ", "landmark_data": "https://.../අ.json", "media_type": "landmarks" }
  ]
}
```

Frontend parsing logic lives in `lib/services/translation_service.dart` and `lib/models/translation_response.dart`:

- The service posts to `POST /api/translate/text-to-slsl` with `{ text, source_language, target_language }`
- The model supports `videoPath`, `animationPath`, and `landmarkData` or `landmarkPath`

Normalization rule (important): The backend sends only base consonants and independent vowels for fallback; vowel modifiers and virama are not emitted as separate letters.

Tips:

- Ensure `BACKEND_URL` points to your running backend, e.g. `http://127.0.0.1:8080`
- If the backend serves pre-signed S3 URLs for `landmark_data`, the app will fetch and render them
- Use `ANIMATION_FPS` to tune playback smoothness
