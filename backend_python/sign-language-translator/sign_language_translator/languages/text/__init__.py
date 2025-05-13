"""Module that contains Text Language Processors as classes to clean up, tokenize and tag texts of various languages."""

# First import the base class
from sign_language_translator.languages.text.text_language import TextLanguage

# Then import the language implementations
from sign_language_translator.languages.text.english import English
from sign_language_translator.languages.text.hindi import Hindi
from sign_language_translator.languages.text.sinhala_text_language import SinhalaTextLanguage
from sign_language_translator.languages.text.urdu import Urdu
from sign_language_translator.text.tagger import Tags

__all__ = [
    "TextLanguage",  # Add the base class to __all__
    "Urdu",
    "English",
    "Hindi",
    "SinhalaTextLanguage",
    "Tags",
]
