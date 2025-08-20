import os
import sys
import logging
import json # For loading custom mapping
import traceback # For detailed error logging
import boto3 # Added for S3 integration
from botocore.exceptions import NoCredentialsError, ClientError # Added for S3 error handling
import random
import urllib.parse # For URL encoding Unicode characters

# Import letter mapping service
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..'))
from letter_mapping_service import get_letter_mapping_service

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

SLT_IMPORT_ERROR: str | None = None
try:
    # Core models and config
    import sign_language_translator.models as slt_models
    from sign_language_translator.config.assets import Assets
    from sign_language_translator.languages.sign.sinhala_sign_language import SinhalaSignLanguage
    from sign_language_translator.languages.text.sinhala_text_language import SinhalaTextLanguage
    from sign_language_translator.vision.landmarks.landmarks import Landmarks

except ImportError as e:
    SLT_IMPORT_ERROR = str(e)
    logging.error(f"Error importing sign_language_translator or its components: {e}")
    slt_models = None

# === S3 Configuration ===
AWS_S3_BUCKET_NAME = os.environ.get('AWS_S3_BUCKET_NAME')
AWS_ACCESS_KEY_ID = os.environ.get('AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY = os.environ.get('AWS_SECRET_ACCESS_KEY')
AWS_S3_REGION = os.environ.get('AWS_S3_REGION')

s3_client = None
S3_INIT_ERROR: str | None = None
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
        S3_INIT_ERROR = str(e)
        logging.error(f"Failed to initialize S3 client: {e}", exc_info=True)
        s3_client = None
else:
    logging.warning("S3 credentials/bucket name/region not fully configured in environment variables. S3 features will be disabled.")

# === Sinhala combining marks for override heuristics ===
SINHALA_COMBINING_MARKS_SET = set([
    'ා','ැ','ෑ','ි','ී','ු','ූ','ෘ','ෙ','ේ','ෛ','ො','ෝ','ෞ','ෲ','්'
])

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
    def _get_available_formats(self, label: str, request_id: str = "UNKNOWN") -> dict:
        """
        For a given sign label, find all available media formats (video, animation, etc.)
        and return a dictionary containing their paths or data.
        """
        logging.debug(f"🔍 [{request_id}] Looking up resources for sign: '{label}'")
        
        resource_info = {
            "label": label,
            "video_path": None,
            "animation_path": None,
            "landmark_data": None,
        }

        if isinstance(_custom_lk_mapping_data, dict) and label in _custom_lk_mapping_data:
            entry = _custom_lk_mapping_data[label]
            logging.debug(f"📚 [{request_id}] Found entry for '{label}' in dictionary")

            # Get Video Path from S3
            video_s3_key = entry.get("video_path")
            if video_s3_key and s3_client:
                try:
                    logging.debug(f"🎥 [{request_id}] Generating S3 URL for video: {video_s3_key}")
                    resource_info["video_path"] = s3_client.generate_presigned_url(
                        'get_object', Params={'Bucket': AWS_S3_BUCKET_NAME, 'Key': video_s3_key}, ExpiresIn=3600
                    )
                    logging.debug(f"✅ [{request_id}] Video URL generated successfully")
                except Exception as e:
                    logging.error(f"❌ [{request_id}] Failed to generate pre-signed URL for video '{video_s3_key}': {e}")

            # Get Animation Path from S3
            animation_s3_key = entry.get("animation_path")
            if animation_s3_key and s3_client:
                 try:
                    logging.debug(f"🎬 [{request_id}] Generating S3 URL for animation: {animation_s3_key}")
                    resource_info["animation_path"] = s3_client.generate_presigned_url(
                        'get_object', Params={'Bucket': AWS_S3_BUCKET_NAME, 'Key': animation_s3_key}, ExpiresIn=3600
                    )
                    logging.debug(f"✅ [{request_id}] Animation URL generated successfully")
                 except Exception as e:
                    logging.error(f"❌ [{request_id}] Failed to generate pre-signed URL for animation '{animation_s3_key}': {e}")
            
            # Get Landmark Data from S3
            landmark_s3_key = entry.get("landmark_data")
            if landmark_s3_key and s3_client:
                try:
                    logging.debug(f"📊 [{request_id}] Generating S3 URL for landmark data: {landmark_s3_key}")
                    logging.debug(f"📊 [{request_id}] S3 Key details - Type: {type(landmark_s3_key)}, Value: {repr(landmark_s3_key)}")
                    
                    # Log the exact parameters being sent to AWS
                    s3_params = {'Bucket': AWS_S3_BUCKET_NAME, 'Key': landmark_s3_key}
                    logging.debug(f"📊 [{request_id}] S3 Params: {s3_params}")
                    
                    resource_info["landmark_data"] = s3_client.generate_presigned_url(
                        'get_object', 
                        Params=s3_params, 
                        ExpiresIn=3600
                    )
                    logging.debug(f"✅ [{request_id}] Landmark URL generated successfully")
                    logging.debug(f"🔗 [{request_id}] Generated URL: {resource_info['landmark_data'][:100]}...")
                    
                except Exception as e:
                    logging.error(f"❌ [{request_id}] Failed to generate pre-signed URL for landmark '{landmark_s3_key}': {e}")
                    logging.error(f"📊 [{request_id}] Bucket: {AWS_S3_BUCKET_NAME}, Region: {AWS_S3_REGION}")
                    
                    # Try to check if the object exists
                    try:
                        s3_client.head_object(Bucket=AWS_S3_BUCKET_NAME, Key=landmark_s3_key)
                        logging.error(f"📁 [{request_id}] Object EXISTS in S3, but URL generation failed")
                    except ClientError as head_error:
                        if head_error.response['Error']['Code'] == '404':
                            logging.error(f"📁 [{request_id}] Object NOT FOUND in S3: {landmark_s3_key}")
                        else:
                            logging.error(f"📁 [{request_id}] Error checking object existence: {head_error}")
                    except Exception as head_error:
                        logging.error(f"📁 [{request_id}] Unexpected error checking object: {head_error}")

        else:
            logging.warning(f"⚠️ [{request_id}] Sign '{label}' not found in custom lk-dictionary-mapping.json.")

        # Log final resource status
        has_video = resource_info["video_path"] is not None
        has_animation = resource_info["animation_path"] is not None  
        has_landmarks = resource_info["landmark_data"] is not None
        logging.debug(f"📋 [{request_id}] Resource summary for '{label}' - Video: {has_video}, Animation: {has_animation}, Landmarks: {has_landmarks}")

        return resource_info
    
    def _get_letter_fallback(self, word: str, request_id: str = "UNKNOWN") -> list:
        """
        Get letter-based sign sequence for words not in dictionary
        
        Args:
            word: Word to break down into letters
            request_id: Request ID for tracking
            
        Returns:
            List of letter sign dictionaries
        """
        try:
            logging.debug(f"🔤 [{request_id}] Generating letter sequence for word: '{word}'")
            letter_service = get_letter_mapping_service()
            letter_signs = letter_service.get_word_as_letter_sequence(word)
            logging.info(f"✅ [{request_id}] Generated letter fallback for word '{word}': {len(letter_signs)} letters")
            
            # Log individual letters for debugging
            if letter_signs:
                letter_labels = [sign.get("label", "unknown") for sign in letter_signs]
                logging.debug(f"🔤 [{request_id}] Letters for '{word}': {letter_labels}")
            
            return letter_signs
        except Exception as e:
            logging.error(f"❌ [{request_id}] Failed to generate letter fallback for word '{word}': {e}")
            return []

    def _map_labels_to_sign(self, video_labels: list[str], person=None, camera=None, sep="_", request_id: str = "UNKNOWN") -> list[dict]:
        """
        Overrides the parent method to call _get_available_formats for each label.
        """
        logging.debug(f"🗂️ [{request_id}] Mapping {len(video_labels)} labels to signs: {video_labels}")
        sign_resources_info = [self._get_available_formats(label, request_id) for label in video_labels]
        logging.debug(f"📦 [{request_id}] Mapped {len(sign_resources_info)} sign resources")
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

def get_diagnostics(full: bool = True) -> dict:
    """Return diagnostics about the translation service environment."""
    # cv2 availability
    cv2_available = True
    cv2_error = None
    try:
        import cv2  # noqa: F401
    except Exception as e:  # pragma: no cover
        cv2_available = False
        cv2_error = str(e)

    # Assets information
    assets_root = None
    lk_mapping_path = None
    lk_mapping_exists = False
    try:
        assets_root = Assets.ROOT_DIR  # type: ignore[name-defined]
        lk_mapping_path = os.path.join(assets_root, "lk-dictionary-mapping.json")
        lk_mapping_exists = os.path.exists(lk_mapping_path)
    except Exception:
        pass

    # Letter landmarks
    landmarks_dir = os.path.join(
        os.path.dirname(__file__),
        '..', '..',
        'sign-language-translator',
        'sign_language_translator',
        'assets',
        'datasets',
        'output_landmarks',
    )
    try:
        landmark_files = [f for f in os.listdir(os.path.abspath(landmarks_dir)) if f.endswith('.json')]
        landmarks_count = len(landmark_files)
    except Exception:
        landmarks_count = 0

    diag_full = {
        "python_version": sys.version.split(" ")[0],
        "cwd": os.getcwd(),
        "slt_imported": bool(slt_models),
        "slt_import_error": SLT_IMPORT_ERROR,
        "cv2_available": cv2_available,
        "cv2_error": cv2_error,
        "assets_root": assets_root,
        "lk_dict_path": lk_mapping_path,
        "lk_dict_exists": lk_mapping_exists,
        "letter_landmarks_dir": os.path.abspath(landmarks_dir),
        "letter_landmarks_count": landmarks_count,
        "models_loaded": list(models.keys()),
        "expected_model_si": "si_to_sinhala-sl" in models,
        "s3_configured": all([
            bool(AWS_S3_BUCKET_NAME), bool(AWS_ACCESS_KEY_ID), bool(AWS_SECRET_ACCESS_KEY), bool(AWS_S3_REGION)
        ]),
        "s3_client_initialized": s3_client is not None,
        "s3_bucket": AWS_S3_BUCKET_NAME,
        "s3_error": S3_INIT_ERROR,
    }

    if full:
        return diag_full
    # minimal subset for error payloads
    return {
        "slt_imported": diag_full["slt_imported"],
        "slt_import_error": diag_full["slt_import_error"],
        "cv2_available": diag_full["cv2_available"],
        "letter_landmarks_count": diag_full["letter_landmarks_count"],
        "models_loaded_count": len(diag_full["models_loaded"]),
        "expected_model_si": diag_full["expected_model_si"],
    }

def translate_text_to_slsl(text, source_language_code="si", request_id="UNKNOWN"):
    """
    Translates text to Sinhala Sign Language, returning all available media formats for each sign.
    Uses letter-based fallback for words not found in the dictionary.
    """
    from datetime import datetime
    timestamp = datetime.now().isoformat()
    
    logging.info(f"🎯 [{timestamp}] TRANSLATION_SERVICE [{request_id}] Starting translation")
    logging.info(f"📊 [{request_id}] Input - Text: '{text}', Language: '{source_language_code}', Length: {len(text)}")

    # Helper utilities used across branches
    def _has_sinhala_combining_marks(token: str) -> bool:
        return any(ch in SINHALA_COMBINING_MARKS_SET for ch in token)

    def _expected_option_b_len(token: str) -> int:
        try:
            letter_service_local = get_letter_mapping_service()
            return len([d for d in letter_service_local.get_word_as_letter_sequence(token)])
        except Exception:
            return 0
    
    if not models:
        error_msg = "Translation service not available."
        logging.error(f"❌ [{request_id}] Service Error: {error_msg}")
        return {"error": error_msg, "code": "SERVICE_UNAVAILABLE", "diagnostics": get_diagnostics(full=False)}

    model_key = f"{source_language_code}_to_sinhala-sl"
    if model_key not in models:
        error_msg = f"Translation model for '{source_language_code}' not available."
        logging.error(f"❌ [{request_id}] Model Error: {error_msg}")
        return {"error": error_msg, "code": "MODEL_MISSING", "diagnostics": get_diagnostics(full=False)}

    model = models[model_key]
    logging.info(f"🤖 [{request_id}] Using model: {model_key}")
    
    try:
        # Check if the text contains combining marks and should use letter fallback directly
        if _has_sinhala_combining_marks(text):
            expected_len = _expected_option_b_len(text)
            if expected_len > 3:  # Use letter fallback for longer words with combining marks
                logging.info(f"🔤 [{request_id}] Text '{text}' contains combining marks and has {expected_len} components - using direct letter fallback")
                letter_service = get_letter_mapping_service()
                letter_signs = letter_service.get_word_as_letter_sequence(text)
                if letter_signs:
                    logging.info(f"✅ [{request_id}] Generated {len(letter_signs)} letter signs directly")
                    return {"signs": letter_signs}
        
        model_start_time = datetime.now()
        logging.info(f"⚡ [{request_id}] Calling translation model...")
        signs_data = model(text)
        model_duration = (datetime.now() - model_start_time).total_seconds()
        logging.info(f"⚡ [{request_id}] Model call completed in {model_duration:.3f}s, got {len(signs_data)} initial signs")
        
        # Check for unknown words and apply letter fallback
        logging.info(f"🔍 [{request_id}] Processing signs and checking for fallbacks...")
        enhanced_signs_data = []
        fallback_count = 0
        
        # (helpers defined above)

        for i, sign_info in enumerate(signs_data):
            if isinstance(sign_info, dict):
                label = sign_info.get("label", "")
                
                # Log sign processing
                has_video = sign_info.get("video_path") is not None
                has_animation = sign_info.get("animation_path") is not None
                has_landmarks = sign_info.get("landmark_data") is not None
                
                logging.debug(f"📄 [{request_id}] Sign {i}: '{label}' - Video: {has_video}, Animation: {has_animation}, Landmarks: {has_landmarks}")
                
                # If sign not found in dictionary, try letter fallback
                if (not has_video and not has_animation and not has_landmarks and
                    label and not label.startswith("letter_")):
                    
                    logging.info(f"🔤 [{request_id}] Applying letter fallback for unknown word: '{label}'")
                    letter_signs = model._get_letter_fallback(label, request_id)
                    if letter_signs:
                        fallback_count += len(letter_signs)
                        enhanced_signs_data.extend(letter_signs)
                        logging.info(f"✅ [{request_id}] Generated {len(letter_signs)} letter signs for '{label}'")
                    else:
                        enhanced_signs_data.append(sign_info)  # Keep original if fallback fails
                        logging.warning(f"⚠️ [{request_id}] Letter fallback failed for '{label}'")
                else:
                    if label and not label.startswith("letter_") and _has_sinhala_combining_marks(label):
                        try:
                            expected_len = _expected_option_b_len(label)
                            if expected_len > 1:
                                logging.info(f"🔤 [{request_id}] Overriding model output for '{label}' with letter fallback (expected {expected_len} units)")
                                letter_service = get_letter_mapping_service()
                                letter_signs = letter_service.get_word_as_letter_sequence(label)
                                if letter_signs:
                                    enhanced_signs_data.extend(letter_signs)
                                    continue
                        except Exception as e:
                            logging.warning(f"⚠️ [{request_id}] Override heuristic failed for '{label}': {e}")

                    enhanced_signs_data.append(sign_info)
            else:
                enhanced_signs_data.append(sign_info)
        
        final_timestamp = datetime.now().isoformat()
        logging.info(f"🎉 [{final_timestamp}] TRANSLATION_COMPLETE [{request_id}] Final result: {len(enhanced_signs_data)} signs ({fallback_count} from letter fallback)")
        
        # Log sign summary
        if enhanced_signs_data:
            sign_summary = []
            for sign in enhanced_signs_data:
                if isinstance(sign, dict):
                    label = sign.get("label", "unknown")
                    has_content = any([sign.get("video_path"), sign.get("animation_path"), sign.get("landmark_data")])
                    sign_summary.append(f"'{label}': {'✓' if has_content else '✗'}")
            logging.info(f"📝 [{request_id}] Sign Summary: {', '.join(sign_summary)}")
        
        return {"signs": enhanced_signs_data}
    except Exception as e:
        error_timestamp = datetime.now().isoformat()
        tb_str = traceback.format_exc()
        logging.error(f"💥 [{error_timestamp}] TRANSLATION_ERROR [{request_id}] Exception during translation for text '{text}': {e}")
        logging.error(f"📚 [{request_id}] Full traceback:\n{tb_str}")
        return {"error": "Failed to translate text.", "details": str(e)}
