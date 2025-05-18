from flask import Flask, request, jsonify, send_from_directory
import os
import sys
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
        return send_from_directory(media_dir, filename)

    return flask_app

# Create the Flask app instance using the factory
app = create_app()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    # Run the app instance created by the factory
    app.run(debug=os.environ.get('FLASK_ENV') == 'development', host='0.0.0.0', port=port)
