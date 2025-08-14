# PipHub Usage Guide

PipHub now uses a single `piphub.yaml` configuration file that contains all your Python package setup information. The scripts automatically generate `setup.py` from this configuration and handle the entire release process.

## Configuration File: `piphub.yaml`

### Required Fields

```yaml
# Package identification
name: "your-package-name"
version: "1.0.0"  # or "auto" to read from existing setup.py
author: "Your Name"
author_email: "your.email@example.com"
description: "Short description of your package"
url: "https://github.com/username/repo-name"
```

### Optional Fields

```yaml
# License and documentation
license: "MIT"
long_description_content_type: "text/markdown"
python_requires: ">=3.6"

# Package structure
py_modules: ["single_module"]  # For single-file packages
# packages are auto-discovered with find_packages()

# Dependencies
install_requires: ["requests>=2.25.0", "pyyaml>=5.4.0"]
# or empty list for no dependencies:
install_requires: []

# PyPI metadata
keywords: "cli, automation, tools"
classifiers: [
    "Development Status :: 4 - Beta",
    "Intended Audience :: Developers",
    "License :: OSI Approved :: MIT License",
    "Operating System :: OS Independent",
    "Programming Language :: Python :: 3"
]

# Project URLs
project_urls: {
    "Bug Reports": "https://github.com/username/repo/issues",
    "Source": "https://github.com/username/repo",
    "Documentation": "https://github.com/username/repo#readme"
}
```

### Release Settings

```yaml
# Release configuration (not part of setup.py)
tag_prefix: "v"              # Creates tags like v1.0.0
target_branch: "main"        # Branch to release from
release_notes_file: "README.md"  # File to use for release notes
draft: false                 # Create as draft release
prerelease: false           # Mark as prerelease
```

## Usage

### 1. Create your `piphub.yaml`

```yaml
name: "mypackage"
version: "1.0.0"
author: "John Doe"
author_email: "john@example.com"
description: "My awesome Python package"
url: "https://github.com/johndoe/mypackage"
license: "MIT"
python_requires: ">=3.6"
install_requires: []
keywords: "python, package, awesome"
classifiers: [
    "Development Status :: 4 - Beta",
    "Intended Audience :: Developers",
    "License :: OSI Approved :: MIT License",
    "Programming Language :: Python :: 3"
]

# Release settings
tag_prefix: "v"
target_branch: "main"
draft: false
prerelease: false
```

### 2. Run the release script

**Linux/macOS/WSL:**
```bash
./piphub.bash
# or if installed globally:
piphub-bash
```

**Windows:**
```powershell
.\piphub.ps1
# or if installed globally:
piphub.bat
```

### 3. What happens automatically

1. **Generates `setup.py`** from your `piphub.yaml` configuration
2. **Validates** git repository state (no uncommitted changes)
3. **Creates git tag** (e.g., `v1.0.0`)
4. **Builds** Python package (wheel and source distribution)
5. **Creates GitHub release** with built packages
6. **Updates `requirements.txt`** with install command

## Advanced Features

### Version Management

```yaml
# Explicit version
version: "2.1.0"

# Auto-detect from existing setup.py
version: "auto"
```

### Complex Dependencies

```yaml
# Multiple dependencies with version constraints
install_requires: [
    "requests>=2.25.0,<3.0.0",
    "click>=7.0",
    "pyyaml>=5.4.0"
]

# Development dependencies (if using extras_require)
extras_require: {
    "dev": ["pytest>=6.0", "black", "flake8"],
    "docs": ["sphinx", "sphinx-rtd-theme"]
}
```

### Entry Points

```yaml
# Console scripts
entry_points: {
    "console_scripts": [
        "mycli=mypackage.cli:main",
        "mytool=mypackage.tools:run"
    ]
}
```

## Migration from `release.yaml`

If you have an existing `release.yaml`, migrate to `piphub.yaml`:

1. **Copy package info** from your existing `setup.py`
2. **Add release settings** from `release.yaml`
3. **Remove** the old `release.yaml` and `setup.py`
4. **Test** with `python test_setup_generation.py`

### Example Migration

**Old `release.yaml`:**
```yaml
repo: johndoe/mypackage
package_name: mypackage
version: auto
tag_prefix: v
```

**Old `setup.py`:**
```python
setup(
    name="mypackage",
    version="1.0.0",
    author="John Doe",
    # ...
)
```

**New `piphub.yaml`:**
```yaml
name: "mypackage"
version: "1.0.0"
author: "John Doe"
author_email: "john@example.com"
description: "My package description"
url: "https://github.com/johndoe/mypackage"
# ... other setup.py fields ...

# Release settings
tag_prefix: "v"
target_branch: "main"
```

## Troubleshooting

### Common Issues

1. **"Unable to determine repository"**
   - Ensure `url` field points to your GitHub repository

2. **"name not set"**
   - Add the `name` field to your `piphub.yaml`

3. **Invalid YAML syntax**
   - Use proper YAML formatting (quotes around strings, proper list syntax)
   - Test with: `python -c "import yaml; yaml.safe_load(open('piphub.yaml'))"`

4. **Generated setup.py has issues**
   - Run `python test_setup_generation.py` to test
   - Check that all required fields are present

### Testing Your Configuration

```bash
# Test setup.py generation
python test_setup_generation.py

# Validate the generated setup.py
python setup.py check

# Test package building
python -m build
```

## Benefits of the New System

1. **Single source of truth** - All package info in one YAML file
2. **No manual setup.py maintenance** - Generated automatically
3. **Consistent formatting** - Scripts handle Python syntax correctly
4. **Version control friendly** - YAML is easier to read and edit
5. **Cross-platform** - Same configuration works on Linux and Windows
