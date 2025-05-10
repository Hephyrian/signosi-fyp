import sys
import os
import unittest

# Add the package root to the Python path to allow direct import
# This is often needed when running scripts directly from a tests folder
# if the package isn't installed in editable mode or site-packages.
PACKAGE_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if PACKAGE_ROOT not in sys.path:
    sys.path.insert(0, PACKAGE_ROOT)

# print(f"Attempting to import from: {PACKAGE_ROOT}")
# print(f"Current sys.path: {sys.path}")

try:
    from sign_language_translator.languages.sign import SinhalaSignLanguage
    from sign_language_translator.models import ConcatenativeSynthesis
    from sign_language_translator.languages.text import TextLanguage # For fallback
    print("Successfully imported SinhalaSignLanguage, ConcatenativeSynthesis, and TextLanguage.")
except ImportError as e:
    print(f"Error importing modules: {e}")
    print("Please ensure that the 'sign-language-translator' package is correctly structured,")
    print("all __init__.py files are correctly updated, and accessible from the PYTHONPATH.")
    print(f"Attempted to add {PACKAGE_ROOT} to sys.path.")
    print("This script expects to be run from 'backend_python/sign-language-translator/' (e.g. python -m unittest tests.test_sinhala_sl) or have the package installed.")
    sys.exit(1)
except Exception as e:
    print(f"An unexpected error occurred during imports: {e}")
    sys.exit(1)

