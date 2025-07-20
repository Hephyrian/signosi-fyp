import os
import json
import logging
import re
from deep_translator import GoogleTranslator

# --- Configuration ---
# Prepend 'backend_python' to the base path
BASE_SIGN_LANGUAGE_TRANSLATOR_PATH = os.path.join("sign-language-translator", "sign_language_translator")
# Save directly to assets directory with the expected name format
MAPPING_FILE_PATH = os.path.join(BASE_SIGN_LANGUAGE_TRANSLATOR_PATH, "assets", "lk-dictionary-mapping.json")
LOG_FILE_PATH = "populate_mapping.log" # Log file will be created in the CWD (backend_python/)

MEDIA_SOURCES = [
    {
        "media_type": "video",
        "base_dir": os.path.join(BASE_SIGN_LANGUAGE_TRANSLATOR_PATH, "assets", "datasets", "Dataset-Original"),
        "dataset_prefix": "lk-custom",
        "file_extensions": (".mp4", ".mov"),
        "process_func": "process_video_files"
    },
    {
        "media_type": "landmark",
        "base_dir": os.path.join(BASE_SIGN_LANGUAGE_TRANSLATOR_PATH, "assets", "datasets", "output_landmarks"),
        "dataset_prefix": "lk-landmark",
        "file_extensions": (".json",),
        "process_func": "process_landmark_files"
    }
]

# --- Setup Logging ---
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE_PATH, encoding='utf-8'),
        logging.StreamHandler()
    ]
)

def get_next_lk_custom_id(existing_mapping, dataset_prefix):
    max_id = 0
    if not existing_mapping:
        return 1
    
    for key in existing_mapping.keys():
        match = re.match(rf"{re.escape(dataset_prefix)}-(\d+)_", key)
        if match:
            current_id = int(match.group(1))
            if current_id > max_id:
                max_id = current_id
    return max_id + 1

def find_media_file(directory_path, dir_name):
    """
    Finds a media file in the given directory based on prioritized rules.
    Returns the filename and a flag indicating if a fallback was used.
    """
    # Rule 1: [DirName]_001.mp4 or [DirName]_001.mov
    for ext in [".mp4", ".mov"]:
        preferred_file = f"{dir_name}_001{ext}"
        if os.path.exists(os.path.join(directory_path, preferred_file)):
            return preferred_file, False
    
    # Rule 2: 001.mp4 or 001.mov
    for ext in [".mp4", ".mov"]:
        preferred_file = f"001{ext}"
        if os.path.exists(os.path.join(directory_path, preferred_file)):
            return preferred_file, False # Still considered a primary pattern

    # Rule 3: Alphabetically first .mp4 or .mov
    files = sorted(os.listdir(directory_path))
    for ext in [".mp4", ".mov"]:
        for f_name in files:
            if f_name.lower().endswith(ext):
                return f_name, True # Fallback used
    
    return None, False

def process_video_files(media_source, existing_mapping, next_lk_id):
    video_added_count = 0
    logging.info(f"--- Starting Video File Processing ({media_source['dataset_prefix']}) ---")
    media_base_dir = media_source["base_dir"]
    dataset_prefix = media_source["dataset_prefix"]
    file_extensions = media_source["file_extensions"]

    if not os.path.isdir(media_base_dir):
        logging.warning(f"Media base directory (videos) not found: {media_base_dir}. Video processing will be skipped.")
        return 0

    # Cache for translations to avoid repeated API calls
    translation_cache = {}
    translator = GoogleTranslator(source='en', target='si')

    # Populate a set of English glosses from the initially loaded mapping.
    initial_processed_english_glosses = set()
    for entry_data_val in existing_mapping.values():
        if "text" in entry_data_val and "en" in entry_data_val["text"] and entry_data_val["text"]["en"]:
            for en_g in entry_data_val["text"]["en"]:
                 if isinstance(en_g, str):
                    initial_processed_english_glosses.add(en_g.lower())

    for category_name in sorted(os.listdir(media_base_dir)): # e.g., Adjectives, Nouns
        category_path = os.path.join(media_base_dir, category_name)
        if not os.path.isdir(category_path):
            continue # Skip if it's not a directory

        logging.info(f"Processing video category: {category_name}")

        for gloss_dir_name in sorted(os.listdir(category_path)): # e.g., Happy, Sad (this is the English gloss)
            current_gloss_dir_path = os.path.join(category_path, gloss_dir_name)
            if os.path.isdir(current_gloss_dir_path):
                english_gloss_video = gloss_dir_name # The subdirectory name is the English gloss

                if english_gloss_video.lower() in initial_processed_english_glosses:
                    logging.info(f"Skipping video directory '{category_name}/{gloss_dir_name}': An entry for English gloss '{english_gloss_video}' already exists in the mapping.")
                    continue

                media_filename, fallback_used = find_media_file(current_gloss_dir_path, gloss_dir_name)

                if not media_filename:
                    logging.error(f"No suitable media file found in video directory: {category_name}/{gloss_dir_name}")
                    continue

                if fallback_used:
                    logging.warning(f"Video Directory '{category_name}/{gloss_dir_name}': Processed using fallback media file '{media_filename}'. Consider standardizing.")
                
                sinhala_translations_video = []
                if english_gloss_video.lower() in translation_cache:
                    sinhala_translations_video = translation_cache[english_gloss_video.lower()]
                    logging.info(f"Using cached Sinhala translation for video gloss '{english_gloss_video}'.")
                else:
                    try:
                        translated_text = translator.translate(english_gloss_video)
                        if not translated_text:
                            raise Exception("Translation returned empty")
                        sinhala_translations_video = [translated_text]
                        translation_cache[english_gloss_video.lower()] = sinhala_translations_video
                    except Exception as e:
                        logging.error(f"Could not translate '{english_gloss_video}' for video in '{category_name}/{gloss_dir_name}': {e}")
                        continue
                
                entry_key_video = f"{dataset_prefix}-{next_lk_id:03d}_{english_gloss_video.replace(' ', '_')}"
                
                # Construct relative media path from the perspective of 'assets' directory
                relative_media_path_parts = [
                    "datasets", 
                    os.path.basename(media_base_dir), # Should be "Dataset-Original"
                    category_name,
                    gloss_dir_name,
                    media_filename
                ]
                correct_media_path = os.path.join(*relative_media_path_parts).replace("\\", "/")


                new_video_entry = {
                    "text": {
                        "si": sinhala_translations_video,
                        "en": [english_gloss_video]
                    },
                    "video_path": correct_media_path,
                    "media_type": "video"
                }

                existing_mapping[entry_key_video] = new_video_entry
                initial_processed_english_glosses.add(english_gloss_video.lower()) # Add to set after successful processing
                logging.info(f"Added video entry for '{english_gloss_video}' (Category: {category_name}, Sinhala: {sinhala_translations_video[0]}) with media '{media_filename}' as key '{entry_key_video}' at path '{correct_media_path}'")
                next_lk_id += 1
                video_added_count += 1
    return video_added_count

