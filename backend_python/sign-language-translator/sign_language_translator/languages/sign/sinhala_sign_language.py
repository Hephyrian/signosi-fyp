"""Defines a class for constructing Sinhala Sign Language from text using rules."""

import re
import random # If needed for rule selection
import logging # <-- Add logging import
import os # <-- Add os import
import json # <-- Add json import
from typing import Any, Dict, Iterable, List, Optional, Tuple, Union

from sign_language_translator.config.assets import Assets
# from sign_language_translator.config.enums import SignLanguages # If we add SINHALA_SIGN_LANGUAGE_NAME to an enum
from sign_language_translator.languages.sign.mapping_rules import (
    CharacterByCharacterMappingRule,
    DirectMappingRule,
    LambdaMappingRule,
    MappingRule,
)
from sign_language_translator.languages.sign.sign_language import SignLanguage
from sign_language_translator.languages.vocab import Vocab
from sign_language_translator.text import Tags # For tagging tokens like NUMBER, NAME etc.

# Define a name for Sinhala Sign Language
SINHALA_SIGN_LANGUAGE_NAME = "sinhala-sl"

class SinhalaSignLanguage(SignLanguage):
    """
    A class representing Sinhala Sign Language (SLSL).
    Provides methods for converting text tokens to sign dictionaries and restructuring sentences
    according to SLSL grammar.
    """

    STOPWORDS = {"සහ", "හා", "වෙත", "වෙතට", "තුළ", "ነው", "වේ"} # Example Sinhala stopwords (and, to, in, is)

    @staticmethod
    def name() -> str:
        return SINHALA_SIGN_LANGUAGE_NAME

    def __init__(self) -> None:
        logging.info("SinhalaSignLanguage: Initializing instance...")
        super().__init__()

        # Load custom Sinhala vocabulary directly
        self.word_to_sign_dict: Dict[str, Dict] = {}
        _temp_word_to_labels = {}
        
        custom_mapping_filename = "lk-dictionary-mapping.json"
        # Assets.ROOT_DIR should point to 'sign_language_translator/assets/'
        custom_mapping_path = os.path.join(Assets.ROOT_DIR, custom_mapping_filename)
        logging.info(f"SinhalaSignLanguage: Attempting to load custom mapping from: {custom_mapping_path}")

        loaded_custom_data = {}
        if os.path.exists(custom_mapping_path):
            try:
                with open(custom_mapping_path, "r", encoding="utf-8") as f:
                    loaded_custom_data = json.load(f)
                logging.info(f"SinhalaSignLanguage: Successfully loaded custom mapping with {len(loaded_custom_data)} top-level entries from {custom_mapping_path}")
            except Exception as e:
                logging.error(f"SinhalaSignLanguage: Failed to load or parse custom mapping from {custom_mapping_path}: {e}", exc_info=True)
        else:
            logging.warning(f"SinhalaSignLanguage: Custom mapping file not found at {custom_mapping_path}")

        # Populate _temp_word_to_labels using the directly loaded_custom_data
        if isinstance(loaded_custom_data, dict):
            for label, mapping_data in loaded_custom_data.items():
                if "text" in mapping_data and isinstance(mapping_data["text"], dict):
                    sign_sequence = [label] # Assuming one sign per word for dictionary entries
                    # <<< FOCUS ONLY ON SINHALA ('si') ENTRIES >>>
                    if "si" in mapping_data["text"] and isinstance(mapping_data["text"]["si"], list):
                        for text_word in mapping_data["text"]["si"]:
                            # <<< ADD SPECIFIC LOGGING FOR THE TARGET WORD 'පොත' >>>
                            if text_word == "පොත":
                                logging.info(f"SinhalaSignLanguage: Found target word '{text_word}' in JSON under label '{label}'. Preparing to add to _temp_word_to_labels.")
                            
                            word_lower = text_word.lower()
                            logging.debug(f"SinhalaSignLanguage: Processing SINHALA word '{text_word}' (lowercase: '{word_lower}') for label '{label}'")
                            _temp_word_to_labels.setdefault(word_lower, [])
                            if sign_sequence not in _temp_word_to_labels[word_lower]:
                                _temp_word_to_labels[word_lower].append(sign_sequence)
                                logging.debug(f"SinhalaSignLanguage: Added sequence {sign_sequence} for Sinhala word '{word_lower}'")
                            else:
                                logging.debug(f"SinhalaSignLanguage: Sequence {sign_sequence} already exists for Sinhala word '{word_lower}'")
                    else:
                        logging.debug(f"SinhalaSignLanguage: No 'si' text list found for label '{label}'. Skipping Sinhala word processing for this label.")
        
        logging.info(f"SinhalaSignLanguage: Populating final word_to_sign_dict from _temp_word_to_labels ({len(_temp_word_to_labels)} entries)...")
        for word, sequences in _temp_word_to_labels.items():
            if sequences:
                try:
                    sign_dict_entry = self._make_equal_weight_sign_dict(sequences)
                    self.word_to_sign_dict[word] = sign_dict_entry
                    logging.debug(f"SinhalaSignLanguage: Added entry to word_to_sign_dict for word '{word}': {sign_dict_entry}")
                except ZeroDivisionError:
                    # Handle case where division by zero might occur due to empty or invalid data
                    sign_dict_entry = {"signs": sequences, "weights": [1.0 / len(sequences) if len(sequences) > 0 else 0.0 for _ in sequences]}
                    self.word_to_sign_dict[word] = sign_dict_entry
                    logging.warning(f"SinhalaSignLanguage: Handled ZeroDivisionError for word '{word}', created entry: {sign_dict_entry}")
                except Exception as e:
                     logging.error(f"SinhalaSignLanguage: Error processing word '{word}' for final dict: {e}", exc_info=True)
            else:
                 logging.warning(f"SinhalaSignLanguage: Skipping word '{word}' due to empty sequences.")


        # Log dictionary status
        logging.info(f"SinhalaSignLanguage: word_to_sign_dict population complete. Final size: {len(self.word_to_sign_dict)} entries.")
        # Check specifically for the lowercase version as keys are lowercased during population
        target_word = "පොත"
        if target_word.lower() in self.word_to_sign_dict:
            logging.info(f"SinhalaSignLanguage: Entry for '{target_word}' (lowercase) found in word_to_sign_dict: {self.word_to_sign_dict[target_word.lower()]}")
        else:
            logging.warning(f"SinhalaSignLanguage: Entry for '{target_word}' (lowercase) NOT found in word_to_sign_dict.")


        # Define mapping rules
        self._direct_rule = self.__get_direct_mapping_rule(priority=1)
        self._sinhala_spelling_rule = self.__get_sinhala_spelling_rule(priority=5)
        self._number_rule = self.__get_number_rule(priority=3)

        self.mapping_rules: List[MappingRule] = sorted(
            [
                self._direct_rule,
                self._sinhala_spelling_rule,
                self._number_rule,
            ],
            key=lambda rule: rule.priority
        )

    def tokens_to_sign_dicts(
        self,
        tokens: Iterable[str],
        tags: Optional[Iterable[Any]] = None,
        contexts: Optional[Iterable[Any]] = None,
    ) -> List[Dict[str, Union[List[List[str]], List[float]]]]:
        if isinstance(tokens, str):
            tokens = [tokens]
        if not tags:
            tags = [Tags.DEFAULT for _ in tokens]
        if not contexts:
            contexts = [None for _ in tokens]

        sign_dicts_list = []
        logging.debug(f"SinhalaSignLanguage.tokens_to_sign_dicts: Received tokens: {list(tokens)}, tags: {list(tags)}")
        for token, tag, context in zip(tokens, tags, contexts):
            logging.debug(f"SinhalaSignLanguage.tokens_to_sign_dicts: Processing token='{token}', tag='{tag}'")
            try:
                # _apply_rules expects a single token and returns a list of sign_dicts for that token
                # (often just one dict, but rules like number chunking can produce multiple)
                token_sign_dicts = self._apply_rules(token, tag, context)
                logging.debug(f"SinhalaSignLanguage.tokens_to_sign_dicts: For token='{token}', _apply_rules returned: {token_sign_dicts}")
                sign_dicts_list.extend(token_sign_dicts)
            except ValueError as e:
                logging.warning(f"SinhalaSignLanguage.tokens_to_sign_dicts: ValueError for token='{token}': {e}")
                # print(f"Warning: Could not map token '{token}' using defined rules: {e}")
                # Fallback: attempt to spell if it's an unknown word and spelling rule exists
                if self._sinhala_spelling_rule.is_applicable(token.lower(), Tags.DEFAULT, context):
                    try:
                        # print(f"Attempting to spell token: {token}")
                        spelling_sign_dicts = self._sinhala_spelling_rule.apply(token.lower())
                        sign_dicts_list.extend(spelling_sign_dicts)
                        continue
                    except Exception as spell_e:
                        # print(f"Spelling also failed for '{token}': {spell_e}")
                        pass # Fall through to raise original error or handle as truly unknown
                
                # If no rule (including spelling fallback) worked, raise or return placeholder
                # For now, re-raising to make it explicit.
                raise ValueError(f"No SLSL sign/rule could be inferred for token '{token}'. Original error: {e}")

        return sign_dicts_list

    def _apply_rules(
        self, token: str, tag=None, context=None
    ) -> List[Dict[str, Union[List[List[str]], List[float]]]]:
        # In PakistanSL, multiple rules of same priority can be chosen randomly.
        # Here, we take the first one that applies based on sorted rule list.
        token_lower = token.lower()
        print(f"[DEBUG] SinhalaSignLanguage._apply_rules: START for token='{token}', token_lower='{token_lower}', tag='{tag}'")
        logging.info(f"SinhalaSignLanguage: Applying rules for token: '{token}' (lowercase: '{token_lower}'), tag: {tag}")
        for rule in self.mapping_rules:
            print(f"[DEBUG] SinhalaSignLanguage._apply_rules: Checking rule: {rule.__class__.__name__} for token_lower='{token_lower}'")
            logging.debug(f"SinhalaSignLanguage: Checking rule: {rule.__class__.__name__} for token '{token_lower}'")
            applicable = rule.is_applicable(token_lower, tag, context)
            print(f"[DEBUG] SinhalaSignLanguage._apply_rules: Rule {rule.__class__.__name__} applicable: {applicable}")
            if applicable:
                logging.info(f"SinhalaSignLanguage: Rule '{rule.__class__.__name__}' is applicable for token '{token_lower}'. Applying...")
                try:
                    result = rule.apply(token_lower) # apply() should return a list of sign_dicts
                    print(f"[DEBUG] SinhalaSignLanguage._apply_rules: Rule {rule.__class__.__name__} applied. Result: {result}")
                    logging.info(f"SinhalaSignLanguage: Rule '{rule.__class__.__name__}' applied successfully for '{token_lower}'. Result: {result}")
                    return result
                except Exception as e:
                    print(f"[DEBUG] SinhalaSignLanguage._apply_rules: EXCEPTION applying rule {rule.__class__.__name__}: {e}")
                    logging.error(f"SinhalaSignLanguage: Error applying rule '{rule.__class__.__name__}' for token '{token_lower}': {e}", exc_info=True)
                    # Optionally re-raise or handle, for now, let it fall through to the general ValueError

        print(f"[DEBUG] SinhalaSignLanguage._apply_rules: No applicable rule found for token_lower='{token_lower}'. Raising ValueError.")
        logging.warning(f"SinhalaSignLanguage: No applicable rule found for token '{token}' (lowercase: '{token_lower}').")
        raise ValueError(f"No applicable rule found for token '{token}'.")

    # <<< REMOVE THIS DUPLICATE METHOD DEFINITION >>>
    # def tokens_to_sign_dicts(
    #     self,
    #     tokens: Iterable[str],
    #     tags: Optional[Iterable[Any]] = None,
    #     contexts: Optional[Iterable[Any]] = None,
    # ) -> List[Dict[str, Union[List[List[str]], List[float]]]]:
    #     if isinstance(tokens, str):
    #         tokens = [tokens]
    #     if not tags:
    #         tags = [Tags.DEFAULT for _ in tokens]
    #     if not contexts:
    #         contexts = [None for _ in tokens]

    #     sign_dicts_list = []
    #     print(f"[DEBUG] SinhalaSignLanguage.tokens_to_sign_dicts: START. Received tokens: {list(tokens)}, tags: {list(tags)}")
    #     logging.debug(f"SinhalaSignLanguage.tokens_to_sign_dicts: Received tokens: {list(tokens)}, tags: {list(tags)}")
    #     for token, tag, context in zip(tokens, tags, contexts):
    #         print(f"[DEBUG] SinhalaSignLanguage.tokens_to_sign_dicts: Processing token='{token}', tag='{tag}'")
    #         logging.debug(f"SinhalaSignLanguage.tokens_to_sign_dicts: Processing token='{token}', tag='{tag}'")
    #         try:
    #             # _apply_rules expects a single token and returns a list of sign_dicts for that token
    #             # (often just one dict, but rules like number chunking can produce multiple)
    #             token_sign_dicts = self._apply_rules(token, tag, context)
    #             print(f"[DEBUG] SinhalaSignLanguage.tokens_to_sign_dicts: For token='{token}', _apply_rules returned: {token_sign_dicts}")
    #             logging.debug(f"SinhalaSignLanguage.tokens_to_sign_dicts: For token='{token}', _apply_rules returned: {token_sign_dicts}")
    #             sign_dicts_list.extend(token_sign_dicts)
    #         except ValueError as e:
    #             print(f"[DEBUG] SinhalaSignLanguage.tokens_to_sign_dicts: ValueError for token='{token}': {e}")
    #             logging.warning(f"SinhalaSignLanguage.tokens_to_sign_dicts: ValueError for token='{token}': {e}")
    #             # print(f"Warning: Could not map token '{token}' using defined rules: {e}")
    #             # Fallback: attempt to spell if it's an unknown word and spelling rule exists
    #             if self._sinhala_spelling_rule.is_applicable(token.lower(), Tags.DEFAULT, context):
    #                 try:
    #                     # print(f"Attempting to spell token: {token}")
    #                     print(f"[DEBUG] SinhalaSignLanguage.tokens_to_sign_dicts: Attempting fallback spelling for token='{token}'")
    #                     spelling_sign_dicts = self._sinhala_spelling_rule.apply(token.lower())
    #                     print(f"[DEBUG] SinhalaSignLanguage.tokens_to__sign_dicts: Fallback spelling returned: {spelling_sign_dicts}")
    #                     sign_dicts_list.extend(spelling_sign_dicts)
    #                     continue
    #                 except Exception as spell_e:
    #                     print(f"[DEBUG] SinhalaSignLanguage.tokens_to_sign_dicts: Fallback spelling EXCEPTION for '{token}': {spell_e}")
    #                     # print(f"Spelling also failed for '{token}': {spell_e}")
    #                     pass # Fall through to raise original error or handle as truly unknown
                
    #             # If no rule (including spelling fallback) worked, raise or return placeholder
    #             # For now, re-raising to make it explicit.
    #             print(f"[DEBUG] SinhalaSignLanguage.tokens_to_sign_dicts: No rule or fallback worked for token='{token}'. Raising ValueError.")
    #             raise ValueError(f"No SLSL sign/rule could be inferred for token '{token}'. Original error: {e}")
    #     print(f"[DEBUG] SinhalaSignLanguage.tokens_to_sign_dicts: END. Returning sign_dicts_list: {sign_dicts_list}")
    #     return sign_dicts_list
    # <<< END OF REMOVAL >>>

    def restructure_sentence(
        self,
        sentence: Iterable[str],
        tags: Optional[Iterable[Any]] = None,
        contexts: Optional[Iterable[Any]] = None,
    ) -> List[Dict[str, Union[List[List[str]], List[float]]]]:
        if isinstance(tokens, str):
            tokens = [tokens]
        if not tags:
            tags = [Tags.DEFAULT for _ in tokens]
        if not contexts:
            contexts = [None for _ in tokens]

        sign_dicts_list = []
        print(f"[DEBUG] SinhalaSignLanguage.tokens_to_sign_dicts: START. Received tokens: {list(tokens)}, tags: {list(tags)}")
        logging.debug(f"SinhalaSignLanguage.tokens_to_sign_dicts: Received tokens: {list(tokens)}, tags: {list(tags)}")
        for token, tag, context in zip(tokens, tags, contexts):
            print(f"[DEBUG] SinhalaSignLanguage.tokens_to_sign_dicts: Processing token='{token}', tag='{tag}'")
            logging.debug(f"SinhalaSignLanguage.tokens_to_sign_dicts: Processing token='{token}', tag='{tag}'")
            try:
                # _apply_rules expects a single token and returns a list of sign_dicts for that token
                # (often just one dict, but rules like number chunking can produce multiple)
                token_sign_dicts = self._apply_rules(token, tag, context)
                print(f"[DEBUG] SinhalaSignLanguage.tokens_to_sign_dicts: For token='{token}', _apply_rules returned: {token_sign_dicts}")
                logging.debug(f"SinhalaSignLanguage.tokens_to_sign_dicts: For token='{token}', _apply_rules returned: {token_sign_dicts}")
                sign_dicts_list.extend(token_sign_dicts)
            except ValueError as e:
                print(f"[DEBUG] SinhalaSignLanguage.tokens_to_sign_dicts: ValueError for token='{token}': {e}")
                logging.warning(f"SinhalaSignLanguage.tokens_to_sign_dicts: ValueError for token='{token}': {e}")
                # print(f"Warning: Could not map token '{token}' using defined rules: {e}")
                # Fallback: attempt to spell if it's an unknown word and spelling rule exists
                if self._sinhala_spelling_rule.is_applicable(token.lower(), Tags.DEFAULT, context):
                    try:
                        # print(f"Attempting to spell token: {token}")
                        print(f"[DEBUG] SinhalaSignLanguage.tokens_to_sign_dicts: Attempting fallback spelling for token='{token}'")
                        spelling_sign_dicts = self._sinhala_spelling_rule.apply(token.lower())
                        print(f"[DEBUG] SinhalaSignLanguage.tokens_to__sign_dicts: Fallback spelling returned: {spelling_sign_dicts}")
                        sign_dicts_list.extend(spelling_sign_dicts)
                        continue
                    except Exception as spell_e:
                        print(f"[DEBUG] SinhalaSignLanguage.tokens_to_sign_dicts: Fallback spelling EXCEPTION for '{token}': {spell_e}")
                        # print(f"Spelling also failed for '{token}': {spell_e}")
                        pass # Fall through to raise original error or handle as truly unknown
                
                # If no rule (including spelling fallback) worked, raise or return placeholder
                # For now, re-raising to make it explicit.
                print(f"[DEBUG] SinhalaSignLanguage.tokens_to_sign_dicts: No rule or fallback worked for token='{token}'. Raising ValueError.")
                raise ValueError(f"No SLSL sign/rule could be inferred for token '{token}'. Original error: {e}")
        print(f"[DEBUG] SinhalaSignLanguage.tokens_to_sign_dicts: END. Returning sign_dicts_list: {sign_dicts_list}")
        return sign_dicts_list

    def restructure_sentence(
        self,
        sentence: Iterable[str],
        tags: Optional[Iterable[Any]] = None,
        contexts: Optional[Iterable[Any]] = None,
    ) -> Tuple[Iterable[str], Iterable[Any], Iterable[Any]]:
        if isinstance(sentence, str):
            sentence = [sentence] # Ensure iterable
        
        tags = [Tags.DEFAULT for _ in sentence] if tags is None else list(tags)
        contexts = [None for _ in sentence] if contexts is None else list(contexts)

        restructured_sentence = []
        restructured_tags = []
        restructured_contexts = []

        for i, token in enumerate(sentence):
            token_lower = token.lower()
            current_tag = tags[i] if i < len(tags) else Tags.DEFAULT
            current_context = contexts[i] if i < len(contexts) else None

            if token_lower in self.STOPWORDS:
                continue
            if current_tag in {Tags.SPACE, Tags.PUNCTUATION}:
                continue
            
            if current_tag == Tags.NUMBER and isinstance(token, str):
                token = token.replace(",", "") # Basic normalization for numbers
            
            # Placeholder for actual SLSL grammar restructuring
            # e.g., SOV word order, handling of questions, negation, etc.
            # This requires linguistic expertise in SLSL.

            restructured_sentence.append(token)
            restructured_tags.append(current_tag)
            restructured_contexts.append(current_context)
        
        return restructured_sentence, restructured_tags, restructured_contexts

    def __get_direct_mapping_rule(self, priority=1):
        return DirectMappingRule(
            priority=priority,
            token_to_object={
                w: [sd] for w, sd in self.word_to_sign_dict.items()
                if self.SignDictKeys.SIGNS.value in sd and self.SignDictKeys.WEIGHTS.value in sd
            }
        )

    def __get_sinhala_spelling_rule(self, priority=5):
        # Assumes Sinhala alphabet characters are keys in self.word_to_sign_dict
        # e.g., self.word_to_sign_dict["අ"] = {"signs": [["lk-custom-S001_A"]], "weights": [1.0]}
        sinhala_letter_signs = {
            char: sign_dict
            for char, sign_dict in self.word_to_sign_dict.items()
            if len(char) == 1 and (0x0D80 <= ord(char) <= 0x0DFF) # Sinhala Unicode range
            and self.SignDictKeys.SIGNS.value in sign_dict # Ensure it's a valid sign_dict
        }
        
        if not sinhala_letter_signs:
            # Return a dummy rule that is never applicable if no letter signs are defined
            return LambdaMappingRule(is_applicable_function=lambda t, tg, c: False, apply_function=lambda t: [], priority=priority)

        return CharacterByCharacterMappingRule(
            token_to_object=sinhala_letter_signs,
            allowed_tags={Tags.DEFAULT, Tags.NAME}, # When to apply spelling
            priority=priority
        )

    def __get_number_rule(self, priority=3):
        # Assumes digits '0'-'9' are keys in self.word_to_sign_dict
        def chunk_number_simple(num_str: str) -> List[str]:
            # Basic: treats each character of the number string as a separate digit token
            # TODO: More advanced: handle multi-digit numbers, number words ("ten") if available
            return list(filter(str.isdigit, num_str))


        return LambdaMappingRule(
            is_applicable_function=lambda token, tag, context: (
                tag == Tags.NUMBER and
                all(digit in self.word_to_sign_dict for digit in chunk_number_simple(token))
            ),
            apply_function=lambda token_str: [
                 # Ensure that what's returned is a list of sign_dicts
                self.word_to_sign_dict[digit] for digit in chunk_number_simple(token_str)
                if digit in self.word_to_sign_dict # double check
            ],
            priority=priority
        )

    def __call__(
        self,
        tokens: Iterable[str],
        tags: Optional[Iterable[Any]] = None,
        contexts: Optional[Iterable[Any]] = None,
    ) -> List[Dict[str, Union[List[List[str]], List[float]]]]:
        restructured_tokens, restructured_tags, restructured_contexts = self.restructure_sentence(
            tokens, tags=tags, contexts=contexts
        )
        sign_dictionaries = self.tokens_to_sign_dicts(
            restructured_tokens, tags=restructured_tags, contexts=restructured_contexts
        )
        return sign_dictionaries
