#!/usr/bin/env python3
"""
Log viewer utility for the Signosi backend.
This script helps you view and monitor backend logs in real-time.
"""

import os
import sys
import time
import argparse
from datetime import datetime

def get_latest_log_file(logs_dir, log_type='requests'):
    """Get the most recent log file of the specified type"""
    if not os.path.exists(logs_dir):
        return None
    
    log_files = [f for f in os.listdir(logs_dir) if f.startswith(log_type) and f.endswith('.log')]
    if not log_files:
        return None
    
    # Sort by modification time, get the latest
    log_files.sort(key=lambda x: os.path.getmtime(os.path.join(logs_dir, x)), reverse=True)
    return os.path.join(logs_dir, log_files[0])

def tail_file(filepath, lines=50):
    """Display the last N lines of a file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lines_list = f.readlines()
            return lines_list[-lines:] if len(lines_list) > lines else lines_list
    except Exception as e:
        print(f"Error reading file: {e}")
        return []

def follow_file(filepath):
    """Follow a file like 'tail -f'"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            # Move to end of file
            f.seek(0, 2)
            
            print(f"📡 Following log file: {filepath}")
            print("Press Ctrl+C to stop...")
            print("=" * 60)
            
            while True:
                line = f.readline()
                if line:
                    print(line.rstrip())
                else:
                    time.sleep(0.1)
    except KeyboardInterrupt:
        print("\n🛑 Stopped following log file")
    except Exception as e:
        print(f"Error following file: {e}")

def main():
    parser = argparse.ArgumentParser(description='View Signosi backend logs')
    parser.add_argument('--type', choices=['requests', 'errors'], default='requests',
                       help='Type of logs to view (default: requests)')
    parser.add_argument('--follow', '-f', action='store_true',
                       help='Follow log file in real-time (like tail -f)')
    parser.add_argument('--lines', '-n', type=int, default=50,
                       help='Number of lines to show (default: 50)')
    parser.add_argument('--file', help='Specific log file to view')
    
    args = parser.parse_args()
    
    backend_dir = os.path.dirname(os.path.abspath(__file__))
    logs_dir = os.path.join(backend_dir, 'logs')
    
    # Determine which file to view
    if args.file:
        log_file = args.file
        if not os.path.isabs(log_file):
            log_file = os.path.join(logs_dir, log_file)
    else:
        log_file = get_latest_log_file(logs_dir, args.type)
    
    if not log_file or not os.path.exists(log_file):
        print(f"❌ No {args.type} log file found!")
        print(f"📁 Looking in: {logs_dir}")
        if os.path.exists(logs_dir):
            print("Available log files:")
            for f in os.listdir(logs_dir):
                if f.endswith('.log'):
                    print(f"  - {f}")
        else:
            print("💡 Start the backend first to generate log files")
        return
    
    print(f"📋 Viewing {args.type} logs")
    print(f"📁 File: {log_file}")
    print(f"🕒 Last modified: {datetime.fromtimestamp(os.path.getmtime(log_file))}")
    print("=" * 60)
    
    if args.follow:
        follow_file(log_file)
    else:
        lines = tail_file(log_file, args.lines)
        for line in lines:
            print(line.rstrip())

if __name__ == '__main__':
    main()