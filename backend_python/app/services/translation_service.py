import os
import sys
import logging
import json # For loading custom mapping
import traceback # For detailed error logging
import boto3 # Added for S3 integration
from botocore.exceptions import NoCredentialsError, ClientError # Added for S3 error handling

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
    # from sign_language_translator.models.video_embedding.mediapipe_landmarks_model import MediaPipeLandmarksModel

except ImportError as e:
    logging.error(f"Error importing sign_language_translator or its components: {e}")
    logging.error(f"Ensure sign-language-translator is in PYTHONPATH or installed. Current sys.path: {sys.path}")
    slt_models = None # So app can check and fail gracefully

# === S3 Configuration ===
AWS_S3_BUCKET_NAME = os.environ.get('AWS_S3_BUCKET_NAME')
AWS_ACCESS_KEY_ID = os.environ.get('AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY = os.environ.get('AWS_SECRET_ACCESS_KEY')
AWS_S3_REGION = os.environ.get('AWS_S3_REGION')

s3_client = None
if AWS_S3_BUCKET_NAME and AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY and AWS_S3_REGION:
    try:
        s3_client = boto3.client(
            's3',
            aws_access_key_id=AWS_ACCESS_KEY_ID,
            aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
            region_name=AWS_S3_REGION
        )
        logging.info(f"S3 client initialized for bucket '{AWS_S3_BUCKET_NAME}' in region '{AWS_S3_REGION}'.")
    except Exception as e:
        logging.error(f"Failed to initialize S3 client: {e}", exc_info=True)
        s3_client = None
else:
    logging.warning("S3 credentials/bucket name/region not fully configured in environment variables. S3 features will be disabled.")

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
        
        if not s3_client:
            logging.error("CustomSinhalaConcatenativeSynthesis: S3 client not initialized. Cannot fetch from S3. Falling back to superclass.")
            return super()._prepare_resource_name(label, person, camera, sep)

        if not isinstance(_custom_lk_mapping_data, dict) or not _custom_lk_mapping_data:
            logging.error("CustomSinhalaConcatenativeSynthesis: Custom mapping data not loaded or empty. Falling back to superclass.")
            return super()._prepare_resource_name(label, person, camera, sep)

        if label in _custom_lk_mapping_data:
            entry = _custom_lk_mapping_data[label]
            s3_object_key = entry.get("media_path") # Assuming media_path is now the S3 object key

            if s3_object_key:
                # Ensure the key uses forward slashes, common for S3
                s3_object_key = s3_object_key.replace("\\\\", "/")
                
                try:
                    presigned_url = s3_client.generate_presigned_url(
                        'get_object',
                        Params={'Bucket': AWS_S3_BUCKET_NAME, 'Key': s3_object_key},
                        ExpiresIn=30  # URL expires in 30 seconds
                    )
                    logging.info(f"CustomSinhalaConcatenativeSynthesis: Generated pre-signed URL for S3 object key '{s3_object_key}': '{presigned_url}'")
                    return presigned_url
                except NoCredentialsError:
                    logging.error("CustomSinhalaConcatenativeSynthesis: AWS credentials not found. Cannot generate pre-signed URL.")
                except ClientError as e:
                    logging.error(f"CustomSinhalaConcatenativeSynthesis: Error generating pre-signed URL for S3 object key '{s3_object_key}': {e}", exc_info=True)
                except Exception as e:
                    logging.error(f"CustomSinhalaConcatenativeSynthesis: Unexpected error generating pre-signed URL for S3 object key '{s3_object_key}': {e}", exc_info=True)
                
                # Fallback if URL generation fails
                logging.warning(f"CustomSinhalaConcatenativeSynthesis: Failed to generate pre-signed URL for S3 object key '{s3_object_key}'. Falling back.")
            else:
                logging.warning(f"CustomSinhalaConcatenativeSynthesis: 'media_path' (S3 object key) not found for sign_id '{label}' in custom mapping. Falling back.")
        else:
            logging.warning(f"CustomSinhalaConcatenativeSynthesis: Sign_id '{label}' not found in custom mapping. Falling back.")

        return super()._prepare_resource_name(label, person, camera, sep)

    def _map_labels_to_sign(self, video_labels: list[str], person=None, camera=None, sep="_") -> list[str]:
        """
        Overrides the parent method to prevent local file validation on S3 URLs.
        It calls our custom _prepare_resource_name for each label (which generates S3 URLs)
        and returns the list of these URLs (or fallback paths).
        """
        logging.debug(f"CustomSinhalaConcatenativeSynthesis._map_labels_to_sign called with labels: {video_labels}")
        resource_paths_or_urls = []
        if not video_labels:
            logging.debug("CustomSinhalaConcatenativeSynthesis._map_labels_to_sign: Received empty video_labels list.")
            return []

        for label_to_map in video_labels:
            # Our _prepare_resource_name method already handles S3 URL generation or fallback.
            path_or_url = self._prepare_resource_name(label_to_map, person, camera, sep)
            if path_or_url:
                resource_paths_or_urls.append(path_or_url)
                logging.debug(f"CustomSinhalaConcatenativeSynthesis._map_labels_to_sign: Added '{path_or_url}' for label '{label_to_map}'")
            else:
                # This case should ideally be handled within _prepare_resource_name's fallback or logging.
                logging.warning(f"CustomSinhalaConcatenativeSynthesis._map_labels_to_sign: _prepare_resource_name returned None for label '{label_to_map}'. Skipping.")
        
        logging.debug(f"CustomSinhalaConcatenativeSynthesis._map_labels_to_sign: Returning resource_paths_or_urls: {resource_paths_or_urls}")
        return resource_paths_or_urls

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
                text_language=SinhalaTextLanguage(), # Corrected NameError
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
        logging.debug(f"Input text type: {type(text)}, value (service level): '{text}'")

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
