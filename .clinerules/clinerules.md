# Project Rules for Signosi

This document outlines the rules and guidelines for maintaining project structure and code quality within the Signosi project, which includes a Python backend and a Flutter frontend.

## General Rules

*   **Consistent Formatting:** All code should be consistently formatted according to the respective language's standard practices and linting rules.
*   **Clear Naming:** Use descriptive and meaningful names for variables, functions, classes, and files.
*   **Documentation:** Document code where necessary, especially for complex logic, functions, and classes.
*   **Version Control:** Follow a consistent Git workflow, including clear commit messages and branching strategies.
*   **Testing:** Write tests for new features and bug fixes to ensure code reliability.

## Project Overview (from Proposal - Development Focus)

This section summarizes key technical information from the "Final year project proposal 10898762 FINAL.pdf" relevant for development.

### Core Goal & Technology
*   **Goal:** Develop an Android app ("Signosi") to convert spoken Sinhala and Tamil into real-time Sri Lankan Sign Language (SLSL) animations.
*   **Tech Stack:**
    *   **Frontend:** Flutter (for cross-platform mobile app)
    *   **Machine Learning (on-device):** TensorFlow Lite (for offline speech recognition and potentially animation logic)
    *   **Local Database:** SQLite
    *   **Speech Input:** Optimized for Sinhala & Tamil, noise cancellation.
    *   **Animation:** 2D animated avatars for SLSL.

### Key Technical Requirements & Constraints

#### Device Requirements (Minimum):
*   **OS:** Android 4.1+
*   **RAM:** 2GB
*   **Storage:** 32GB
*   **Hardware:** Standard microphone, touch screen, internet (for updates), minimum graphics support.

#### Development Requirements:
*   **Frameworks/Libraries:** Flutter, TensorFlow Lite, SQLite.
*   **Capabilities:** Support for animation, efficient local storage, network handling, error logging.

#### Technical Constraints:
*   **Network:** Must function effectively in low bandwidth conditions.
*   **Device Performance:** Manage device-specific constraints (screen sizes, varied hardware configurations) efficiently.
*   **Resource Management:** Optimize memory, storage, and battery usage.
*   **Background Operations:** Manage seamlessly.

## Backend (Python) Rules

*   **Project Structure:**
    *   The main application code should reside within the `backend_python/app.py` file or organized into logical modules within the `backend_python/` directory.
    *   Tests should be placed in the `backend_python/tests/` directory.
*   **Environment Setup:**
    *   Always use a virtual environment. Create one using `python -m venv venv` and activate it (e.g., `source venv/bin/activate` on Linux/macOS or `venv\Scripts\activate` on Windows).
    *   Manage environment variables by creating a `.env` file in the `backend_python` directory (i.e., `backend_python/.env`).
    *   Essential environment variables include:
        *   `GOOGLE_APPLICATION_CREDENTIALS`: Path to your Google Cloud service account JSON file (this key should have permissions for the Speech-to-Text API).
        *   `FLASK_APP`: Should be set to `app.py`.
        *   `FLASK_ENV`: Set to `development` for local development.
        *   `PORT`: (Optional) Defaults to 8080 if not set.
*   **Dependencies:**
    *   Dependencies are managed using `requirements.txt`. Install them using `pip install -r requirements.txt` after activating the virtual environment.
    *   If Poetry is used (indicated by `pyproject.toml` and `poetry.lock`), follow Poetry workflows for dependency management.
    *   Clearly list all dependencies and ensure versions are specified for reproducibility.
*   **Running the Application:**
    *   The application can be run using `flask run` (if `FLASK_APP` is set in the environment).
    *   Alternatively, run directly using `python app.py`.
    *   The backend typically runs on `http://127.0.0.1:8080/` or the port specified in the `.env` file.
*   **Code Quality:**
    *   Adhere to PEP 8 style guidelines.
    *   Use a linter such as Flake8 or Pylint.
    *   Employ a code formatter like Black or autopep8.
    *   Write comprehensive docstrings for all modules, classes, and functions.
