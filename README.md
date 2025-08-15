# PipHub - GitHub Release Automation Tools

PipHub provides command-line tools for automating GitHub releases and Python package publishing. It includes scripts for both bash and PowerShell environments with YAML-based configuration.

## Features

- 🚀 **Automated GitHub Releases** - Create releases with one command
- 📦 **Python Package Building** - Automatic wheel and source distribution creation
- 🔧 **YAML Configuration** - Simple setup.py generation from YAML
- 🌐 **Cross-Platform** - Works on Linux, macOS, and Windows
- 📋 **Flexible Installation** - Multiple installation methods available

## Quick Installation

### Linux/macOS
```bash
# One-line install
curl -fsSL https://raw.githubusercontent.com/ltanedo/piphub/main/install.sh | bash

# Manual install
wget https://raw.githubusercontent.com/ltanedo/piphub/main/install.sh
chmod +x install.sh
./install.sh
```

### Windows
```powershell
# One-line install
iwr -useb https://raw.githubusercontent.com/ltanedo/piphub/main/install.ps1 | iex

# Manual install
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ltanedo/piphub/main/install.ps1" -OutFile "install.ps1"
.\install.ps1

# System-wide install (requires admin)
.\install.ps1 -System

# Custom directory install
.\install.ps1 -InstallDir "C:\tools\piphub"
```

#### Proxy-friendly (Zscaler) tips
```powershell
# Use winget to install Git, clone repo, install to WindowsApps (most proxy-friendly)
iwr -useb https://raw.githubusercontent.com/ltanedo/piphub/main/install.ps1 | iex -Args @{ UseWinget = $true }

# Use your Windows credentials for the corporate proxy
iwr -useb https://raw.githubusercontent.com/ltanedo/piphub/main/install.ps1 | iex -Args @{ ProxyUseDefaultCredentials = $true }

# Install without any network (from a cloned workspace)
# Run from the repo root or wherever piphub.ps1 is available
.\install.ps1 -FromWorkspace -InstallDir "$env:LOCALAPPDATA\piphub"
```


## Package Manager Installation

### Linux (Debian/Ubuntu)
```bash
# Download latest .deb package
wget https://github.com/ltanedo/piphub/releases/latest/download/piphub_*_all.deb
sudo dpkg -i piphub_*_all.deb

# Fix dependencies if needed
sudo apt-get install -f
```

### Windows (Manual from Releases)
```powershell
# Download and extract ZIP
$version = "1.0.0"  # Replace with latest version
Invoke-WebRequest -Uri "https://github.com/ltanedo/piphub/releases/download/v$version/piphub-windows-$version.zip" -OutFile "piphub.zip"
Expand-Archive -Path "piphub.zip" -DestinationPath "C:\Program Files\piphub"

# Add to PATH
$env:PATH += ";C:\Program Files\piphub\bin"
[Environment]::SetEnvironmentVariable("PATH", $env:PATH, "User")
```

## Advanced Installation Options

### Custom Installation Directory

**Linux/macOS:**
```bash
# Install to custom directory
curl -fsSL https://raw.githubusercontent.com/ltanedo/clify-py/main/install.sh | INSTALL_DIR="$HOME/bin" bash
```

**Windows:**
```powershell
# Install to custom directory
iwr -useb https://raw.githubusercontent.com/ltanedo/clify-py/main/install.ps1 | iex -Args @{InstallDir="C:\tools\piphub"}

# System-wide installation (requires administrator privileges)
iwr -useb https://raw.githubusercontent.com/ltanedo/clify-py/main/install.ps1 | iex -Args @{System=$true}
```

## Configuration File: `piphub.yaml`

PipHub uses a single `piphub.yaml` configuration file that contains all your Python package setup information. The scripts automatically generate `setup.py` from this configuration and handle the entire release process.

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

## Available Commands

| Command | Platform | Description |
|---------|----------|-------------|
| `piphub` | Linux/macOS | Uses bash version |
| `piphub` | Windows | Uses PowerShell version |
| `piphub-ps.ps1` | All | PowerShell script directly |

## Requirements

### Linux/macOS
- `bash` >= 4.0
- `git`
- `gh` (GitHub CLI)
- `python3`
- `python3-pip`

### Windows
- PowerShell 5.1+ or PowerShell Core
- `git`
- `gh` (GitHub CLI)
- `python`
- For bash version: WSL with bash

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

## Uninstallation

### Linux (if installed via .deb)
```bash
sudo apt remove piphub
```

### Linux/macOS (if installed via script)
```bash
sudo rm -f /usr/local/bin/piphub /usr/local/bin/piphub-bash /usr/local/bin/piphub-ps.ps1
# Or for user installation:
rm -f ~/.local/bin/piphub ~/.local/bin/piphub-bash ~/.local/bin/piphub-ps.ps1
```

### Windows
```powershell
# Remove installation directory
Remove-Item -Recurse -Force "C:\Program Files\piphub"
# Remove from PATH manually via System Properties > Environment Variables
```

## Installation Troubleshooting

### Command not found
- Ensure the installation directory is in your PATH
- Restart your terminal after installation
- Check installation with `which piphub` (Linux/macOS) or `where piphub` (Windows)

### Permission denied
- On Linux: Ensure scripts are executable with `chmod +x`
- On Windows: Check PowerShell execution policy with `Get-ExecutionPolicy`

### WSL issues (Windows)
- Install WSL: `wsl --install`
- Ensure bash is available in WSL: `wsl bash --version`

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- 🐛 [Report Issues](https://github.com/ltanedo/piphub/issues)
- 📖 [Documentation](https://github.com/ltanedo/piphub#readme)
- 💬 [Discussions](https://github.com/ltanedo/piphub/discussions)
