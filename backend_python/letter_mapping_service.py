"""
Letter Mapping Service for Sinhala Sign Language
Integrates landmark files from the Handsigns folder for letter-based sign translation
"""
import os
import json
import logging
from typing import Dict, List, Optional, Any

# Define Sinhala character sets based on Unicode standards and the paper
SINHALA_CONSONANTS = {
    'ක', 'ඛ', 'ග', 'ඝ', 'ങ', 'ච', 'ඡ', 'ජ', 'ඣ', 'ඤ', 'ට', 'ඨ', 'ඩ', 'ඪ', 'ණ',
    'ත', 'ථ', 'ද', 'ධ', 'න', 'ප', 'ඵ', 'බ', 'භ', 'ම', 'ය', 'ර', 'ල', 'ව',
    'ශ', 'ෂ', 'ස', 'හ', 'ළ', 'ෆ'
}
SINHALA_VOWEL_MODIFIERS = {
    'ා': 'ආ', 'ැ': 'ඇ', 'ෑ': 'ඈ', 'ි': 'ඉ', 'ී': 'ඊ', 'ු': 'උ', 'ූ': 'ඌ',
    'ෘ': 'ඍ', 'ෙ': 'එ', 'ේ': 'ඒ', 'ෛ': 'ඓ', 'ො': 'ඔ', 'ෝ': 'ඕ', 'ෞ': 'ඖ',
    'ෲ': 'ඎ'
}
SINHALA_INDEPENDENT_VOWELS = {
    'අ', 'ආ', 'ඇ', 'ඈ', 'ඉ', 'ඊ', 'උ', 'ඌ', 'ඍ', 'ඎ', 'එ', 'ඒ', 'ඓ', 'ඔ', 'ඕ', 'ඖ'
}
HAL_KIRIMA = '්'

class LetterMappingService:
    """
    Service to handle letter-based sign mapping using landmark files
    from the assets/datasets/output_landmarks folder
    """
    
    def __init__(self, landmarks_dir: str = None):
        """
        Initialize the letter mapping service
        
        Args:
            landmarks_dir: Path to the output_landmarks directory
        """
        if landmarks_dir is None:
            # Default path to landmarks directory
            landmarks_dir = os.path.join(
                os.path.dirname(__file__),
                "sign-language-translator",
                "sign_language_translator",
                "assets",
                "datasets", 
                "output_landmarks"
            )
        
        self.landmarks_dir = landmarks_dir
        self.letter_landmarks: Dict[str, Any] = {}
        self._load_letter_landmarks()
        
    def _load_letter_landmarks(self):
        """Load all letter landmark files from the directory"""
        if not os.path.exists(self.landmarks_dir):
            logging.error(f"Landmarks directory not found: {self.landmarks_dir}")
            return
            
        for filename in os.listdir(self.landmarks_dir):
            if filename.endswith('.json'):
                letter = filename.replace('.json', '')
                filepath = os.path.join(self.landmarks_dir, filename)
                
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        landmark_data = json.load(f)
                        self.letter_landmarks[letter] = landmark_data
                        logging.debug(f"Loaded landmarks for letter: {letter}")
                except Exception as e:
                    logging.error(f"Failed to load landmarks for {letter}: {e}")
                    
        logging.info(f"Loaded {len(self.letter_landmarks)} letter landmarks")
    
    def get_letter_landmark(self, letter: str) -> Optional[Dict]:
        """
        Get landmark data for a specific letter
        
        Args:
            letter: Sinhala letter to get landmarks for
            
        Returns:
            Dictionary containing landmark data or None if not found
        """
        return self.letter_landmarks.get(letter)
    
    def break_word_to_letters(self, word: str) -> List[str]:
        """
        Break a Sinhala word into individual phonetic components based on the
        standard phonetic pronunciation mechanism described in sign language research.
        e.g., 'ක' (ka) -> ['ක්', 'අ']
              'කී' (ki) -> ['ක්', 'ඊ']
        """
        decomposed = []
        i = 0
        n = len(word)

        while i < n:
            char = word[i]

            if char in SINHALA_CONSONANTS:
                consonant = char
                i += 1
                
                # Look ahead for modifiers
                if i < n:
                    next_char = word[i]
                    
                    if next_char in SINHALA_VOWEL_MODIFIERS:
                        # Consonant + Vowel Modifier (e.g., කා, කි, කෙ)
                        base_consonant_with_hal = consonant + HAL_KIRIMA
                        standalone_vowel = SINHALA_VOWEL_MODIFIERS[next_char]
                        decomposed.extend([base_consonant_with_hal, standalone_vowel])
                        i += 1
                    elif next_char == HAL_KIRIMA:
                        # Pure consonant (e.g., ක්)
                        decomposed.append(consonant + HAL_KIRIMA)
                        i += 1
                    else:
                        # Consonant with implicit 'a' vowel sound
                        base_consonant_with_hal = consonant + HAL_KIRIMA
                        decomposed.extend([base_consonant_with_hal, 'අ'])
                else:
                    # Consonant at the end of the word, also has implicit 'a'
                    base_consonant_with_hal = consonant + HAL_KIRIMA
                    decomposed.extend([base_consonant_with_hal, 'අ'])

            elif char in SINHALA_INDEPENDENT_VOWELS:
                # Standalone vowel (e.g., අ, ඉ, එ)
                decomposed.append(char)
                i += 1
            else:
                # Could be punctuation, a number, ZWJ, or an unhandled character.
                # Just append it as is and let the next stage handle it.
                decomposed.append(char)
                i += 1
                
        return decomposed
    
    def get_word_as_letter_sequence(self, word: str) -> List[Dict]:
        """
        Convert a word to a sequence of letter sign representations
        
        Args:
            word: Word to convert to letter signs
            
        Returns:
            List of sign dictionaries for each letter
        """
        letters = self.break_word_to_letters(word)
        letter_signs = []
        
        for letter in letters:
            landmark_data = self.get_letter_landmark(letter)
            if landmark_data:
                # Create sign dictionary format compatible with existing system
                sign_dict = {
                    "label": f"letter_{letter}",
                    "landmark_data": landmark_data,
                    "media_type": "landmarks",
                    "letter": letter
                }
                letter_signs.append(sign_dict)
            else:
                logging.warning(f"No landmark data found for letter: {letter}")
                # Add placeholder or skip
                letter_signs.append({
                    "label": f"unknown_letter_{letter}",
                    "landmark_data": None,
                    "media_type": "landmarks", 
                    "letter": letter
                })
        
        return letter_signs
    
    def is_letter_available(self, letter: str) -> bool:
        """
        Check if landmark data is available for a specific letter
        
        Args:
            letter: Letter to check
            
        Returns:
            True if landmark data exists, False otherwise
        """
        return letter in self.letter_landmarks
    
    def get_available_letters(self) -> List[str]:
        """
        Get list of all available letters with landmark data
        
        Returns:
            List of available letters
        """
        return list(self.letter_landmarks.keys())

# Global instance for easy access
_letter_mapping_service = None

def get_letter_mapping_service() -> LetterMappingService:
    """Get singleton instance of LetterMappingService"""
    global _letter_mapping_service
    if _letter_mapping_service is None:
        _letter_mapping_service = LetterMappingService()
    return _letter_mapping_service
