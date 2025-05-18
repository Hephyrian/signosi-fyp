import os
import json
import logging
import re
from deep_translator import GoogleTranslator

# --- Configuration ---
# Prepend 'backend_python' to the base path
BASE_SIGN_LANGUAGE_TRANSLATOR_PATH = os.path.join("backend_python", "sign-language-translator", "sign_language_translator")
MEDIA_BASE_DIR = os.path.join(BASE_SIGN_LANGUAGE_TRANSLATOR_PATH, "assets", "datasets", "lk-custom", "media")
# Save directly to assets directory with the expected name format
MAPPING_FILE_PATH = os.path.join(BASE_SIGN_LANGUAGE_TRANSLATOR_PATH, "assets", "lk-dictionary-mapping.json")
DATASET_PREFIX = "lk-custom" # Prefix for video entries
LOG_FILE_PATH = "populate_mapping.log" # Log file will be created in the CWD (backend_python/)

# --- New Configuration for CSV Data ---
CSV_DATASET_BASE_DIR = os.path.join(BASE_SIGN_LANGUAGE_TRANSLATOR_PATH, "assets", "datasets", "Dataset-MP-CSV")
MP_CSV_DATA_PREFIX = "mp-csv-data" # Prefix for CSV entries

# --- Setup Logging ---
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE_PATH),
        logging.StreamHandler()
    ]
)

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

def get_next_lk_custom_id(existing_mapping):
    max_id = 0
    if not existing_mapping:
        return 1
    
    for key in existing_mapping.keys():
        match = re.match(rf"{DATASET_PREFIX}-(\d+)_", key)
        if match:
            current_id = int(match.group(1))
            if current_id > max_id:
                max_id = current_id
    return max_id + 1

