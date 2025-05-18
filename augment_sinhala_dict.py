import json
import re
import os

# INPUT_FILE will also be the OUTPUT_FILE in this version
IO_FILE = 'backend_python/sign-language-translator/sign_language_translator/assets/lk-dictionary-mapping.json'

def generate_new_variations_from_single_word(word):
    """
    Generates new grammatical variations from a single Sinhala word.
    
    Args:
        word (str): A single Sinhala word.
        
    Returns:
        list: A list of new (derived) string variations. Should NOT include the original word.
    """
    variations = []
    
    # Rule 0: Skip if the word is purely numeric or too short
    if word.isnumeric() or len(word) < 2:
        return []

    # Rule 1: Strip common enumerators/prefixes like "1. ", "10) ", "(අ) " etc.
    prefix_patterns = [
        r"^\\d+\\.\\s*(.+)",            # Matches "1. word", captures "word"
        r"^\\d+[)]\\s*(.+)",            # Matches "1) word", captures "word"
        r"^[(]([a-zA-Z]+|[අ-ෆ])[)]\\s*(.+)",  # Matches "(a) word" or "(අ) word", captures letter then "word"
        r"^[a-zA-Z]+\\.\\s*(.+)",      # Matches "a. word", captures "word"
    ]
    original_word_for_derivation = word
    for pattern in prefix_patterns:
        match_prefix = re.match(pattern, original_word_for_derivation)
        if match_prefix:
            stripped_word = match_prefix.group(match_prefix.lastindex) # Get the last captured group
            if stripped_word != original_word_for_derivation:
                variations.append(stripped_word)
                original_word_for_derivation = stripped_word # Use stripped word for further derivations
            break # Assume only one such prefix

    # Common Sinhala case suffixes to identify nouns and avoid applying incorrect patterns
    case_endings = ["ගේ", "ට", "ටා", "ගෙන්", "ටත්", "ටම", "න්", "යන්", "වන්", "වල", "වලට", "වලින්"]
    verb_endings = ["නවා", "ණවා", "යි", "ති", "වා", "මි", "මු", "වෙමි", "වෙමු", "කරනවා", "කරයි", "කළා"]
    
    # Try to identify the part of speech
    is_likely_noun = not any(original_word_for_derivation.endswith(ending) for ending in verb_endings)
    is_likely_verb = any(original_word_for_derivation.endswith(ending) for ending in ["නවා", "ණවා", "වා"])
    
    # Rule 2: Declensions for nouns (විභක්ති - vibhakti)
    if is_likely_noun:
        # Base word appears to be a noun
        
        # Possessive forms - "ගේ" (genitive)
        if not original_word_for_derivation.endswith(tuple(case_endings)):
            variations.append(original_word_for_derivation + "ගේ")  # Possessive
        
        # Dative forms - "ට" (to)
        if not original_word_for_derivation.endswith(("ට", "ටා", "ටත්", "ටම")):
            variations.append(original_word_for_derivation + "ට")  # To/for
            
        # Instrumental forms - "ගෙන්" (by/with)
        if not original_word_for_derivation.endswith("ගෙන්"):
            variations.append(original_word_for_derivation + "ගෙන්")  # By/with
            
        # Locative forms - "වල" (in/at)
        if not original_word_for_derivation.endswith(("වල", "වලට", "වලින්")):
            variations.append(original_word_for_derivation + "වල")  # In/at
            
        # Pluralization strategies based on word endings
        if not original_word_for_derivation.endswith(("ලා", "වරු", "යෝ", "වල්", "වල", "ගණ")):
            # Human and animate nouns often take "ලා"
            if not any(original_word_for_derivation.endswith(ending) for ending in ["නවා", "ණවා", "වෙමි", "වෙමු"]):
                variations.append(original_word_for_derivation + "ලා")
                
            # Professional/respected nouns take "වරු"
            if original_word_for_derivation.endswith(("කරු", "ගුරු", "ආචාර්ය")):
                variations.append(original_word_for_derivation + "වරු")
                
            # General plurals with "වල්"
            if not original_word_for_derivation.endswith(("නවා", "ණවා", "වා", "ගේ")):
                variations.append(original_word_for_derivation + "වල්")
    
    # Rule 3: Verb forms - verbs have rich conjugation in Sinhala
    # Identify potential verb roots by removing common verb endings
    verb_root = None
    if is_likely_verb:
        # Try to extract verb root by removing common endings
        if original_word_for_derivation.endswith("නවා"):
            verb_root = original_word_for_derivation[:-3]  # Remove "නවා"
        elif original_word_for_derivation.endswith("ණවා"):
            verb_root = original_word_for_derivation[:-3]  # Remove "ණවා" 
        elif original_word_for_derivation.endswith("වා"):
            verb_root = original_word_for_derivation[:-2]  # Remove "වා"
    
    # If we've identified a verb root, generate verb forms
    if verb_root:
        # Infinitive form
        variations.append(verb_root + "න්න")  # To [verb]
        
        # Past tense
        variations.append(verb_root + "වා")   # Did [verb]
        
        # Imperative (command)
        variations.append(verb_root + "න්න")   # [Verb]!
        
        # Future tense
        variations.append(verb_root + "යි")    # Will [verb]
        
        # Conditional
        variations.append(verb_root + "නවා නම්")  # If [verb]
        
        # Causative
        if len(verb_root) > 2:
            variations.append(verb_root + "වනවා")  # Make/cause to [verb]
    
    # Rule 4: Adjective forms (when applicable)
    # Some adjectives can take intensifiers or comparatives
    if not is_likely_verb and not original_word_for_derivation.endswith(tuple(case_endings)):
        # Quality nouns derived from adjectives
        variations.append(original_word_for_derivation + "කම")  # The quality of being [adj]
        
        # Adverbial form  
        variations.append(original_word_for_derivation + "ව")  # In a [adj] manner
        
    # Rule 5: Particle attachments - emphatic particles
    if not original_word_for_derivation.endswith(("ම", "ත්", "ද")):
        variations.append(original_word_for_derivation + "ම")   # Emphatic (exactly/only)
        variations.append(original_word_for_derivation + "ත්")   # Also/too
        
    # Rule 6: For common words, add negation forms
    common_verbs = ["යනවා", "එනවා", "කරනවා", "කියනවා", "බලනවා", "දකිනවා", "පුළුවන්"]
    if original_word_for_derivation in common_verbs:
        if original_word_for_derivation == "පුළුවන්":
            variations.append("බැහැ")  # Can't (negation of "can")
        elif original_word_for_derivation.endswith("නවා"):
            # Negation of verbs
            verb_base = original_word_for_derivation[:-3]
            variations.append(verb_base + "න්නේ නැහැ")  # Don't/doesn't [verb]
    
    # Return only unique new variations that are different from the original input 'word' 
    # and also different from the 'original_word_for_derivation' if it was stripped.
    final_variations = []
    for v in list(set(variations)):  # Make unique
        if v and v != word and v != original_word_for_derivation:  # Ensure it's new and not empty
            final_variations.append(v)
    return final_variations

