"""
PipHub - GitHub Release Automation Tools

A collection of scripts for automating GitHub releases and Python package publishing.
"""

__version__ = "1.0.0"
__author__ = "ltanedo"
__email__ = "lloydtan@buffalo.edu"

from .cli import main_bash, main_powershell

__all__ = ["main_bash", "main_powershell"]
