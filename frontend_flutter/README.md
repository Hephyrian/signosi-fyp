# Signosi - Sign Language Translator App

A Flutter application for translating text to sign language videos or animations.

## Features

- Speech-to-text translation in multiple languages (Sinhala, English, Tamil)
- Sign language video playback
- Clean and modern UI following Material 3 design

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
