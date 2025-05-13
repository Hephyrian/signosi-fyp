# backend_python/app/services/sinhala_text_language.py

import sys
import os
from typing import Optional, List

# Ensure the sign_language_translator package is findable
# This might be redundant if translation_service.py already handles sys.path,
# but it's safer to include it if this module could be imported independently.
# Assuming this file is in backend_python/app/services/
# and sign-language-translator is in backend_python/sign-language-translator/
SERVICE_DIR = os.path.dirname(os.path.abspath(__file__))
APP_DIR = os.path.dirname(SERVICE_DIR)
BACKEND_PYTHON_DIR = os.path.dirname(APP_DIR)
SLT_PACKAGE_DIR = os.path.join(BACKEND_PYTHON_DIR, "sign-language-translator")

if SLT_PACKAGE_DIR not in sys.path:
    sys.path.insert(0, SLT_PACKAGE_DIR)

# Import TextLanguage directly from text_language module to avoid circular imports
try:
    from sign_language_translator.languages.text.text_language import TextLanguage
except ImportError as e:
    print(f"Error importing TextLanguage from sign_language_translator: {e}")
    print(f"SLT_PACKAGE_DIR: {SLT_PACKAGE_DIR}")
    print(f"sys.path: {sys.path}")
    TextLanguage = object  # Fallback to a dummy object to allow class definition

class SinhalaTextLanguage(TextLanguage):
    """
    Custom TextLanguage class for Sinhala.
    """
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        # Add any Sinhala-specific initialization here if needed
        # For example, loading custom tokenizers, normalizers, etc.
        self._name = "si"

    def preprocess(self, text: str) -> str:
        """
        Preprocesses the input Sinhala text.
        Converts to lowercase and filters characters based on self.allowed_characters.
        """
        if not isinstance(text, str):
            # Handle potential non-string input gracefully
            return ""

        # 1. Convert to lowercase
        processed_text = text.lower()

        # 2. Filter characters
        allowed = self.allowed_characters
        processed_text = "".join(char for char in processed_text if char in allowed)

        # 3. Optional: Add other normalization steps if needed (e.g., handling ZWJ/ZWNJ)

        # 4. Strip leading/trailing whitespace
        processed_text = processed_text.strip()

        return processed_text

    def tokenize(self, text: str) -> list[str]:
        """
        Tokenizes the input Sinhala text.
        Uses simple whitespace splitting for now.
        Ensures a list is always returned.
        """
        if not isinstance(text, str):
            return [] # Return empty list for non-string input

        # Simple whitespace tokenization
        tokens = text.split()

        # Return the list of tokens, even if it's empty
        return tokens

    @property
    def name(self) -> str:
        return "sinhala"

    @property
    def allowed_characters(self) -> set[str]:
        # Define allowed characters for Sinhala text
        # Includes basic consonants, vowels, vowel signs, and some punctuation
        sinhala_chars = set(
            "අආඇඈඉඊඋඌඍඎඏඐඑඒඓඔඕඖ"  # Independent Vowels
            "කඛගඝඞඟචඡජඣඤඥඦටඨඩඪණඬතථදධනඳපඵබභමයරලවශෂසහළෆ"  # Consonants
            "්ාැෑිීුූෘෙේෛොෝෞංඃ"  # Vowel signs (Dependent Vowels) and other marks
            "෴"  # Punctuation (Kunddaliya)
        )
        english_chars = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,!?")
        return english_chars | sinhala_chars

    def detokenize(self, tokens: list[str]) -> str:
        # Simple detokenization by joining tokens with space
        return " ".join(tokens)

    def sentence_tokenize(self, text: Optional[str]) -> List[str]:
        """Tokenizes the input Sinhala text into sentences."""
        if text is None:
            return []
        # Split by Sinhala full stop "。" (U+0D82) and standard period "."
        # Replace Sinhala full stop with standard period for consistent splitting
        # and ensure sentences are stripped of whitespace and non-empty.
        processed_text = text.replace("。", ".")
        sentences = [s.strip() for s in processed_text.split(".") if s.strip()]
        return sentences

    def tag(self, tokens: List[str]) -> List[str]:
        # Placeholder for part-of-speech tagging or other token classification
        return ["UNKNOWN" for _ in tokens]

    # Change return type hint to List[str] and return a flat list
    def get_tags(self, tokens: List[str]) -> List[str]: 
        # Placeholder for getting possible tags
        return ["UNKNOWN" for _ in tokens]

    def get_word_senses(self, token: str) -> List[str]:
        # Placeholder for word sense disambiguation
        return [token]

    @property
    def token_regex(self) -> str:
        # Basic regex for tokenization; refine for Sinhala if needed
        return r"\w+|[^\w\s]"

if __name__ == '__main__':
    # Example usage (for testing this module directly)
    try:
        sinhala_proc = SinhalaTextLanguage()
        print(f"Successfully initialized SinhalaTextLanguage with name: {sinhala_proc.name}")
        
        test_sentence = "මෙය සිංහල වාක්‍යයකි."
        preprocessed = sinhala_proc.preprocess(test_sentence)
        print(f"Original: {test_sentence}")
        print(f"Preprocessed: {preprocessed}")
        
        tokens = sinhala_proc.tokenize(preprocessed)
        print(f"Tokens: {tokens}")

    except Exception as e:
        print(f"Error during SinhalaTextLanguage test: {e}")
        traceback.print_exc()
