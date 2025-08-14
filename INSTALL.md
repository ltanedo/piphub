# PipHub Installation Guide

PipHub provides GitHub release automation tools with multiple installation methods for different platforms.

## Quick Install (Recommended)

### Linux/macOS
```bash
curl -fsSL https://raw.githubusercontent.com/ltanedo/clify-py/main/install.sh | bash
```

### Windows (PowerShell)
```powershell
iwr -useb https://raw.githubusercontent.com/ltanedo/clify-py/main/install.ps1 | iex
```

## Package Manager Installation

### Linux (Debian/Ubuntu) - APT Package

1. **Download from GitHub Releases:**
```bash
# Get the latest version
LATEST=$(curl -s https://api.github.com/repos/ltanedo/clify-py/releases/latest | grep tag_name | cut -d '"' -f 4)
VERSION=${LATEST#v}

# Download and install
wget "https://github.com/ltanedo/clify-py/releases/download/$LATEST/piphub_${VERSION}_all.deb"
sudo dpkg -i "piphub_${VERSION}_all.deb"

# Fix dependencies if needed
sudo apt-get install -f
```

2. **Verify installation:**
```bash
piphub --help
which piphub piphub-bash
```

### Windows - Manual Installation

1. **Download from GitHub Releases:**
   - Go to [Releases](https://github.com/ltanedo/clify-py/releases)
   - Download `piphub-windows-*.zip`

2. **Extract and Install:**
```powershell
# Extract to Program Files (requires admin) or user directory
Expand-Archive -Path "piphub-windows-*.zip" -DestinationPath "C:\Program Files\piphub"

# Add to PATH (system-wide, requires admin)
$env:PATH += ";C:\Program Files\piphub\bin"
[Environment]::SetEnvironmentVariable("PATH", $env:PATH, "Machine")
```

3. **Verify installation:**
```powershell
piphub.bat
piphub-bash.bat  # Requires WSL
```

## Advanced Installation Options

### Custom Installation Directory

**Linux:**
```bash
# Install to custom directory
curl -fsSL https://raw.githubusercontent.com/ltanedo/clify-py/main/install.sh | INSTALL_DIR="$HOME/bin" bash
```

**Windows:**
```powershell
# Install to custom directory
iwr -useb https://raw.githubusercontent.com/ltanedo/clify-py/main/install.ps1 | iex -Args @{InstallDir="C:\tools\piphub"}
```

### System-wide Installation (Windows)

```powershell
# Requires administrator privileges
iwr -useb https://raw.githubusercontent.com/ltanedo/clify-py/main/install.ps1 | iex -Args @{System=$true}
```

## Available Commands After Installation

| Command | Platform | Description |
|---------|----------|-------------|
| `piphub` | Linux/macOS | Default command (uses bash version) |
| `piphub-bash` | Linux/macOS/WSL | Bash version explicitly |
| `piphub.bat` | Windows | Default command (uses PowerShell version) |
| `piphub-bash.bat` | Windows | Bash version via WSL |
| `piphub-ps.ps1` | Windows/Linux | PowerShell version directly |

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

## Troubleshooting

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

For more help, see the [main README](README.md) or [open an issue](https://github.com/ltanedo/clify-py/issues).