def process_landmark_files(media_source, existing_mapping, next_lk_id):
    landmark_added_count = 0
    logging.info(f"--- Starting Landmark File Processing ({media_source['dataset_prefix']}) ---")
    media_base_dir = media_source["base_dir"]
    dataset_prefix = media_source["dataset_prefix"]
    file_extensions = media_source["file_extensions"]

    if not os.path.isdir(media_base_dir):
        logging.warning(f"Media base directory (landmarks) not found: {media_base_dir}. Landmark processing will be skipped.")
        return 0

    for filename in sorted(os.listdir(media_base_dir)):
        if filename.lower().endswith(file_extensions):
            sinhala_char = os.path.splitext(filename)[0] # Extract Sinhala character from filename
            
            # Construct a unique key for the entry
            entry_key_landmark = f"{dataset_prefix}-{next_lk_id:03d}_{sinhala_char.replace(' ', '_')}"

            # Construct relative media path from the perspective of 'assets' directory
            relative_media_path_parts = [
                "datasets", 
                os.path.basename(media_base_dir), 
                filename
            ]
            correct_media_path = os.path.join(*relative_media_path_parts).replace("\\", "/")

            new_landmark_entry = {
                "text": {
                    "si": [sinhala_char] # Sinhala character is the text
                },
                "landmark_data": correct_media_path, # Use landmark_data for S3 key
                "media_type": "landmark"
            }

            # Check if an entry for this Sinhala character already exists to avoid duplicates
            found_existing = False
            for key, value in existing_mapping.items():
                if "text" in value and "si" in value["text"] and sinhala_char in value["text"]["si"]:
                    logging.info(f"Skipping landmark '{filename}': An entry for Sinhala character '{sinhala_char}' already exists in the mapping.")
                    found_existing = True
                    break
            
            if found_existing:
                continue

            existing_mapping[entry_key_landmark] = new_landmark_entry
            logging.info(f"Added landmark entry for '{sinhala_char}' with media '{filename}' as key '{entry_key_landmark}' at path '{correct_media_path}'")
            next_lk_id += 1
            landmark_added_count += 1
    return landmark_added_count

def main():
    logging.info(f"Starting script to populate {MAPPING_FILE_PATH}")
    logging.info(f"Mapping file path: {os.path.abspath(MAPPING_FILE_PATH)}")

    # Load existing mapping file or initialize if not found
    existing_mapping = {}
    if os.path.exists(MAPPING_FILE_PATH):
        try:
            with open(MAPPING_FILE_PATH, 'r', encoding='utf-8') as f:
                existing_mapping = json.load(f)
            logging.info(f"Loaded existing mapping file with {len(existing_mapping)} entries.")
        except json.JSONDecodeError:
            logging.error(f"Error decoding JSON from {MAPPING_FILE_PATH}. Starting with an empty mapping.")
    else:
        logging.info(f"Mapping file not found at {MAPPING_FILE_PATH}. A new one will be created.")

    total_added_count = 0

    for source in MEDIA_SOURCES:
        next_id = get_next_lk_custom_id(existing_mapping, source['dataset_prefix'])
        logging.info(f"Next available ID for {source['dataset_prefix']} entries: {next_id:03d}")

        if source["process_func"] == "process_video_files":
            total_added_count += process_video_files(source, existing_mapping, next_id)
        elif source["process_func"] == "process_landmark_files":
            total_added_count += process_landmark_files(source, existing_mapping, next_id)
        else:
            logging.warning(f"Unknown process function specified: {source['process_func']}")

    if total_added_count > 0:
        try:
            # Ensure parent directory for MAPPING_FILE_PATH exists
            os.makedirs(os.path.dirname(MAPPING_FILE_PATH), exist_ok=True)
            with open(MAPPING_FILE_PATH, 'w', encoding='utf-8') as f:
                json.dump(existing_mapping, f, ensure_ascii=False, indent=2)
            logging.info(f"Successfully updated mapping. Total new entries added: {total_added_count}. Total entries in file: {len(existing_mapping)}")
        except Exception as e:
            logging.error(f"Error writing updated mapping file: {e}")
    else:
        logging.info("No new entries were added to the mapping file.")

    logging.info(f"Script finished. Log saved to {LOG_FILE_PATH}")

if __name__ == '__main__':
    main()