#!/usr/bin/env python3
"""
CLI entry points for PipHub scripts
"""

import os
import sys
import subprocess
import tempfile
import platform
from pathlib import Path


def get_script_content(script_name):
    """Get the content of the embedded script"""
    script_dir = Path(__file__).parent
    script_path = script_dir / "scripts" / script_name
    
    if not script_path.exists():
        raise FileNotFoundError(f"Script {script_name} not found at {script_path}")
    
    return script_path.read_text(encoding='utf-8')


def main_bash():
    """Entry point for piphub-bash command"""
    try:
        script_content = get_script_content("piphub.bash")
        
        # Create a temporary script file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.bash', delete=False) as f:
            f.write(script_content)
            temp_script = f.name
        
        try:
            # Make it executable
            os.chmod(temp_script, 0o755)
            
            # Run the script
            if platform.system() == "Windows":
                # On Windows, try to run with WSL if available
                try:
                    result = subprocess.run(['wsl', 'bash', temp_script], 
                                          cwd=os.getcwd(), check=True)
                except FileNotFoundError:
                    print("WSL not found. Please install WSL or use piphub-ps instead.", file=sys.stderr)
                    sys.exit(1)
            else:
                # On Unix-like systems, run directly
                result = subprocess.run(['bash', temp_script], 
                                      cwd=os.getcwd(), check=True)
        finally:
            # Clean up temp file
            try:
                os.unlink(temp_script)
            except OSError:
                pass
                
    except subprocess.CalledProcessError as e:
        sys.exit(e.returncode)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


def main_powershell():
    """Entry point for piphub-ps command"""
    try:
        script_content = get_script_content("piphub.ps1")
        
        # Create a temporary script file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.ps1', delete=False, encoding='utf-8') as f:
            f.write(script_content)
            temp_script = f.name
        
        try:
            # Run the PowerShell script
            if platform.system() == "Windows":
                # On Windows, use PowerShell directly
                result = subprocess.run(['powershell', '-ExecutionPolicy', 'Bypass', '-File', temp_script], 
                                      cwd=os.getcwd(), check=True)
            else:
                # On Unix-like systems, try pwsh (PowerShell Core)
                try:
                    result = subprocess.run(['pwsh', '-File', temp_script], 
                                          cwd=os.getcwd(), check=True)
                except FileNotFoundError:
                    print("PowerShell Core (pwsh) not found. Please install PowerShell Core or use piphub-bash instead.", file=sys.stderr)
                    sys.exit(1)
        finally:
            # Clean up temp file
            try:
                os.unlink(temp_script)
            except OSError:
                pass
                
    except subprocess.CalledProcessError as e:
        sys.exit(e.returncode)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    # Default to bash on Unix-like systems, PowerShell on Windows
    if platform.system() == "Windows":
        main_powershell()
    else:
        main_bash()