class TestSinhalaSignLanguage(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        print("\n--- Setting up TestSinhalaSignLanguage ---")
        # This is to ensure that the TextLanguage for "sinhala" can be found or defaults.
        # The ConcatenativeSynthesis model tries to load text_language="sinhala".
        # If SinhalaTextLanguage class doesn't exist, it might cause issues.
        # We can register a default TextLanguage for "sinhala" if needed for tests.
        # from sign_language_translator.config.assets import Assets
        # if "sinhala" not in Assets.get_available_languages("text"):
        #     Assets.register_language_class("sinhala", TextLanguage, "text")
        #     print("Registered default TextLanguage for 'sinhala' for testing purposes.")
        # For now, let's assume ConcatenativeSynthesis handles missing specific text languages gracefully
        # by using the base TextLanguage or that the user might create SinhalaTextLanguage later.
        pass

    def test_01_sinhala_sign_language_initialization(self):
        """Tests if SinhalaSignLanguage can be initialized and loads its vocab."""
        print("\n--- Test 1: SinhalaSignLanguage Initialization ---")
        try:
            print("Attempting to initialize SinhalaSignLanguage...")
            sinhala_sl = SinhalaSignLanguage()
            print(f"SinhalaSignLanguage initialized: {sinhala_sl}")
            
            self.assertIsNotNone(sinhala_sl.vocab, "Vocab object should be initialized.")
            self.assertTrue(hasattr(sinhala_sl.vocab, 'data'), "Vocab object should have a 'data' attribute.")
            self.assertIsNotNone(sinhala_sl.vocab.data, "Vocab data should not be None.")
            self.assertGreater(len(sinhala_sl.vocab.data), 0, "Vocab data should not be empty.")
            print(f"Vocab loaded successfully. Number of entries: {len(sinhala_sl.vocab.data)}")

            expected_key = "lk-custom-001_Ayubowan"
            self.assertIn(expected_key, sinhala_sl.vocab.data, f"Expected key '{expected_key}' not found in vocab.")
            print(f"Found expected key '{expected_key}' in vocab.")
            # print(f"Data for '{expected_key}': {sinhala_sl.vocab.data[expected_key]}")

        except Exception as e:
            import traceback
            traceback.print_exc()
            self.fail(f"Error during SinhalaSignLanguage initialization or vocab check: {e}")

    def test_02_sinhala_translation_english_gloss(self):
        """Tests translation of an English gloss using ConcatenativeSynthesis."""
        print("\n--- Test 2: Sinhala Translation (English Gloss 'Ayubowan') ---")
        try:
            print("Attempting to initialize ConcatenativeSynthesis model (text_language='english')...")
            model = ConcatenativeSynthesis(
                text_language="english", 
                sign_language="sinhala-sl",
                sign_format="label" 
            )
            print("ConcatenativeSynthesis model initialized successfully.")

            text_to_translate = "Ayubowan"
            print(f"Attempting to translate: '{text_to_translate}'")
            translation_labels = model.translate(text_to_translate)
            print(f"Translation result (labels): {translation_labels}")

            self.assertIsNotNone(translation_labels, "Translation result should not be None.")
            self.assertIsInstance(translation_labels, list, "Translation result should be a list.")
            self.assertGreater(len(translation_labels), 0, "Translation result list should not be empty.")
            
            first_sign_dict = translation_labels[0]
            self.assertIn("sign", first_sign_dict, "Sign dictionary should contain 'sign' key.")
            self.assertEqual(first_sign_dict["sign"], "lk-custom-001_Ayubowan", 
                             f"Translation label mismatch. Expected 'lk-custom-001_Ayubowan', got {first_sign_dict.get('sign')}")
            print("SUCCESS: English gloss 'Ayubowan' translation label matches expected.")

        except Exception as e:
            import traceback
            traceback.print_exc()
            self.fail(f"Error during English gloss translation test: {e}")

    def test_03_sinhala_translation_sinhala_text(self):
        """Tests translation of Sinhala text using ConcatenativeSynthesis."""
        print("\n--- Test 3: Sinhala Translation (Sinhala Text 'ආයුබෝවන්') ---")
        try:
            # This test assumes that text_language="sinhala" will either find a
            # SinhalaTextLanguage class or default to the base TextLanguage,
            # which should be sufficient for single-word tokenization.
            print("Attempting to initialize ConcatenativeSynthesis model (text_language='sinhala')...")
            model = ConcatenativeSynthesis(
                text_language="sinhala", 
                sign_language="sinhala-sl",
                sign_format="label"
            )
            print("ConcatenativeSynthesis model initialized successfully.")

            sinhala_text = "ආයුබෝවන්"
            print(f"Attempting to translate Sinhala text: '{sinhala_text}'")
            translation_labels = model.translate(sinhala_text)
            print(f"Translation result for Sinhala text (labels): {translation_labels}")

            self.assertIsNotNone(translation_labels, "Translation result for Sinhala text should not be None.")
            self.assertIsInstance(translation_labels, list, "Translation result for Sinhala text should be a list.")
            self.assertGreater(len(translation_labels), 0, "Translation result list for Sinhala text should not be empty.")

            first_sign_dict = translation_labels[0]
            self.assertIn("sign", first_sign_dict, "Sign dictionary for Sinhala text should contain 'sign' key.")
            self.assertEqual(first_sign_dict["sign"], "lk-custom-001_Ayubowan",
                             f"Sinhala text translation label mismatch. Expected 'lk-custom-001_Ayubowan', got {first_sign_dict.get('sign')}")
            print("SUCCESS: Sinhala text 'ආයුබෝවන්' translation label matches expected.")

        except Exception as e:
            import traceback
            traceback.print_exc()
            self.fail(f"Error during Sinhala text translation test: {e}")

    def test_04_translation_of_unknown_word(self):
        """Tests translation of an unknown word to see fallback behavior."""
        print("\n--- Test 4: Translation of an Unknown Word ---")
        try:
            model = ConcatenativeSynthesis(
                text_language="english",
                sign_language="sinhala-sl",
                sign_format="label"
            )
            unknown_text = "UnknownUnseenWord"
            print(f"Attempting to translate unknown text: '{unknown_text}'")
            translation_labels = model.translate(unknown_text)
            print(f"Translation result for unknown text (labels): {translation_labels}")

            self.assertIsNotNone(translation_labels)
            self.assertIsInstance(translation_labels, list)
            self.assertGreater(len(translation_labels), 0)

            # Expected behavior for unknown words depends on SinhalaSignLanguage.tokens_to_sign_dicts
            # and its mapping rules (e.g., CharacterByCharacterMappingRule or default UNK_ prefix).
            # If CharacterByCharacterMappingRule is active and SINHALA_CHARACTERS_SIGN_MAPPING is empty
            # or doesn't cover English letters, it might fall through to the UNK_ prefix.
            # The current SinhalaSignLanguage has CharacterByCharacter for Sinhala, then Lambda for numbers.
            # An unknown English word might not be caught by these and fall to the default "UNK_"
            
            # Let's assume it will be prefixed with UNK_ if no character-by-character for English.
            # The base SignLanguage.tokens_to_sign_dicts appends UNK_ if no rule applies.
            # The custom SinhalaSignLanguage also has this fallback.
            
            first_sign_dict = translation_labels[0]
            self.assertIn("sign", first_sign_dict)
            self.assertTrue(first_sign_dict["sign"].startswith("UNK_"),
                            f"Expected unknown word sign to start with 'UNK_', got {first_sign_dict['sign']}")
            self.assertEqual(first_sign_dict["sign"], f"UNK_{unknown_text}",
                             f"Expected unknown word sign to be 'UNK_{unknown_text}', got {first_sign_dict['sign']}")
            print(f"SUCCESS: Unknown word '{unknown_text}' handled as expected (got '{first_sign_dict['sign']}').")

        except Exception as e:
            import traceback
            traceback.print_exc()
            self.fail(f"Error during unknown word translation test: {e}")


if __name__ == "__main__":
    print("Running Sinhala Sign Language Tests using unittest...")
    # To run from the `backend_python/sign-language-translator/` directory:
    # python -m unittest tests.test_sinhala_sl
    # Or, if this script is run directly (less common for unittest):
    # python tests/test_sinhala_sl.py
    unittest.main(verbosity=2)