def augment_dictionary(filepath):
    """
    Reads the dictionary, generates and adds Sinhala word variations, 
    and saves the changes back to the same file.
    """
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"Error: Input file not found at {filepath}")
        return
    except json.JSONDecodeError:
        print(f"Error: Could not decode JSON from {filepath}")
        return

    processed_count = 0
    entries_changed_count = 0
    # Create a deep copy for comparison to see if anything actually changed
    original_data_str = json.dumps(data, sort_keys=True) 

    for entry_id, entry_data in data.items():
        if "text" in entry_data and "si" in entry_data["text"] and \
           isinstance(entry_data["text"]["si"], list):
            
            original_si_words_for_entry = list(entry_data["text"]["si"]) # Work with a copy
            all_variations_for_this_entry = set(original_si_words_for_entry) # Start with existing words to ensure uniqueness
            
            made_change_to_this_entry = False

            for si_word in original_si_words_for_entry: # Iterate over the original words only for generating variations
                newly_derived_variations = generate_new_variations_from_single_word(si_word)
                
                for variant in newly_derived_variations:
                    if variant not in all_variations_for_this_entry:
                        all_variations_for_this_entry.add(variant)
                        made_change_to_this_entry = True # Mark that a new variant was added to the set
            
            if made_change_to_this_entry:
                current_list_in_entry = set(entry_data["text"]["si"])
                if not all_variations_for_this_entry.issubset(current_list_in_entry) or \
                   not current_list_in_entry.issubset(all_variations_for_this_entry):
                    entry_data["text"]["si"] = sorted(list(all_variations_for_this_entry))
                    # entries_changed_count is incremented only if the file content will change later.
                    # The actual check for file change is done by comparing json dumps.
                else:
                    # This case implies new variations were generated but were already present somehow, 
                    # or duplicate of originals. Set made_change_to_this_entry to false if list isn't actually changing.
                    made_change_to_this_entry = False 
            
            processed_count += 1
        else:
            print(f"Warning: Entry {entry_id} does not have a valid 'text.si' list structure. Skipping.")
    
    current_data_str = json.dumps(data, sort_keys=True)

    if current_data_str != original_data_str:
        try:
            # Recalculate entries_changed_count based on actual differences if needed, 
            # or rely on the fact that original_data_str != current_data_str means at least one changed.
            # For simplicity, we can just report that the file was modified.
            # To get an accurate entries_changed_count, we would need to compare old and new entry_data["text"]["si"] lists.
            # The current entries_changed_count might be an overestimation if generated variants were already present in some cases.
            # For now, the overall file change detection is key.
            
            # Let's refine entries_changed_count based on actual changes:
            final_entries_changed = 0
            temp_original_data = json.loads(original_data_str)
            for entry_id, new_entry_data in data.items():
                old_si_list = temp_original_data.get(entry_id, {}).get("text", {}).get("si", None)
                new_si_list = new_entry_data.get("text", {}).get("si", None)
                if old_si_list is not None and new_si_list is not None and sorted(list(set(old_si_list))) != sorted(list(set(new_si_list))):
                    final_entries_changed +=1

            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            print(f"Successfully processed {processed_count} entries.")
            print(f"{final_entries_changed} entries had their Sinhala variations list modified.")
            print(f"Changes saved directly to: {filepath}")
        except IOError:
            print(f"Error: Could not write changes back to {filepath}")
    else:
        print(f"Successfully processed {processed_count} entries.")
        print("No overall changes to Sinhala variations were made, so the file was not modified.")

