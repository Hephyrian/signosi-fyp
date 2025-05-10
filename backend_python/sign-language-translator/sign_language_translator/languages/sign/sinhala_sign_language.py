"""Defines a class for constructing Sinhala Sign Language from text using rules."""

import re
import random # If needed for rule selection
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
        super().__init__()

        # Load vocabulary specific to Sinhala Sign Language
        self.vocab = Vocab(
            language_codes_or_regex=["si", "en"], # Match keys in your mapping's "text" field
            collection_name_or_regex="lk-custom-dictionary-mapping.json", # Points to your custom mapping
            data_root_dir=Assets.ROOT_DIR,
        )

        self.word_to_sign_dict: Dict[str, Dict] = {}
        # This part assumes Vocab populates an attribute like `word_to_parsed_data`
        # where each item contains necessary info including the sign labels (unique IDs).
        # The exact attribute name and structure from Vocab needs verification for custom JSON.
        # Let's assume `self.vocab.get_word_to_sign_sequences_map()` is a method that returns
        # a dict like: {"word": [["label1_seq1_part1", "label1_seq1_part2"], ["label1_seq2_part1"]]}
        # For now, we'll use a placeholder logic that needs to be aligned with Vocab's actual output.

        # Hypothetical: Vocab provides a direct word -> list of label sequences
        # (where a sequence is a list of sign labels for a single meaning of the word)
        # e.g. {"hello": [["lk-custom-001_Hello"]], "book": [["lk-custom-002_Book"]]}
        # This structure is what _make_equal_weight_sign_dict expects for its 'signs' argument.
        
        # Attempt to populate word_to_sign_dict from vocab.
        # This is a critical section that depends heavily on how Vocab processes
        # your 'lk-custom-dictionary-mapping.json'.
        # You might need to inspect Vocab's code or debug its output.
        # For example, if vocab.word_to_labels provides {word: ["label1", "label2"]} for multiple variants of a word
        # or {word: "primary_label"}
        
        # Let's assume vocab has an attribute `word_to_sign_options` which is a dictionary:
        # {
        #    "word_from_mapping_text_field": [ # list of options for this word
        #        ["lk-custom-ID_Gloss"],      # option 1: a sequence of 1 sign label
        #        ["lk-custom-ID2_Gloss_part1", "lk-custom-ID2_Gloss_part2"] # option 2: sequence of 2 labels
        #    ], ...
        # }
        # This is what self._make_equal_weight_sign_dict expects as its `signs` argument.
        # The `Vocab` class would need to parse your `lk-custom-dictionary-mapping.json`
        # to produce this structure, associating words (from "text.si", "text.en")
        # with their corresponding media labels (derived from the top-level key like "lk-custom-001_Ayubowan").

        # Placeholder: Iterate through the mapping JSON directly if Vocab doesn't provide a ready map.
        # This is not ideal as Vocab should be the source of truth.
        # You should aim to make Vocab load your JSON into a usable structure.
        _temp_word_to_labels = {}
        if hasattr(self.vocab, 'data') and isinstance(self.vocab.data, dict):
            for label, mapping_data in self.vocab.data.items(): # self.vocab.data is the loaded JSON
                if "text" in mapping_data and isinstance(mapping_data["text"], dict):
                    # The label itself (e.g., "lk-custom-001_Ayubowan") is the sign identifier
                    sign_sequence = [label] # Assuming one sign per word for dictionary entries
                    for lang_code, text_list in mapping_data["text"].items():
                        if isinstance(text_list, list):
                            for text_word in text_list:
                                _temp_word_to_labels.setdefault(text_word.lower(), [])
                                if sign_sequence not in _temp_word_to_labels[text_word.lower()]:
                                     _temp_word_to_labels[text_word.lower()].append(sign_sequence)
        
        for word, sequences in _temp_word_to_labels.items():
            if sequences:
                self.word_to_sign_dict[word] = self._make_equal_weight_sign_dict(sequences)


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
        for token, tag, context in zip(tokens, tags, contexts):
            try:
                # _apply_rules expects a single token and returns a list of sign_dicts for that token
                # (often just one dict, but rules like number chunking can produce multiple)
                token_sign_dicts = self._apply_rules(token, tag, context)
                sign_dicts_list.extend(token_sign_dicts)
            except ValueError as e:
                # print(f"Warning: Could not map token '{token}' using defined rules: {e}")
                # Fallback: attempt to spell if it's an unknown word and spelling rule exists
                if self._sinhala_spelling_rule.is_applicable(token.lower(), Tags.UNKNOWN, context):
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
        for rule in self.mapping_rules:
            if rule.is_applicable(token.lower(), tag, context):
                return rule.apply(token.lower()) # apply() should return a list of sign_dicts

        raise ValueError(f"No applicable rule found for token '{token}'.")


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
            map_dict={
                w: [sd] for w, sd in self.word_to_sign_dict.items()
                if self.SignDictKeys.SIGNS.value in sd and self.SignDictKeys.WEIGHTS.value in sd
            },
            priority=priority
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
            character_to_sign_dict_map=sinhala_letter_signs,
            applicable_tags={Tags.UNKNOWN, Tags.NAME, Tags.DEFAULT}, # When to apply spelling
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