def main():
    logging.info(f"Starting script to populate {MAPPING_FILE_PATH}")
    logging.info(f"Media base directory (videos): {os.path.abspath(MEDIA_BASE_DIR)}")
    logging.info(f"CSV dataset base directory: {os.path.abspath(CSV_DATASET_BASE_DIR)}")
    logging.info(f"Mapping file path: {os.path.abspath(MAPPING_FILE_PATH)}")

    if not os.path.isdir(MEDIA_BASE_DIR):
        logging.warning(f"Media base directory (videos) not found: {MEDIA_BASE_DIR}. Video processing will be skipped.")
    if not os.path.isdir(CSV_DATASET_BASE_DIR):
        logging.warning(f"CSV_DATASET_BASE_DIR not found: {CSV_DATASET_BASE_DIR}. CSV processing will be skipped.")

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

    # Cache for translations to avoid repeated API calls
    translation_cache = {}
    translator = GoogleTranslator(source='en', target='si')
    
    # Populate a set of English glosses from the initially loaded mapping.
    # This helps avoid reprocessing video directories if their gloss is already known.
    initial_processed_english_glosses = set()
    for entry_data_val in existing_mapping.values():
        if "text" in entry_data_val and "en" in entry_data_val["text"] and entry_data_val["text"]["en"]:
            for en_g in entry_data_val["text"]["en"]:
                 if isinstance(en_g, str):
                    initial_processed_english_glosses.add(en_g.lower())

    video_added_count = 0
    csv_added_count = 0

    # --- Process Video Files (lk-custom) ---
    logging.info("--- Starting Video File Processing (lk-custom) ---")
    if os.path.isdir(MEDIA_BASE_DIR):
        next_lk_id = get_next_lk_custom_id(existing_mapping) # Get ID for new video entries
        logging.info(f"Next available ID for new lk-custom video entries: {next_lk_id:03d}")

        for dir_name in sorted(os.listdir(MEDIA_BASE_DIR)):
            current_dir_path = os.path.join(MEDIA_BASE_DIR, dir_name)
            if os.path.isdir(current_dir_path):
                english_gloss_video = dir_name # Directory name is the English gloss

                if english_gloss_video.lower() in initial_processed_english_glosses:
                    logging.info(f"Skipping video directory '{dir_name}': An entry for English gloss '{english_gloss_video}' already exists in the mapping.")
                    continue

                media_filename, fallback_used = find_media_file(current_dir_path, dir_name)

                if not media_filename:
                    logging.error(f"No suitable media file found in video directory: {dir_name}")
                    continue

                if fallback_used:
                    logging.warning(f"Video Directory '{dir_name}': Processed using fallback media file '{media_filename}'. Consider standardizing.")
                
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
                        logging.error(f"Could not translate '{english_gloss_video}' for video: {e}")
                        continue
                
                entry_key_video = f"{DATASET_PREFIX}-{next_lk_id:03d}_{english_gloss_video.replace(' ', '_')}"
                
                new_video_entry = {
                    "text": {
                        "si": sinhala_translations_video,
                        "en": [english_gloss_video]
                    },
                    "media_path": f"datasets/lk-custom/media/{dir_name}/{media_filename}",
                    "media_type": "video"
                }

                existing_mapping[entry_key_video] = new_video_entry
                initial_processed_english_glosses.add(english_gloss_video.lower()) # Add to set after successful processing
                logging.info(f"Added video entry for '{english_gloss_video}' (Sinhala: {sinhala_translations_video[0]}) with media '{media_filename}' as key '{entry_key_video}'")
                next_lk_id += 1
                video_added_count += 1
    else:
        logging.info("Skipping video processing as MEDIA_BASE_DIR was not found.")


    # --- Process CSV Files (mp-csv-data) ---
    logging.info("--- Starting CSV File Processing (mp-csv-data) ---")
    if os.path.isdir(CSV_DATASET_BASE_DIR):
        for category_name in sorted(os.listdir(CSV_DATASET_BASE_DIR)): # e.g., Months
            category_path = os.path.join(CSV_DATASET_BASE_DIR, category_name)
            if os.path.isdir(category_path):
                for gloss_dir_name in sorted(os.listdir(category_path)): # e.g., April (this is english_gloss)
                    gloss_path = os.path.join(category_path, gloss_dir_name)
                    if os.path.isdir(gloss_path):
                        english_gloss_csv = gloss_dir_name

                        for csv_filename in sorted(os.listdir(gloss_path)):
                            if csv_filename.lower().endswith(".csv"):
                                # Validate filename format and extract ID
                                # Expected: GlossName_XXX.csv, e.g., April_001.csv
                                expected_start_pattern = f"{english_gloss_csv}_"
                                if not csv_filename.lower().startswith(expected_start_pattern.lower()):
                                    logging.warning(f"CSV file '{csv_filename}' in '{gloss_path}' does not match expected start pattern '{expected_start_pattern}XXX.csv'. Skipping.")
                                    continue
                                
                                match = re.search(r'_(\d{3,})\.csv$', csv_filename, re.IGNORECASE)
                                if not match:
                                    logging.warning(f"Could not extract ID from CSV filename: '{csv_filename}' in '{gloss_path}'. Expected format like '{english_gloss_csv}_001.csv'. Skipping.")
                                    continue
                                file_id = match.group(1)

                                entry_key_csv = f"{MP_CSV_DATA_PREFIX}-{file_id}_{english_gloss_csv.replace(' ', '_')}"

                                if entry_key_csv in existing_mapping:
                                    logging.info(f"Skipping CSV file '{csv_filename}': Entry key '{entry_key_csv}' already exists.")
                                    continue
                                
                                sinhala_translations_csv = []
                                if english_gloss_csv.lower() in translation_cache:
                                    sinhala_translations_csv = translation_cache[english_gloss_csv.lower()]
                                    logging.info(f"Using cached Sinhala translation for CSV gloss '{english_gloss_csv}'.")
                                else:
                                    try:
                                        translated_text = translator.translate(english_gloss_csv)
                                        if not translated_text: # Handle empty translation
                                            raise Exception("Translation returned empty")
                                        sinhala_translations_csv = [translated_text]
                                        translation_cache[english_gloss_csv.lower()] = sinhala_translations_csv
                                    except Exception as e:
                                        logging.error(f"Could not translate '{english_gloss_csv}' for CSV '{csv_filename}': {e}")
                                        continue # Skip this CSV if translation fails
                                
                                # Construct relative path for media_path
                                relative_csv_path = os.path.join("datasets", "Dataset-MP-CSV", category_name, gloss_dir_name, csv_filename).replace("\\", "/")
                                
                                new_csv_entry = {
                                    "text": {
                                        "si": sinhala_translations_csv,
                                        "en": [english_gloss_csv] 
                                    },
                                    "media_path": relative_csv_path,
                                    "media_type": "csv_coordinates" 
                                }

                                existing_mapping[entry_key_csv] = new_csv_entry
                                logging.info(f"Added CSV entry for '{english_gloss_csv}' (File ID: {file_id}, Sinhala: {sinhala_translations_csv[0]}) with media '{csv_filename}' as key '{entry_key_csv}'")
                                csv_added_count += 1
    else:
        logging.info("Skipping CSV processing as CSV_DATASET_BASE_DIR was not found.")


    total_added_count = video_added_count + csv_added_count
    if total_added_count > 0:
        try:
            # Ensure parent directory for MAPPING_FILE_PATH exists
            os.makedirs(os.path.dirname(MAPPING_FILE_PATH), exist_ok=True)
            with open(MAPPING_FILE_PATH, 'w', encoding='utf-8') as f:
                json.dump(existing_mapping, f, ensure_ascii=False, indent=2)
            logging.info(f"Successfully updated mapping. Videos added: {video_added_count}. CSVs added: {csv_added_count}. Total new: {total_added_count}. Total entries: {len(existing_mapping)}")
        except Exception as e:
            logging.error(f"Error writing updated mapping file: {e}")
    else:
        logging.info("No new video or CSV entries were added to the mapping file.")

    logging.info(f"Script finished. Log saved to {LOG_FILE_PATH}")

if __name__ == '__main__':
    main()