if __name__ == '__main__':
    print("IMPORTANT: This script will modify the input file directly.")
    print("It is highly recommended to back up your JSON file before proceeding.")
    proceed = input(f"Are you sure you want to augment '{IO_FILE}' in place? (yes/no): ")
    
    if proceed.lower() == 'yes':
        print(f"Current working directory: {os.getcwd()}")
        print(f"Target file for augmentation: {os.path.abspath(IO_FILE)}")
        
        if not os.path.exists(IO_FILE):
            print(f"ERROR: Target file {IO_FILE} does not exist from the current directory.")
            print("Please ensure you are running this script from the root of your project,")
            print("or that the IO_FILE path is correct.")
        else:
            augment_dictionary(IO_FILE)
    else:
        print("Augmentation cancelled by the user.")

# To run this script:
# 1. Save it as a .py file (e.g., augment_sinhala_dict.py) in the root of your 'signosi-fyp' project.
# 2. IMPORTANT: Modify the `generate_new_variations_from_single_word` function 
#    with your specific rules for generating Sinhala word variations.
# 3. **BACKUP YOUR lk-dictionary-mapping.json FILE BEFORE RUNNING.**
# 4. Open a terminal in the root of your 'signosi-fyp' project.
# 5. Run the script: python augment_sinhala_dict.py
# 6. Confirm when prompted if you want to modify the file in place.