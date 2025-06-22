import os
import sys
import logging
import json # For loading custom mapping
import traceback # For detailed error logging
import boto3 # Added for S3 integration
from botocore.exceptions import NoCredentialsError, ClientError # Added for S3 error handling
import random

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

# Adjust sys.path if necessary
if SLT_PACKAGE_ROOT_DIR not in sys.path:
    sys.path.insert(0, SLT_PACKAGE_ROOT_DIR)

try:
    # Core models and config
    import sign_language_translator.models as slt_models
    from sign_language_translator.config.assets import Assets
    from sign_language_translator.languages.sign.sinhala_sign_language import SinhalaSignLanguage
    from sign_language_translator.languages.text.sinhala_text_language import SinhalaTextLanguage
    from sign_language_translator.vision.landmarks.landmarks import Landmarks

except ImportError as e:
    logging.error(f"Error importing sign_language_translator or its components: {e}")
    slt_models = None

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
_custom_lk_mapping_data = None

def _load_lk_custom_mapping_data_once():
    global _custom_lk_mapping_data
    if _custom_lk_mapping_data is None:
        try:
            mapping_path = os.path.join(Assets.ROOT_DIR, "lk-dictionary-mapping.json")
            if os.path.exists(mapping_path):
                with open(mapping_path, "r", encoding="utf-8") as f:
                    _custom_lk_mapping_data = json.load(f)
                logging.info("Successfully loaded lk-dictionary-mapping.json.")
            else:
                _custom_lk_mapping_data = {}
                logging.warning(f"lk-dictionary-mapping.json not found at {mapping_path}.")
        except (NameError, AttributeError):
            logging.error("Assets class not available for loading custom mapping.")
            _custom_lk_mapping_data = {}

_load_lk_custom_mapping_data_once()

# Custom ConcatenativeSynthesis model for Sinhala SLSL
class CustomSinhalaConcatenativeSynthesis(slt_models.ConcatenativeSynthesis if slt_models else object):
    def _get_available_formats(self, label: str) -> dict:
        """
        For a given sign label, find all available media formats (video, animation, etc.)
        and return a dictionary containing their paths or data.
        """
        resource_info = {
            "label": label,
            "video_path": None,
            "animation_path": None,
            "landmark_data": None,
        }

        if isinstance(_custom_lk_mapping_data, dict) and label in _custom_lk_mapping_data:
            entry = _custom_lk_mapping_data[label]

            # Get Video Path from S3
            video_s3_key = entry.get("video_path")
            if video_s3_key and s3_client:
                try:
                    resource_info["video_path"] = s3_client.generate_presigned_url(
                        'get_object', Params={'Bucket': AWS_S3_BUCKET_NAME, 'Key': video_s3_key}, ExpiresIn=3600
                    )
                except Exception as e:
                    logging.error(f"Failed to generate pre-signed URL for video '{video_s3_key}': {e}")

            # Get Animation Path from S3
            animation_s3_key = entry.get("animation_path")
            if animation_s3_key and s3_client:
                 try:
                    resource_info["animation_path"] = s3_client.generate_presigned_url(
                        'get_object', Params={'Bucket': AWS_S3_BUCKET_NAME, 'Key': animation_s3_key}, ExpiresIn=3600
                    )
                 except Exception as e:
                    logging.error(f"Failed to generate pre-signed URL for animation '{animation_s3_key}': {e}")
            
            # Get Landmark Data
            resource_info["landmark_data"] = entry.get("landmark_data")

        else:
            logging.warning(f"Sign '{label}' not found in custom lk-dictionary-mapping.json.")

        return resource_info

    def _map_labels_to_sign(self, video_labels: list[str], person=None, camera=None, sep="_") -> list[dict]:
        """
        Overrides the parent method to call _get_available_formats for each label.
        """
        sign_resources_info = [self._get_available_formats(label) for label in video_labels]
        logging.debug(f"Returning full sign resources: {sign_resources_info}")
        return sign_resources_info

# Initialize models
models = {}
if slt_models:
    try:
        models["si_to_sinhala-sl"] = CustomSinhalaConcatenativeSynthesis(
            text_language=SinhalaTextLanguage(),
            sign_language=SinhalaSignLanguage(),
            sign_format="video",
        )
        logging.info("Sinhala model (custom) initialized successfully.")
    except Exception as e:
        logging.error(f"Error initializing custom Sinhala model: {e}", exc_info=True)

def translate_text_to_slsl(text, source_language_code="si"):
    """
    Translates text to Sinhala Sign Language, returning all available media formats for each sign.
    """
    if not models:
        return {"error": "Translation service not available."}

    model_key = f"{source_language_code}_to_sinhala-sl"
    if model_key not in models:
        return {"error": f"Translation model for '{source_language_code}' not available."}

    model = models[model_key]
    try:
        signs_data = model(text)
        return {"signs": signs_data}
    except Exception as e:
        tb_str = traceback.format_exc()
        logging.error(f"An error occurred during translation for text '{text}': {e}\n{tb_str}")
        return {"error": "Failed to translate text.", "details": str(e)}
