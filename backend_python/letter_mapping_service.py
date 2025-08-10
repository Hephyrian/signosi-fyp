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
SINHALA_COMBINING_MARKS = set(SINHALA_VOWEL_MODIFIERS.keys()) | {HAL_KIRIMA}

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

    def break_word_to_main_letters(self, word: str) -> List[str]:
        """
        Break a Sinhala word into MAIN letters only, suitable for fallback where
        landmarks exist only for base consonants and independent vowels.

        Rules:
        - Consonant + any modifiers/virama -> emit only the base consonant
        - Independent vowels are emitted as-is
        - All combining marks (vowel modifiers, virama) are ignored
        - Other characters are skipped
        """
        main_letters: List[str] = []
        i = 0
        n = len(word)

        while i < n:
            char = word[i]

            if char in SINHALA_CONSONANTS:
                # Emit base consonant
                main_letters.append(char)
                i += 1
                # Skip any trailing combining marks (modifiers/virama)
                while i < n and (word[i] in SINHALA_COMBINING_MARKS):
                    i += 1
                continue

            if char in SINHALA_INDEPENDENT_VOWELS:
                main_letters.append(char)
                i += 1
                continue

            # Skip any other characters (punctuation, numbers, ZWJ, etc.)
            i += 1

        return main_letters
    
    def get_word_as_letter_sequence(self, word: str) -> List[Dict]:
        """
        Convert a word to a sequence of sign representations using base
        consonants plus independent vowels derived from modifiers (Option B).
        
        Args:
            word: Word to convert to letter signs
            
        Returns:
            List of sign dictionaries for each letter
        """
        # Use base consonants + independent vowels derived from modifiers
        letters = self._break_word_letters_option_b(word)
        logging.debug(f"[LetterMapping] OptionB letters for '{word}': {letters}")
        letter_signs = []
        
        for letter in letters:
            landmark_data = self.get_letter_landmark(letter)
            if landmark_data:
                # Prefer a fetchable path so frontend can load frames on demand
                landmark_path = f"/api/translate/landmark-data/{letter}.json"
                logging.debug(f"[LetterMapping] Mapped letter '{letter}' to landmark path: {landmark_path}")
                sign_dict = {
                    "label": f"letter_{letter}",
                    "landmark_data": landmark_path,
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
        
        try:
            sign_labels = [s.get("label", "unknown") for s in letter_signs]
            logging.debug(f"[LetterMapping] Final letter signs for '{word}': {sign_labels}")
        except Exception:
            pass

        return letter_signs

    def _break_word_letters_option_b(self, word: str) -> List[str]:
        """
        Break a Sinhala word into base consonants and independent vowels
        (Option B):
          - Consonant + vowel modifier -> [base consonant, independent vowel]
          - Consonant + virama (්)     -> [base consonant]
          - Consonant without modifier -> [base consonant] (implicit 'අ' omitted)
          - Independent vowels         -> [vowel]
        """
        normalized_word = self._normalize_prebase_vowel_signs(word)
        if normalized_word != word:
            logging.debug(f"[LetterMapping] Normalized '{word}' -> '{normalized_word}'")
        detailed_tokens = self.break_word_to_letters(normalized_word)
        logging.debug(f"[LetterMapping] Detailed tokens for '{normalized_word}': {detailed_tokens}")
        result_letters: List[str] = []

        i = 0
        m = len(detailed_tokens)
        while i < m:
            token = detailed_tokens[i]

            # Handle consonant-with-hal (e.g., 'ක්') by emitting base consonant
            if token.endswith(HAL_KIRIMA) and token[:-1] in SINHALA_CONSONANTS:
                base_consonant = token[:-1]

                # Look ahead to decide handling
                next_token = detailed_tokens[i + 1] if (i + 1) < m else None

                if next_token in SINHALA_INDEPENDENT_VOWELS:
                    # Consonant + vowel → emit base consonant and vowel (omit implicit 'අ')
                    if next_token == 'අ':
                        result_letters.append(base_consonant)
                    else:
                        result_letters.append(base_consonant)
                        result_letters.append(next_token)
                    i += 2  # consume consonant-with-hal and the vowel
                    continue
                else:
                    # Pure virama consonant (e.g., gemination or word-final): emit base consonant
                    result_letters.append(base_consonant)
                    i += 1
                    continue

            # Independent vowels
            if token in SINHALA_INDEPENDENT_VOWELS:
                result_letters.append(token)
                i += 1
                continue

            # Other characters (punctuation/numbers/etc.) pass through; may not map to landmarks
            result_letters.append(token)
            i += 1

        logging.debug(f"[LetterMapping] Result letters for '{normalized_word}': {result_letters}")
        return result_letters

    def _normalize_prebase_vowel_signs(self, word: str) -> str:
        """
        Normalize words where certain Sinhala vowel signs may appear before the
        base consonant in storage order by moving the sign after the consonant.

        Example: 'ො' + 'ක' -> 'ක' + 'ො'
        This helps downstream logic that expects consonant-then-modifier.
        """
        chars = list(word)
        i = 0
        n = len(chars)
        output: List[str] = []

        # Helper for combining common split vowel sequences into single signs
        def combine_split_vowel_signs(consonant: str, following: list[str]) -> tuple[list[str], int]:
            # Map known split sequences after a consonant to a single combining mark
            # e.g., 'ෙ' + 'ා' => 'ො' (o), 'ෙ' + 'ී' => 'ේ' (ee)
            if len(following) >= 2:
                first, second = following[0], following[1]
                if first == 'ෙ' and second == 'ා':
                    return [consonant, 'ො'], 2
                if first == 'ෙ' and second == 'ී':
                    return [consonant, 'ේ'], 2
            # Handle already-composed single signs after a consonant
            if len(following) >= 1:
                first = following[0]
                if first in {'ො', 'ෝ', 'ෞ'}:
                    return [consonant, first], 1
            if len(following) >= 1:
                first = following[0]
                if first == 'ෙ':
                    return [consonant, 'ෙ'], 1
            return [consonant], 0

        while i < n:
            current_char = chars[i]
            next_char = chars[i + 1] if (i + 1) < n else None

            # Case 1: Pre-base vowel sign 'ෙ' before a consonant (rare in stored order)
            if current_char == 'ෙ' and next_char in SINHALA_CONSONANTS:
                # Swap and also try to fold sequences like 'ෙ' + 'ා' into 'ො'
                consonant = next_char
                remaining = chars[i + 2 : i + 4]  # look ahead a couple
                combined, consumed = combine_split_vowel_signs(consonant, [current_char] + remaining)
                output.extend(combined)
                i += 2 + max(consumed - 1, 0)
                continue

            # Case 2: Consonant followed by split vowel sequence (common IME order)
            if current_char in SINHALA_CONSONANTS:
                remaining = chars[i + 1 : i + 4]
                combined, consumed = combine_split_vowel_signs(current_char, remaining)
                output.extend(combined)
                i += 1 + consumed
                continue

            # Default: passthrough
            output.append(current_char)
            i += 1

        return "".join(output)
    
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
