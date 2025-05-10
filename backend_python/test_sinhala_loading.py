import sys
import os
import traceback

# Adjust sys.path to find the local sign_language_translator package
# Assumes this script is in backend_python/ and the package is in backend_python/sign-language-translator/
# The 'sign-language-translator' directory is the root of the pip installable package.
PACKAGE_PARENT_DIR = os.path.abspath(os.path.dirname(__file__))
PACKAGE_ROOT_DIR = os.path.join(PACKAGE_PARENT_DIR, "sign-language-translator")

if PACKAGE_ROOT_DIR not in sys.path:
    sys.path.insert(0, PACKAGE_ROOT_DIR)

try:
    import sign_language_translator.models as slt_models
    from sign_language_translator.languages import SignLanguage
    # Attempt to get the language class to confirm it's registered and to check its properties later
    sinhala_lang_class = SignLanguage.create("sinhala-sl", text_language_code="si") # dummy text_language_code for now
    print(f"Successfully imported sign_language_translator and found SinhalaSignLanguage class.")
    print(f"SinhalaSignLanguage dictionary file should be: {sinhala_lang_class.dictionary_mapping_file}")
    if not os.path.exists(sinhala_lang_class.dictionary_mapping_file):
        print(f"WARNING: The dictionary file {sinhala_lang_class.dictionary_mapping_file} does not seem to exist at this path.")
    else:
        print(f"Confirmed: The dictionary file {sinhala_lang_class.dictionary_mapping_file} exists.")


except ImportError:
    print("ERROR: Could not import the 'sign_language_translator' package.")
    print(f"Please ensure that the package is installed or that the path '{PACKAGE_ROOT_DIR}' is correct and contains the package.")
    print(traceback.format_exc())
    sys.exit(1)
except Exception as e:
    print(f"ERROR: Could not get SinhalaSignLanguage class. Is it correctly registered in __init__.py files?")
    print(traceback.format_exc())
    sys.exit(1)

def test_translation(text_language_code, text_to_translate, expected_media_hint=""):
    print(f"\n--- Testing with text_language='{text_language_code}', text='{text_to_translate}' ---")
    try:
        # Initialize the ConcatenativeSynthesis model
        # This model will internally create an instance of SinhalaSignLanguage
        model = slt_models.ConcatenativeSynthesis(
            text_language=text_language_code,  # Language of the input text
            sign_language="sinhala-sl",  # Target sign language
            sign_format="video"          # We expect video outputs
        )
        print("Model initialized successfully.")

        # Perform translation
        print(f"Attempting to translate: '{text_to_translate}'")
        sign_output = model.translate(text_to_translate)
        
        print("Translation result (sign_dicts):")
        if sign_output and sign_output.sign_dicts:
            for sign_dict in sign_output.sign_dicts:
                print(f"  - {sign_dict}")
            # Basic check if the expected media path is part of the output
            if expected_media_hint and any(expected_media_hint in d.get("media_path", "") for d in sign_output.sign_dicts):
                print(f"SUCCESS: Found expected media hint '{expected_media_hint}' in translation.")
            elif expected_media_hint:
                print(f"NOTE: Did not find exact media hint '{expected_media_hint}' in translation, but translation produced output.")
        else:
            print("  - No sign_dicts produced or empty output.")

    except Exception as e:
        print(f"ERROR during testing with '{text_to_translate}':")
        print(traceback.format_exc())

if __name__ == "__main__":
    # Test case 1: English input
    # "Ayubowan" is lk-custom-001_Ayubowan, media: Ayubowan/Ayubowan_001.mov
    test_translation(text_language_code="en", text_to_translate="Ayubowan", expected_media_hint="Ayubowan/Ayubowan_001")

    # Test case 2: Sinhala input
    # "පොත" (Book) is lk-custom-002_Potha, media: Book/Book_001.mp4
    test_translation(text_language_code="si", text_to_translate="පොත", expected_media_hint="Book/Book_001")

    # Test case 3: Another English input from the populated list
    # "Cat" is lk-custom-062_Cat, media: Cat/Cat_001.mp4
    test_translation(text_language_code="en", text_to_translate="Cat", expected_media_hint="Cat/Cat_001")
    
    # Test case 4: A word that might involve character-by-character spelling if not in dictionary
    # (Assuming 'XYZ' is not in the dictionary and character signs exist)
    # This depends on how SinhalaSignLanguage handles unknown words and if character signs are mapped.
    # print("\nNote: The following test for 'XYZ' might try to spell if 'X', 'Y', 'Z' character signs are defined.")
    # test_translation(text_language_code="en", text_to_translate="XYZ")
