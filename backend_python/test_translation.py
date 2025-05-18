import requests
import json

def test_translation_service(text="පොත", source_language="si", port=8080):
    """
    Test the translation service by sending a request to the backend API.
    
    Args:
        text (str): The text to translate.
        source_language (str): The source language code ('si' for Sinhala, 'en' for English).
        port (int): The port on which the backend server is running.
    """
    try:
        # Construct URL with configurable port
        url = f"http://127.0.0.1:{port}/api/translate/text-to-slsl"
        payload = {
            "text": text,
            "source_language": source_language
        }
        headers = {"Content-Type": "application/json"}
        
        print(f"Sending request to {url} with text: '{text}' in language: {source_language}")
        response = requests.post(url, data=json.dumps(payload), headers=headers, timeout=5)
        
        if response.status_code == 200:
            result = response.json()
            print("Translation successful:")
            print(json.dumps(result, indent=2, ensure_ascii=False))
        else:
            print(f"Error: Received status code {response.status_code}")
            print(response.text)
    except requests.exceptions.ConnectionError:
        print(f"Error: Could not connect to the server at {url}. Is the backend running on port {port}?")
    except Exception as e:
        print(f"Error during test: {e}")

if __name__ == "__main__":
    import sys
    # Allow port to be specified as command line argument
    port = 8080
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print(f"Invalid port number: {sys.argv[1]}. Using default port 8080.")
    
    # Test with Sinhala text
    test_translation_service(port=port)
    # Test with another Sinhala word from the dictionary
    test_translation_service(text="එක", source_language="si", port=port)
    # # Test with English text (using a word known to be in the dictionary) - Disabled as en->slsl model not configured
    # test_translation_service(text="Book", source_language="en", port=port)
