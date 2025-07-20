#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Simple test script to verify Sinhala letter mapping
"""
import os
import sys
import json

# Add the current directory to Python path
sys.path.append(os.path.dirname(__file__))

from letter_mapping_service import get_letter_mapping_service

def test_simple():
    """Simple test without console output issues"""
    print("Testing Sinhala letter mapping...")
    
    # Get the letter mapping service
    letter_service = get_letter_mapping_service()
    
    # Get available letters
    available_letters = letter_service.get_available_letters()
    print(f"Total available letters: {len(available_letters)}")
    
    # Test a few specific letters by their Unicode values
    test_letters = [
        "\u0D85",  # අ (a)
        "\u0D9A",  # ක (ka) 
        "\u0DB4",  # ප (pa)
        "\u0DAD",  # ත (ta)
        "\u0DB8",  # ම (ma)
    ]
    
    print("Testing specific letters:")
    for i, letter in enumerate(test_letters):
        is_available = letter_service.is_letter_available(letter)
        print(f"  Letter {i+1}: {'Available' if is_available else 'Not found'}")
        
        if is_available:
            landmark_data = letter_service.get_letter_landmark(letter)
            if landmark_data and 'frames' in landmark_data:
                frame_count = len(landmark_data['frames'])
                print(f"    - Has {frame_count} frames of landmark data")
    
    # Test word breakdown
    print("\nTesting word breakdown:")
    test_word = "\u0D85\u0DB8\u0DCA\u0DB8\u0DCF"  # අම්මා (amma - mother)
    letters = letter_service.break_word_to_letters(test_word)
    print(f"Word breaks into {len(letters)} letters")
    
    # Test full sequence generation
    letter_sequence = letter_service.get_word_as_letter_sequence(test_word)
    print(f"Generated {len(letter_sequence)} letter signs")
    
    for i, sign in enumerate(letter_sequence):
        has_data = sign.get('landmark_data') is not None
        print(f"  Sign {i+1}: {'Has data' if has_data else 'No data'}")
    
    return True

if __name__ == "__main__":
    try:
        test_simple()
        print("Test completed successfully!")
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()