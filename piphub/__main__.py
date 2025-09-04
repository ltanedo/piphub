#!/usr/bin/env python3
"""
PipHub command-line interface

This module provides the main entry point for the piphub command.
Since PipHub is primarily implemented as shell scripts (piphub.bash and piphub.ps1),
this Python entry point serves as a bridge to call the appropriate script.
"""

import sys
import os
import subprocess
import platform


def main():
    """Main entry point for the piphub command."""
    
    # Determine which script to use based on the platform
    if platform.system() == "Windows":
        script_name = "piphub.ps1"
        # Try to find PowerShell
        try:
            subprocess.run(["powershell", "-Version"], capture_output=True, check=True)
            cmd = ["powershell", "-ExecutionPolicy", "Bypass", "-File", script_name] + sys.argv[1:]
        except (subprocess.CalledProcessError, FileNotFoundError):
            print("Error: PowerShell not found. Please install PowerShell to use piphub on Windows.")
            sys.exit(1)
    else:
        script_name = "piphub.bash"
        cmd = ["bash", script_name] + sys.argv[1:]
    
    # Find the script in the same directory as this module
    script_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    script_path = os.path.join(script_dir, script_name)
    
    if not os.path.exists(script_path):
        print(f"Error: {script_name} not found at {script_path}")
        print("Please ensure piphub is properly installed.")
        sys.exit(1)
    
    # Replace the script name in the command with the full path
    cmd[cmd.index(script_name)] = script_path
    
    try:
        # Execute the appropriate script
        result = subprocess.run(cmd)
        sys.exit(result.returncode)
    except KeyboardInterrupt:
        sys.exit(130)  # Standard exit code for Ctrl+C
    except Exception as e:
        print(f"Error executing {script_name}: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
