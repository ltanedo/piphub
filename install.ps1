# install.ps1 - Install piphub from GitHub releases (Windows)

param(
    [switch]$System,  # Install system-wide (requires admin)
    [string]$InstallDir = ""
)

$ErrorActionPreference = "Stop"

$REPO = "ltanedo/clify-py"

function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Green }
function Write-Warn { param($Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

# Determine install directory
if ($System) {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Error "System installation requires administrator privileges"
        Write-Host "Please run as administrator or omit -System flag for user installation"
        exit 1
    }
    $INSTALL_DIR = "$env:ProgramFiles\piphub\bin"
} elseif ($InstallDir) {
    $INSTALL_DIR = $InstallDir
} else {
    $INSTALL_DIR = "$env:USERPROFILE\.local\bin"
}

Write-Info "Installing to: $INSTALL_DIR"
New-Item -ItemType Directory -Force -Path $INSTALL_DIR | Out-Null

# Get latest release info
Write-Info "Fetching latest release information..."
try {
    $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/releases/latest"
    $tagName = $response.tag_name
    $version = $tagName -replace '^v', ''
} catch {
    Write-Error "Failed to get latest release information: $_"
    exit 1
}

Write-Info "Latest version: $tagName"

# Try to download and extract Windows package
$zipUrl = "https://github.com/$REPO/releases/download/$tagName/piphub-windows-$version.zip"
$tempZip = [System.IO.Path]::GetTempFileName() + ".zip"

try {
    Write-Info "Downloading Windows package..."
    Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip
    
    Write-Info "Extracting package..."
    $tempDir = [System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid().ToString()
    Expand-Archive -Path $tempZip -DestinationPath $tempDir
    
    # Copy files from extracted package
    $extractedBin = Join-Path $tempDir "bin"
    if (Test-Path $extractedBin) {
        Copy-Item -Path "$extractedBin\*" -Destination $INSTALL_DIR -Recurse -Force
        Write-Info "Package installation complete!"
    } else {
        throw "Package structure not as expected"
    }
    
    # Clean up
    Remove-Item $tempZip -Force
    Remove-Item $tempDir -Recurse -Force
    
} catch {
    Write-Warn "Package installation failed, falling back to direct script download: $_"
    
    # Fallback: Download scripts directly
    Write-Info "Installing scripts directly..."
    
    # Download bash script
    $bashUrl = "https://raw.githubusercontent.com/$REPO/$tagName/piphub.bash"
    Invoke-WebRequest -Uri $bashUrl -OutFile "$INSTALL_DIR\piphub-bash"
    
    # Download PowerShell script
    $psUrl = "https://raw.githubusercontent.com/$REPO/$tagName/piphub.ps1"
    Invoke-WebRequest -Uri $psUrl -OutFile "$INSTALL_DIR\piphub-ps.ps1"
    
    # Create batch wrappers
    @'
@echo off
wsl bash -c "$(wslpath '%~dp0piphub-bash') %*"
'@ | Out-File -FilePath "$INSTALL_DIR\piphub-bash.bat" -Encoding ascii
    
    @'
@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0piphub-ps.ps1" %*
'@ | Out-File -FilePath "$INSTALL_DIR\piphub.bat" -Encoding ascii
}

Write-Info "Installation complete!"
Write-Info "Commands available:"
Write-Info "  piphub.bat       - Default (PowerShell version)"
Write-Info "  piphub-bash.bat  - Bash version (requires WSL)"
Write-Info "  piphub-ps.ps1    - PowerShell script directly"

# Check if install directory is in PATH
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentPath -notlike "*$INSTALL_DIR*") {
    Write-Warn "$INSTALL_DIR is not in your PATH"
    
    $addToPath = Read-Host "Add to PATH automatically? (y/N)"
    if ($addToPath -eq 'y' -or $addToPath -eq 'Y') {
        $newPath = "$currentPath;$INSTALL_DIR"
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        Write-Info "Added to PATH. Please restart your terminal."
    } else {
        Write-Warn "Manually add to PATH: $INSTALL_DIR"
    }
}
