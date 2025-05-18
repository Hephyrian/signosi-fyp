from flask import Blueprint, request, jsonify
import logging # Added for debugging
# Assuming translation_service.py is in backend_python/app/services/
from ..services.translation_service import translate_text_to_slsl

translate_bp = Blueprint('translate_bp', __name__)

@translate_bp.route('/text-to-slsl', methods=['POST'])
def handle_text_to_slsl():
    data = request.get_json()
    if not data or 'text' not in data:
        return jsonify({"error": "Missing 'text' in request body"}), 400
    
    text_to_translate = data['text']
    logging.info(f"[ROUTE] Received text for translation: '{text_to_translate}', type: {type(text_to_translate)}") # Added for debugging
    source_language = data.get('source_language', 'si') # Default to Sinhala

    if source_language not in ['si', 'en', 'ta']: # Add 'ta' if you add support in service
        return jsonify({"error": "Unsupported source_language. Use 'si', 'en', or 'ta'."}), 400

    result = translate_text_to_slsl(text_to_translate, source_language_code=source_language)

    if "error" in result:
        # Consider more specific error codes based on the error type
        return jsonify(result), 500 

    # The result["signs"] will be a list of dicts, e.g.
    # [{"text": "Ayubowan", "media_path": "path/to/Ayubowan_001.mov", ...}, ...]
    # The frontend will need to know how to access these media_path files.
    # You might need to serve these files statically or from a media server.
    # A TODO was added in the service to adjust media_paths if necessary.
    return jsonify(result), 200
