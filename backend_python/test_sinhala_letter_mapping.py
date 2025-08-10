#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test script to verify Sinhala letter mapping works correctly
"""
import os
import sys
import io

# Fix Windows console encoding for Sinhala characters
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

# Add the current directory to Python path
sys.path.append(os.path.dirname(__file__))

from letter_mapping_service import get_letter_mapping_service
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)

def test_sinhala_letters():
    """Test individual Sinhala letter mapping"""
    print("=== Testing Sinhala Letter Mapping ===")
    
    # Get the letter mapping service
    letter_service = get_letter_mapping_service()
    
    # Test some common Sinhala letters
    test_letters = ["අ", "ක", "ප", "ත", "ම", "න", "ර", "ල", "ව", "ස", "හ"]
    
    print(f"Available letters: {letter_service.get_available_letters()}")
    print(f"Total available letters: {len(letter_service.get_available_letters())}")
    
    for letter in test_letters:
        is_available = letter_service.is_letter_available(letter)
        print(f"Letter '{letter}': {'✓ Available' if is_available else '✗ Not found'}")
        
        if is_available:
            landmark_data = letter_service.get_letter_landmark(letter)
            if landmark_data and 'frames' in landmark_data:
                print(f"  - Has {len(landmark_data['frames'])} frames of landmark data")

def test_word_breakdown():
    """Test breaking Sinhala words into letters"""
    print("\n=== Testing Word Breakdown ===")
    
    letter_service = get_letter_mapping_service()
    
    # Test Sinhala words
    test_words = [
        "අම්මා",  # mother
        "තාත්තා", # father  
        "පොත",    # book
        "ගෙදර",   # house
        "ස්කෝලය", # school
        "කතා",
        "කොල්ලො"
    ]
    
    for word in test_words:
        letters = letter_service.break_word_to_letters(word)
        print(f"Word '{word}' breaks into: {letters}")
        
        # Check how many letters have landmark data
        available_count = sum(1 for letter in letters if letter_service.is_letter_available(letter))
        print(f"  - {available_count}/{len(letters)} letters have landmark data")

def test_full_word_sequence():
    """Test getting full letter sequence for a word"""
    print("\n=== Testing Full Word Letter Sequence ===")
    
    letter_service = get_letter_mapping_service()
    
    test_word = "අම්මා"  # mother - should have available letters
    print(f"Testing word: '{test_word}'")
    
    letter_sequence = letter_service.get_word_as_letter_sequence(test_word)
    
    print(f"Generated {len(letter_sequence)} letter signs:")
    for i, sign in enumerate(letter_sequence):
        letter = sign.get('letter', 'unknown')
        has_data = sign.get('landmark_data') is not None
        print(f"  {i+1}. Letter '{letter}': {'✓ Has landmark data' if has_data else '✗ No landmark data'}")

if __name__ == "__main__":
    try:
        test_sinhala_letters()
        test_word_breakdown() 
        test_full_word_sequence()
        print("\n=== Test completed ===")
    except Exception as e:
        print(f"Error during testing: {e}")
        import traceback
        traceback.print_exc()