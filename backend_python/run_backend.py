#!/usr/bin/env python3
"""
Simple and reliable backend runner with logging
"""
import os
import sys

# Ensure we're in the right directory
backend_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(backend_dir)

# Add current directory to Python path
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

def main():
    print("🎯 Starting Signosi Backend")
    print("=" * 50)
    
    try:
        # Direct import and run
        import app
        
        # Get configuration
        host = os.environ.get('FLASK_HOST', '0.0.0.0')
        port = int(os.environ.get('FLASK_PORT', 8080))
        debug = os.environ.get('FLASK_ENV') == 'development'
        
        print(f"🌐 Server: http://{host}:{port}")
        print(f"🐛 Debug: {debug}")
        print(f"📡 Ready for requests!")
        print("=" * 50)
        
        # Run the app directly from the module
        app.app.run(host=host, port=port, debug=debug)
        
    except Exception as e:
        print(f"❌ Error starting backend: {e}")
        print("\n🔧 Try running directly:")
        print("   python app.py")
        sys.exit(1)

if __name__ == '__main__':
    main()