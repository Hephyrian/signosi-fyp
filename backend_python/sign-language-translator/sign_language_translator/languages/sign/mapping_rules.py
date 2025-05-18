"""
This module provides classes for mapping rules used in a mapping system.

The mapping system allows for mapping tokens to specific objects based on predefined rules.
The module includes abstract base classes for mapping rules and several concrete implementations.

Classes:
- MappingRule: Abstract base class for mapping rules.
- LambdaMappingRule: Mapping rule defined by lambda functions.
- DirectMappingRule: Mapping rule for supported words.
- CharacterByCharacterMappingRule: Mapping rule for character-by-character mapping.

Each mapping rule class defines the behavior of the rule,
including applicability checks and actions to be taken when the rule is applied.
"""

from abc import ABC, abstractmethod
from typing import Any, Callable, Dict, List, Set, Optional, Tuple, Union


class MappingRule(ABC):
    """
    Abstract base class for mapping rules.
    """

    @property
    @abstractmethod
    def priority(self) -> int:
        """
        Priority of the mapping rule.

        Returns:
            int: The priority of the mapping rule.
        """

    @abstractmethod
    def is_applicable(
        self,
        token: str,
        tag: Any = None,
        context: Any = None,
    ) -> bool:
        """
        Check if the mapping rule is applicable for the given token, tag, and context.

        Args:
            token (str): The token to be checked.
            tag (Any, optional): The tag associated with the token. Defaults to None.
            context (Any, optional): The context in which the token appears. Defaults to None.

        Returns:
            bool: True if the mapping rule is applicable, False otherwise.
        """

    @abstractmethod
    def apply(self, token: str) -> Any:
        """
        Apply the mapping rule to the given token. (i.e. map the given token to something.)

        Args:
            token (str): The token to apply the mapping rule to.

        Returns:
            The result of applying the mapping rule.
        """


class LambdaMappingRule(MappingRule):
    """Mapping rule based on lambda functions.

    Args:
        is_applicable_function (Callable[[str, Any, Any], bool]):
            Function to check if the rule is applicable to the given token, tag & context.
        apply_function (Callable[[str], Any]): Function to apply the rule to the token.
        priority (int): Priority of the rule.
    """

    def __init__(
        self,
        is_applicable_function: Callable[[str, Any, Any], bool],
        apply_function: Callable[[str], Any],
        priority: int,
    ) -> None:
        super().__init__()
        self.is_applicable_function = is_applicable_function
        self.apply_function = apply_function
        self._priority = priority

    def is_applicable(self, token, tag=None, context=None) -> bool:
        return self.is_applicable_function(token, tag, context)

    def apply(self, token) -> Any:
        return self.apply_function(token)

    @property
    def priority(self):
        return self._priority


class DirectMappingRule(MappingRule):
    """Mapping rule that directly maps keys to values.

    Args:
        priority (int): Priority of the rule.
        token_to_object (Dict[str, Any], optional): Dictionary mapping tokens to some objects.
        map_dict (Dict[str, Any], optional): Alternative name for token_to_object.
    """

    def __init__(self, priority: int, token_to_object: Optional[Dict[str, Any]] = None, map_dict: Optional[Dict[str, Any]] = None) -> None:
        super().__init__()
        if token_to_object is not None:
            self.token_to_object = token_to_object
        elif map_dict is not None:
            self.token_to_object = map_dict
        else:
            raise ValueError("DirectMappingRule requires either 'token_to_object' or 'map_dict' to be provided.")
        self._priority = priority

    def is_applicable(self, token, tag=None, context=None) -> bool:
        return token in self.token_to_object

    def apply(self, token: str) -> Any:
        return self.token_to_object[token]

    @property
    def priority(self):
        return self._priority


class CharacterByCharacterMappingRule(MappingRule):
    """Mapping rule which maps a token character-by-character.

    Args:
        token_to_object (Dict[str, Any]): Dictionary mapping tokens to some objects.
        allowed_tags (Set[Any]): Set of allowed tags for the rule to be applicable.
        priority (int): Priority of the rule.
    """

    def __init__(
        self,
        token_to_object: Dict[str, Any],
        allowed_tags: Set[Any],
        priority: int,
    ) -> None:
        super().__init__()
        self.token_to_object = token_to_object
        self.allowed_tags = allowed_tags
        self._priority = priority

    def is_applicable(self, token, tag=None, context=None) -> bool:
        # Check if any tag in the potentially nested tag structure is allowed
        tag_is_allowed = False
        if isinstance(tag, (list, tuple, set)):
            # Flatten potential list of lists (like [['UNKNOWN']])
            flat_tags = []
            for item in tag:
                if isinstance(item, (list, tuple, set)):
                    flat_tags.extend(item)
                else:
                    flat_tags.append(item)
            
            # Check if any flattened tag is in allowed_tags
            tag_is_allowed = any(t in self.allowed_tags for t in flat_tags)
        elif tag is not None:
            # Handle single tag case
            tag_is_allowed = tag in self.allowed_tags
        # If tag is None, tag_is_allowed remains False, which is usually correct unless allowed_tags includes None

        # Check if all characters in the token are mappable
        chars_are_mappable = all(char in self.token_to_object for char in token)

        return tag_is_allowed and chars_are_mappable

    def apply(self, token) -> List[Any]:
        """Apply the mapping rule to the given token.

        Args:
            token (str): The token to apply the mapping rule to.

        Returns:
            List[Any]: list of results of applying the mapping rule to each character in the token.
        """

        return [self.token_to_object[char] for char in token]

    @property
    def priority(self):
        return self._priority
