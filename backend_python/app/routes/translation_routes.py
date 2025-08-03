from flask import Blueprint, request, jsonify, g, send_file
import logging # Added for debugging
import os # Added for file operations
from datetime import datetime
# Assuming translation_service.py is in backend_python/app/services/
from ..services.translation_service import translate_text_to_slsl

translate_bp = Blueprint('translate_bp', __name__)

@translate_bp.route('/text-to-slsl', methods=['POST'])
def handle_text_to_slsl():
    request_id = getattr(g, 'request_id', 'UNKNOWN')
    timestamp = datetime.now().isoformat()
    
    logging.info(f"🔥 [{timestamp}] TRANSLATION_ENDPOINT [{request_id}] Processing translation request")
    
    data = request.get_json()
    if not data or 'text' not in data:
        error_msg = "Missing 'text' in request body"
        logging.error(f"❌ [{request_id}] Validation Error: {error_msg}")
        return jsonify({"error": error_msg}), 400
    
    text_to_translate = data['text']
    source_language = data.get('source_language', 'si') # Default to Sinhala
    
    logging.info(f"📝 [{request_id}] Translation Request - Text: '{text_to_translate}', Language: '{source_language}', Text Length: {len(text_to_translate)}")

    if source_language not in ['si', 'en', 'ta']: # Add 'ta' if you add support in service
        error_msg = f"Unsupported source_language '{source_language}'. Use 'si', 'en', or 'ta'."
        logging.error(f"❌ [{request_id}] Language Error: {error_msg}")
        return jsonify({"error": error_msg}), 400

    # Call translation service with request ID for tracking
    logging.info(f"🔄 [{request_id}] Calling translation service...")
    result = translate_text_to_slsl(text_to_translate, source_language_code=source_language, request_id=request_id)

    if "error" in result:
        logging.error(f"❌ [{request_id}] Translation Service Error: {result}")
        # Consider more specific error codes based on the error type
        return jsonify(result), 500 

    # Log successful result
    num_signs = len(result.get("signs", []))
    logging.info(f"✅ [{request_id}] Translation Success - Generated {num_signs} signs")
    
    if num_signs > 0:
        sign_labels = [sign.get("label", "unknown") for sign in result["signs"]]
        logging.info(f"📋 [{request_id}] Sign Labels: {sign_labels}")

    return jsonify(result), 200

@translate_bp.route('/landmark-data/<path:filename>', methods=['GET'])
def serve_landmark_file(filename):
    """
    Serve landmark JSON files from the output_landmarks directory
    """
    request_id = getattr(g, 'request_id', 'UNKNOWN')
    timestamp = datetime.now().isoformat()
    
    logging.info(f"📊 [{timestamp}] LANDMARK_ENDPOINT [{request_id}] Serving landmark file: {filename}")
    
    try:
        # Define the path to the output_landmarks directory
        landmarks_dir = os.path.join(
            os.path.dirname(__file__), 
            '..', '..', 
            'sign-language-translator',
            'sign_language_translator',
            'assets',
            'datasets',
            'output_landmarks'
        )
        
        # Get absolute path and normalize
        landmarks_dir = os.path.abspath(landmarks_dir)
        file_path = os.path.join(landmarks_dir, filename)
        file_path = os.path.abspath(file_path)
        
        # Security check: ensure the file is within the landmarks directory
        if not file_path.startswith(landmarks_dir):
            error_msg = f"Access denied: Invalid file path"
            logging.error(f"❌ [{request_id}] Security Error: {error_msg} - Requested: {filename}")
            return jsonify({"error": error_msg}), 403
        
        # Check if file exists
        if not os.path.exists(file_path):
            error_msg = f"Landmark file not found: {filename}"
            logging.error(f"❌ [{request_id}] File Error: {error_msg}")
            return jsonify({"error": error_msg}), 404
        
        # Check if it's a JSON file
        if not filename.lower().endswith('.json'):
            error_msg = f"Only JSON files are allowed"
            logging.error(f"❌ [{request_id}] File Type Error: {error_msg} - Requested: {filename}")
            return jsonify({"error": error_msg}), 400
        
        logging.info(f"✅ [{request_id}] Serving landmark file: {file_path}")
        
        # Send the file with appropriate headers
        return send_file(
            file_path,
            mimetype='application/json',
            as_attachment=False,
            download_name=filename
        )
        
    except Exception as e:
        error_msg = f"Error serving landmark file: {str(e)}"
        logging.error(f"❌ [{request_id}] Server Error: {error_msg}", exc_info=True)
        return jsonify({"error": error_msg}), 500