*   **Docker Usage:**
    *   To build the Docker image: `docker build -t signosi-backend .` (executed from the `backend_python` directory).
        *   Ensure the `Dockerfile` correctly handles the `GOOGLE_APPLICATION_CREDENTIALS` file (e.g., by copying it during the build or preparing for a volume mount at runtime).
    *   To run the Docker container: `docker run -p 8080:8080 -e PORT=8080 signosi-backend`.
    *   For development, mounting the service account file as a volume is recommended to avoid rebuilding the image for credential changes. Example:
        ```bash
        docker run -p 8080:8080 \
            -v /path/to/your/service-account-file.json:/app/service-account-file.json:ro \
            -e GOOGLE_APPLICATION_CREDENTIALS="/app/service-account-file.json" \
            -e PORT=8080 \
            signosi-backend
        ```
    *   Note: The path `/app/service-account-file.json` inside the container is an example; adjust as per the `Dockerfile` and your mounting strategy. The `:ro` flag makes the volume read-only in the container.

### Sign Language Translator (Python Package)

The `sign-language-translator` Python package is a core component of the backend, enabling translation between sign language and text.

*   **Overview:**
    *   Provides a user-friendly translation API and a framework for building custom sign language translators.
    *   Supports both sign-to-text and text-to-sign conversion.
    *   Aims to bridge the communication gap for the hearing-impaired community.
    *   Can translate full sentences, not just alphabets.
    *   Features an extensible rule-based text-to-sign system for generating training data for Deep Learning models.

*   **Installation:**
    *   Install the package using pip:
        ```bash
        pip install sign-language-translator
        ```
    *   For all optional dependencies (e.g., `mediapipe` for pose extraction, `deep_translator` for synonyms):
        ```bash
        pip install "sign-language-translator[all]"
        ```
    *   Editable mode (if cloned from git):
        ```bash
        git clone https://github.com/sign-language-translator/sign-language-translator.git
        cd sign-language-translator
        pip install -e ".[all]"
        ```

*   **Major Components:**
    *   **Sign language to Text:**
        *   Extracts features from sign language videos (e.g., using MediaPipe 3D landmarks).
        *   Transcribes and translates signs into multiple text languages.
        *   Supports training models for word-for-word gloss writing.
    *   **Text to Sign Language:**
        *   **Rule-Based Concatenation:** Parses input text and plays appropriate video clips for each token based on a mapped dictionary. Requires word sense disambiguation for accuracy.
        *   **Deep Learning (seq2seq):** Can generate sign sequences or synthesize signs directly, handling ambiguous words and out-of-dictionary words.
    *   **Language Processing:**
        *   **Sign Processing:** 3D landmark extraction, pose visualization, pose transformations.
        *   **Text Processing:** Normalization, disambiguation, tokenization, token classification.
    *   **Datasets:**
        *   Relies on datasets including word-level dictionaries, replications, parallel sentences, and grammatical rules. See the `sign-language-datasets` repository for details.

*   **Building a Custom Translator:**
    1.  **Data Collection:** Gather dictionary videos, map them to text, create parallel corpora, and collect sentence videos with translations/glosses.
    2.  **Language Processing:** Subclass `slt.languages.TextLanguage` for text processing and `slt.languages.SignLanguage` for mapping text to sign video filenames and restructuring according to sign language grammar.
    3.  **Rule-Based Translation:** Use `slt.models.ConcatenativeSynthesis` with your custom language classes.
    4.  **Deep Learning Model Fine-Tuning:** Use the generated data to fine-tune models for better accuracy.

*   **Usage Examples:**
    *   **Python:**
        ```python
        import sign_language_translator as slt
        model = slt.models.ConcatenativeSynthesis(
           text_language="urdu", sign_language="pk-sl", sign_format="video"
        )
        text = "یہ بہت اچھا ہے۔"
        sign = model.translate(text)
        sign.show()
        ```
    *   **Command Line:**
        ```bash
        slt translate --model-code rule-based --text-lang urdu --sign-lang pk-sl --sign-format video "your text here"
        ```

*   **Further Information:**
    *   Refer to the official documentation: [slt.readthedocs.io](https://slt.readthedocs.io)
    *   Check the project repository: [github.com/sign-language-translator/sign-language-translator](https://github.com/sign-language-translator/sign-language-translator)

## Frontend (Flutter) Rules

*   **Project Structure:**
    *   The main application code should be in the `frontend_flutter/lib/` directory.
    *   Organize code into logical components and screens.
    *   Assets (images, fonts, etc.) should be placed in appropriate subdirectories within the project.
    *   Tests should be placed in the `frontend_flutter/test/` directory.
*   **Code Quality:**
    *   Adhere to the Dart style guide.
    *   Use the `dart analyze` tool for static analysis.
    *   Use a formatter like `dart format`.
    *   Write comments for complex widgets and logic.
*   **Dependencies:**
    *   Manage dependencies using `pubspec.yaml`.
    *   Specify dependency versions.
