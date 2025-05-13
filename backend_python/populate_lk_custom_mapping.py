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
DATASET_PREFIX = "lk-custom" # Keep prefix for generating entry keys if needed, but filename is changed
LOG_FILE_PATH = "populate_mapping.log" # Log file will be created in the CWD (backend_python/)

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

def get_next_id(existing_mapping):
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
    logging.info(f"Media base directory: {os.path.abspath(MEDIA_BASE_DIR)}")
    logging.info(f"Mapping file path: {os.path.abspath(MAPPING_FILE_PATH)}")

    if not os.path.isdir(MEDIA_BASE_DIR):
        logging.error(f"Media base directory not found: {MEDIA_BASE_DIR}")
        return

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

    next_id = get_next_id(existing_mapping)
    logging.info(f"Next available ID for new entries: {next_id:03d}")
    
    # Create a set of existing English glosses for quick lookup to avoid duplicates by gloss
    # This checks the 'en' field within the 'text' object of each entry.
    processed_english_glosses = set()
    for entry_data in existing_mapping.values():
        if "text" in entry_data and "en" in entry_data["text"] and entry_data["text"]["en"]:
            # Add all English translations from the list to the set
            for en_gloss in entry_data["text"]["en"]:
                 if isinstance(en_gloss, str):
                    processed_english_glosses.add(en_gloss.lower())


    translator = GoogleTranslator(source='en', target='si')
    added_count = 0

    for dir_name in sorted(os.listdir(MEDIA_BASE_DIR)):
        current_dir_path = os.path.join(MEDIA_BASE_DIR, dir_name)
        if os.path.isdir(current_dir_path):
            english_gloss = dir_name # Directory name is the English gloss

            # Skip if this English gloss (directory name) seems to be already processed
            if english_gloss.lower() in processed_english_glosses:
                logging.info(f"Skipping directory '{english_gloss}': An entry with this English gloss might already exist.")
                continue

            media_filename, fallback_used = find_media_file(current_dir_path, dir_name)

            if not media_filename:
                logging.error(f"No suitable media file found in directory: {dir_name}")
                continue

            if fallback_used:
                logging.warning(f"Directory '{dir_name}': Processed using fallback media file '{media_filename}'. Consider standardizing.")
            
            try:
                sinhala_translations = [translator.translate(english_gloss)]
                if not sinhala_translations[0]: # Handle empty translation
                    raise Exception("Translation returned empty")
            except Exception as e:
                logging.error(f"Could not translate '{english_gloss}' to Sinhala: {e}")
                continue

            entry_key = f"{DATASET_PREFIX}-{next_id:03d}_{english_gloss.replace(' ', '_')}" # Sanitize gloss for key
            
            new_entry = {
                "text": {
                    "si": sinhala_translations,
                    "en": [english_gloss] # Store original directory name as English gloss
                },
                "media_path": f"datasets/lk-custom/media/{dir_name}/{media_filename}",
                "media_type": "video" # Assuming video
            }

            existing_mapping[entry_key] = new_entry
            processed_english_glosses.add(english_gloss.lower()) # Add to processed set
            logging.info(f"Added entry for '{english_gloss}' (Sinhala: {sinhala_translations[0]}) with media '{media_filename}' as key '{entry_key}'")
            next_id += 1
            added_count += 1

    if added_count > 0:
        try:
            # Ensure parent directory for MAPPING_FILE_PATH exists
            os.makedirs(os.path.dirname(MAPPING_FILE_PATH), exist_ok=True)
            with open(MAPPING_FILE_PATH, 'w', encoding='utf-8') as f:
                json.dump(existing_mapping, f, ensure_ascii=False, indent=2)
            logging.info(f"Successfully updated and saved mapping file with {added_count} new entries. Total entries: {len(existing_mapping)}")
        except Exception as e:
            logging.error(f"Error writing updated mapping file: {e}")
    else:
        logging.info("No new entries were added to the mapping file.")

    logging.info(f"Script finished. Log saved to {LOG_FILE_PATH}")

if __name__ == '__main__':
    main()
