import os
import sys
import logging
import json # For loading custom mapping
import traceback # For detailed error logging

# Define paths first
PACKAGE_PARENT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')) # .../signosi-fyp/backend_python
PROJECT_ROOT_DIR = os.path.abspath(os.path.join(PACKAGE_PARENT_DIR, '..')) # .../signosi-fyp
SLT_PACKAGE_ROOT_DIR = os.path.join(PACKAGE_PARENT_DIR, "sign-language-translator")

# Configure logging
LOG_FILE = os.path.join(PACKAGE_PARENT_DIR, 'initialization.log')
logging.basicConfig(level=logging.DEBUG, # Changed level to DEBUG
                    format='%(asctime)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s', # Added filename and lineno
                    handlers=[
                        logging.FileHandler(LOG_FILE),
                        logging.StreamHandler() # Also print to console
                    ])

# Adjust sys.path if necessary (similar to test_sinhala_loading.py)
# This ensures the local package is found if not installed globally in the venv
# This might be needed if you run flask run from backend_python/
# and the sign-language-translator is a sub-directory not installed in editable mode.
if SLT_PACKAGE_ROOT_DIR not in sys.path:
    sys.path.insert(0, SLT_PACKAGE_ROOT_DIR)

try:
    # Core models and config
    import sign_language_translator.models as slt_models
    from sign_language_translator.config import settings as slt_settings
    from sign_language_translator.config.assets import Assets
    from sign_language_translator.config.enums import SignFormats
    
    # Language implementations
    from sign_language_translator.languages.sign.sinhala_sign_language import SinhalaSignLanguage
    from sign_language_translator.languages.text.sinhala_text_language import SinhalaTextLanguage
    
    # Vision and landmarks
    from sign_language_translator.vision.video.video import Video
    from sign_language_translator.vision.landmarks.landmarks import Landmarks
    from sign_language_translator.models.video_embedding.mediapipe_landmarks_model import MediaPipeLandmarksModel

except ImportError as e:
    logging.error(f"Error importing sign_language_translator or its components: {e}")
    logging.error(f"Ensure sign-language-translator is in PYTHONPATH or installed. Current sys.path: {sys.path}")
    slt_models = None # So app can check and fail gracefully

# === Custom video path logic for lk-custom dataset ===
_custom_lk_mapping_data = None # Store the loaded JSON data

def _load_lk_custom_mapping_data_once():
    global _custom_lk_mapping_data
    if _custom_lk_mapping_data is None: # Load only once
        try:
            mapping_path = os.path.join(Assets.ROOT_DIR, "lk-dictionary-mapping.json") # Use Assets.ROOT_DIR
            if os.path.exists(mapping_path):
                try:
                    with open(mapping_path, "r", encoding="utf-8") as f:
                        _custom_lk_mapping_data = json.load(f)
                    logging.info(f"Successfully loaded lk-dictionary-mapping.json for custom video path function.")
                except Exception as e:
                    _custom_lk_mapping_data = {} # Ensure it's a dict on error
                    logging.error(f"Failed to load or parse lk-dictionary-mapping.json for custom video path function: {e}", exc_info=True)
            else:
                _custom_lk_mapping_data = {} # Ensure it's a dict if file not found
                logging.warning(f"lk-dictionary-mapping.json not found at {mapping_path} for custom video path function.")
        except (NameError, AttributeError):
            logging.error("Assets class not available for loading custom mapping.")
            _custom_lk_mapping_data = {}
            return

try:
    _load_lk_custom_mapping_data_once() # Attempt to load when the module is imported
except (NameError, AttributeError):
    logging.error("Assets class not imported, cannot load custom mapping for video paths.")
    _custom_lk_mapping_data = {}

