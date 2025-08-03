#!/usr/bin/env python3
"""
Diagnostic script to test backend imports and setup
"""
import os
import sys

# Ensure we're in the right directory
backend_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(backend_dir)
sys.path.insert(0, backend_dir)

def test_imports():
    print("🔍 Testing backend imports...")
    print("="*50)
    
    try:
        print("1. Testing basic imports...")
        import flask
        print("   ✅ Flask imported successfully")
        
        print("2. Testing app module import...")
        import app as app_module
        print("   ✅ App module imported successfully")
        
        print("3. Checking app module contents...")
        attrs = [attr for attr in dir(app_module) if not attr.startswith('_')]
        print(f"   📋 Available attributes: {attrs}")
        
        print("4. Checking for Flask app instance...")
        if hasattr(app_module, 'app'):
            flask_app = app_module.app
            print("   ✅ Flask app instance found!")
            print(f"   📊 App type: {type(flask_app)}")
            
            if flask_app is not None:
                print("   ✅ Flask app is not None")
                print(f"   🌐 App name: {flask_app.name}")
            else:
                print("   ❌ Flask app is None")
        else:
            print("   ❌ No 'app' attribute found")
            
        print("5. Testing create_app function...")
        if hasattr(app_module, 'create_app'):
            print("   ✅ create_app function found")
            try:
                test_app = app_module.create_app()
                print(f"   ✅ create_app() successful: {type(test_app)}")
            except Exception as e:
                print(f"   ❌ create_app() failed: {e}")
        else:
            print("   ❌ create_app function not found")
            
    except ImportError as e:
        print(f"❌ Import failed: {e}")
        import traceback
        traceback.print_exc()
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()

def test_dependencies():
    print("\n🔧 Testing dependencies...")
    print("="*50)
    
    required_packages = [
        'flask', 'python-dotenv', 'boto3', 'botocore'
    ]
    
    for package in required_packages:
        try:
            __import__(package.replace('-', '_'))
            print(f"   ✅ {package}")
        except ImportError:
            print(f"   ❌ {package} - Missing!")

if __name__ == '__main__':
    test_dependencies()
    test_imports()
    
    print("\n🎯 Recommendations:")
    print("="*50)
    print("If everything looks good above, try:")
    print("   python app.py")
    print("\nIf there are import errors, install missing packages:")
    print("   pip install flask python-dotenv boto3")