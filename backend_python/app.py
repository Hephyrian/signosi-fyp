import sys
import io

# Reconfigure stdout and stderr to use UTF-8 for Unicode output in Windows console
sys.stdout = io.TextIOWrapper(sys.stdout.detach(), encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.detach(), encoding='utf-8', errors='replace')

from flask import Flask, request, jsonify, send_from_directory, g
import os
import sys
import logging
import time
import uuid
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Add the 'backend_python' directory to sys.path
# This allows `from app.routes...` and `from app.services...` to work
# when app.py is in backend_python/ and the app modules are in backend_python/app/
sys.path.append(os.path.dirname(os.path.abspath(__file__)))


def create_app(config_object_name=None):
    """
    Application factory for the Flask app.
    Initializes the Flask app, loads configuration, and registers blueprints.
    """
    flask_app = Flask(__name__)
    flask_app.config['JSON_AS_ASCII'] = False # Ensure Unicode characters are not escaped in JSON responses

    if config_object_name:
        flask_app.config.from_object(config_object_name)
    else:
        flask_app.config.from_mapping(
            DEBUG=os.environ.get('FLASK_DEBUG', True),
            SECRET_KEY=os.environ.get('SECRET_KEY', 'a-very-secure-default-key')
        )

    # Configure comprehensive logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - [%(name)s] - %(message)s',
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler('backend_requests.log', encoding='utf-8')
        ]
    )
    
    # Request logging middleware
    @flask_app.before_request
    def log_request_info():
        g.start_time = time.time()
        g.request_id = str(uuid.uuid4())[:8]
        
        timestamp = datetime.now().isoformat()
        flask_app.logger.info(f"🚀 [{timestamp}] REQUEST_START [{g.request_id}] {request.method} {request.url}")
        flask_app.logger.info(f"📋 [{g.request_id}] Headers: {dict(request.headers)}")
        
        if request.is_json:
            try:
                body = request.get_json()
                # Sanitize sensitive data for logging
                safe_body = {k: (v if k not in ['password', 'token', 'secret'] else '*REDACTED*') 
                           for k, v in body.items()} if body else {}
                flask_app.logger.info(f"📝 [{g.request_id}] Request Body: {safe_body}")
            except Exception as e:
                flask_app.logger.warning(f"⚠️ [{g.request_id}] Could not parse JSON body: {e}")
        elif request.data:
            flask_app.logger.info(f"📄 [{g.request_id}] Raw Body Length: {len(request.data)} bytes")
    
    @flask_app.after_request
    def log_response_info(response):
        duration = time.time() - g.start_time
        timestamp = datetime.now().isoformat()
        
        flask_app.logger.info(f"✅ [{timestamp}] REQUEST_END [{g.request_id}] {response.status_code} - {duration:.3f}s")
        
        # Attach correlation headers
        try:
            response.headers['X-Request-ID'] = getattr(g, 'request_id', 'UNKNOWN')
            response.headers['X-Server-Timestamp'] = timestamp
        except Exception:
            pass

        if response.is_json:
            try:
                # Log response size rather than full content for large responses
                response_data = response.get_json()
                if response_data and len(str(response_data)) > 1000:
                    flask_app.logger.info(f"📊 [{g.request_id}] Response: Large JSON ({len(str(response_data))} chars)")
                else:
                    flask_app.logger.info(f"📤 [{g.request_id}] Response: {response_data}")
            except Exception as e:
                flask_app.logger.warning(f"⚠️ [{g.request_id}] Could not parse response JSON: {e}")
        
        return response

    # Global error handler for unexpected exceptions
    @flask_app.errorhandler(Exception)
    def handle_unexpected_error(e):
        request_id = getattr(g, 'request_id', 'UNKNOWN')
        timestamp = datetime.now().isoformat()
        flask_app.logger.error(f"💥 [{timestamp}] UNHANDLED_EXCEPTION [{request_id}] {e}", exc_info=True)
        message = str(e) if flask_app.config.get('DEBUG') else 'Internal server error'
        return jsonify({
            "error": message,
            "code": "UNHANDLED_EXCEPTION",
            "request_id": request_id,
        }), 500

    # Import and register blueprints
    try:
        from app.routes.translation_routes import translate_bp
        flask_app.register_blueprint(translate_bp, url_prefix='/api/translate')
    except ImportError as e:
        print(f"Could not import or register translate_bp: {e}")
        # Potentially raise an error or log more severely if this is critical

    # Add route to serve static media files (landmark data)
    @flask_app.route('/media/<path:filename>')
    def serve_media(filename):
        # Assuming the media path in the response is relative to the media directory
        media_dir = os.path.join(flask_app.root_path, 'sign-language-translator', 'sign_language_translator', 'assets', 'datasets', 'lk-custom', 'media')
        flask_app.logger.info(f"📁 [{getattr(g, 'request_id', 'UNKNOWN')}] Serving media file: {filename}")
        return send_from_directory(media_dir, filename)

    return flask_app

# Create the Flask app instance using the factory
app = create_app()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    # Run the app instance created by the factory
    app.run(debug=os.environ.get('FLASK_ENV') == 'development', host='0.0.0.0', port=port)