# Custom ConcatenativeSynthesis model for Sinhala SLSL
class CustomSinhalaConcatenativeSynthesis(slt_models.ConcatenativeSynthesis if slt_models else object):
    def _prepare_resource_name(self, label: str, person=None, camera=None, sep="_") -> str:
        logging.debug(f"CustomSinhalaConcatenativeSynthesis._prepare_resource_name called with label: '{label}'")
        # 'label' is the sign_id from SinhalaSignLanguage, e.g., "lk-custom-S0001_Potha"
        
        if not isinstance(_custom_lk_mapping_data, dict) or not _custom_lk_mapping_data:
            logging.error("CustomSinhalaConcatenativeSynthesis: Custom mapping data not loaded or empty. Falling back to superclass.")
            return super()._prepare_resource_name(label, person, camera, sep)

        if label in _custom_lk_mapping_data:
            entry = _custom_lk_mapping_data[label]
            
            # Directly use "media_path" from the custom mapping
            relative_media_path = entry.get("media_path")

            if relative_media_path:
                # Ensure the path uses forward slashes, as expected by the Assets system
                # (though it should already be in this format if populate_lk_custom_mapping.py is correct)
                relative_media_path = relative_media_path.replace("\\", "/")
                # Handle folder names with dots by extracting the correct folder from the sign ID if needed
                if label.startswith("lk-custom-") and "_" in label:
                    sign_part = label.split("_")[-1] if "_" in label else label
                    if "." in sign_part:
                        # Extract the intended folder name from the sign ID or mapping
                        folder_name = sign_part.replace(".", ". ")
                        # Adjust the path to include the dot in the folder name
                        path_parts = relative_media_path.split("/")
                        if path_parts[-1].startswith(folder_name.split(".")[0]):
                            path_parts[-2] = folder_name
                            relative_media_path = "/".join(path_parts[:-1]) + "/" + path_parts[-1].replace(folder_name.split(".")[0], folder_name)
                # Convert to absolute path relative to the project root (PACKAGE_PARENT_DIR)
                # Assuming relative_media_path starts like 'backend_python/...'
                # We need the path relative to the script's execution context (likely backend_python/)
                # Let's construct the absolute path carefully.
                # Assuming relative_media_path is like 'backend_python/sign-language-translator/...'
                # And PACKAGE_PARENT_DIR is 'c:/.../signosi-fyp'
                # We need 'c:/.../signosi-fyp/backend_python/sign-language-translator/...'
                # os.path.abspath() might resolve relative to the CWD (backend_python), so joining with PACKAGE_PARENT_DIR is safer.
                # However, the relative path already includes 'backend_python', so joining might duplicate it.
                # Construct the absolute path by joining the project root (PACKAGE_PARENT_DIR)
                # with the relative path from the mapping file. Use PROJECT_ROOT_DIR as the base.
                logging.debug(f"CustomSinhalaConcatenativeSynthesis: Preparing to join: PROJECT_ROOT_DIR='{PROJECT_ROOT_DIR}', relative_media_path='{relative_media_path}'") # Changed log variable name
                absolute_media_path = os.path.join(PROJECT_ROOT_DIR, relative_media_path) # Use PROJECT_ROOT_DIR
                # Normalize the path (e.g., handle mixed slashes if any, resolve '..')
                absolute_media_path = os.path.normpath(absolute_media_path)
                logging.debug(f"CustomSinhalaConcatenativeSynthesis: Result of join and normpath: '{absolute_media_path}'") # Added log

                logging.info(f"CustomSinhalaConcatenativeSynthesis: Using absolute media_path for sign_id '{label}': '{absolute_media_path}'")
                return absolute_media_path
            else:
                logging.warning(f"CustomSinhalaConcatenativeSynthesis: 'media_path' not found for sign_id '{label}' in custom mapping. Falling back.")
        else:
            logging.warning(f"CustomSinhalaConcatenativeSynthesis: Sign_id '{label}' not found in custom mapping. Falling back.")

        return super()._prepare_resource_name(label, person, camera, sep)

