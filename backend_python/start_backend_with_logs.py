#!/usr/bin/env python3
"""
Enhanced backend startup script with comprehensive logging setup.
This script starts the Flask backend with detailed request/response logging.
"""

import os
import sys
import logging
from datetime import datetime

# Add the backend directory to Python path
backend_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, backend_dir)

def setup_comprehensive_logging():
    """Set up detailed logging for the backend"""
    
    # Create logs directory if it doesn't exist
    logs_dir = os.path.join(backend_dir, 'logs')
    os.makedirs(logs_dir, exist_ok=True)
    
    # Setup log files
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    request_log = os.path.join(logs_dir, f'requests_{timestamp}.log')
    error_log = os.path.join(logs_dir, f'errors_{timestamp}.log')
    
    # Configure root logger
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - [%(name)s:%(funcName)s:%(lineno)d] - %(message)s',
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler(request_log, encoding='utf-8'),
        ]
    )
    
    # Setup error logging
    error_handler = logging.FileHandler(error_log, encoding='utf-8')
    error_handler.setLevel(logging.ERROR)
    error_formatter = logging.Formatter('%(asctime)s - %(levelname)s - [%(name)s:%(funcName)s:%(lineno)d] - %(message)s')
    error_handler.setFormatter(error_formatter)
    
    # Add error handler to root logger
    logging.getLogger().addHandler(error_handler)
    
    print(f"🚀 Backend logging configured!")
    print(f"📋 Request logs: {request_log}")
    print(f"❌ Error logs: {error_log}")
    print(f"📺 Console: Enabled")
    print(f"" + "="*60)

def main():
    """Main function to start the backend with enhanced logging"""
    
    print("🎯 Starting Signosi Backend with Enhanced Logging")
    print("="*60)
    
    # Setup logging
    setup_comprehensive_logging()
    
    # Import and start the Flask app
    try:
        print("📦 Importing app module...")
        import app as app_module
        
        print("🔍 Checking app module attributes...")
        if hasattr(app_module, 'app'):
            flask_app = app_module.app
            print("✅ Flask app instance found!")
        else:
            print("❌ Flask app instance not found!")
            print(f"Available attributes in app module: {dir(app_module)}")
            raise AttributeError("No 'app' attribute found in app module")
        
        if flask_app is None:
            raise ValueError("Flask app instance is None - app creation may have failed")
        
        # Get configuration from environment
        host = os.environ.get('FLASK_HOST', '0.0.0.0')
        port = int(os.environ.get('FLASK_PORT', 8080))
        debug = os.environ.get('FLASK_ENV') == 'development'
        
        print(f"🌐 Starting server on http://{host}:{port}")
        print(f"🐛 Debug mode: {debug}")
        print(f"📡 Ready to receive requests from frontend!")
        print("="*60)
        
        # Start the app
        flask_app.run(host=host, port=port, debug=debug)
        
    except ImportError as e:
        logging.error(f"Failed to import Flask app: {e}")
        print(f"❌ Import Error: {e}")
        print("\n🔧 Try running directly with: python app.py")
        sys.exit(1)
    except (AttributeError, ValueError) as e:
        logging.error(f"Flask app setup error: {e}")
        print(f"❌ App Setup Error: {e}")
        print("\n🔧 The Flask app may not be properly initialized")
        print("Check the create_app() function in app.py")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n🛑 Shutting down backend server...")
        sys.exit(0)
    except Exception as e:
        logging.error(f"Unexpected error starting backend: {e}")
        print(f"💥 Unexpected error: {e}")
        print("\n🔧 Try running directly with: python app.py")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()