# Initialize models for different input languages
# We create them once to be reused across requests.
models = {}
if slt_models:
    try:
        sinhala_text_processor = SinhalaTextLanguage() # Instantiate custom Sinhala processor
        sinhala_sign_language = SinhalaSignLanguage()
        logging.info("Initialized SinhalaTextLanguage and SinhalaSignLanguage instances.")
        # Model for Sinhala text to Sinhala Sign Language
        try:
            logging.info("Attempting to initialize Sinhala model (si_to_sinhala-sl) using CustomSinhalaConcatenativeSynthesis...")
            models["si_to_sinhala-sl"] = CustomSinhalaConcatenativeSynthesis( # Use the custom class
                text_language="si",
                sign_language=sinhala_sign_language,
                sign_format="video",  # Using video format
            )
            logging.info("Sinhala model (custom) initialized successfully with video output.")
        except Exception as te:
            logging.error(f"Error initializing custom Sinhala model for video: {te}. Skipping this model.", exc_info=True)

        # Model for English text to Sinhala Sign Language (Temporarily Disabled due to Vocab loading error)
        try:
            logging.info("Attempting to initialize English model (en_to_sinhala-sl)...")
            models["en_to_sinhala-sl"] = slt_models.ConcatenativeSynthesis(
                text_language="en",
                sign_language=sinhala_sign_language,
                sign_format="video"
            )
            logging.info("English model initialized successfully.")
        except Exception as te:
            logging.error(f"Error initializing English model: {te}. Skipping this model.", exc_info=True)

        if models:
            logging.info("Some sign language translation models initialized successfully.")
        else:
            logging.warning("No models could be initialized.")
    except Exception as e:
        logging.error(f"General error initializing translation models: {e}", exc_info=True)
        models = {} # Ensure it's empty on failure

def translate_text_to_slsl(text, source_language_code="si"):
    """
    Translates text from the given source language to Sinhala Sign Language.
    Args:
        text (str): The text to translate.
        source_language_code (str): 'si' for Sinhala, 'en' for English.
                                     Support for 'ta' (Tamil) can be added.
    Returns:
        dict: A dictionary containing a list of sign dictionaries (with media_path, etc.)
              or an error message.
    """
    if not slt_models or not models:
        return {"error": "Translation service not available."}

    model_key = f"{source_language_code}_to_sinhala-sl"
    if model_key not in models:
        logging.warning(f"Translation model for '{source_language_code}' to 'sinhala-sl' not available.")
        return {"error": f"Translation model for '{source_language_code}' to 'sinhala-sl' not available."}

    model = models[model_key]
    try:
        logging.info(f"Attempting translation for text: '{text}' using model: {model_key}")
        logging.debug(f"Model instance: {model}")
        logging.debug(f"Input text type: {type(text)}, value: {text}")

        # === Call the core translation method ===
        # This returns either a Landmarks object or a list of video paths
        result = model.translate(text)
        # =======================================

        logging.info(f"Translation call completed. Output type: {type(result)}")
        logging.debug(f"Raw result object: {result}")

        # Check if the result is a Landmarks object or a list of video paths
        if isinstance(result, Landmarks):  # Use the imported Landmarks class
            logging.info(f"Translation successful. Received Landmarks object with shape: {result.tensor.shape}")
            # Convert tensor to a list of lists for JSON serialization
            landmark_data = result.tensor.numpy().tolist()
            logging.debug(f"Landmark data list (first frame): {landmark_data[0] if landmark_data else 'No frames'}")
            return {"landmark_data": landmark_data}
        elif isinstance(result, list) and all(isinstance(item, str) for item in result):
            # Handle the case where we get a list of video file paths
            logging.info(f"Translation successful. Received list of {len(result)} video paths.")
            # Return the video paths
            return {"signs": [{"media_path": path} for path in result]}
        else:
            logging.error(f"Translation returned unexpected result type: {type(result)}")
            return {"error": "Translation failed to produce expected output format."}

    except Exception as e:
        logging.error(f"Exception during translation for text '{text}': {e}", exc_info=True)
        return {"error": f"Translation failed: {str(e)}"}
