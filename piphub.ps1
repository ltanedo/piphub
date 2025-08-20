# piphub.ps1 - Create a GitHub release and upload Python package assets (PowerShell)
#
# Requirements:
# - git configured with access to your repo remote (origin)
# - gh (GitHub CLI) installed and authenticated: gh auth login
# - Python build tooling: python -m pip install --upgrade build
# - A piphub.yaml file at the repo root with setup() function arguments
#
# Usage:
#   .\piphub.ps1 <init|generate|release>
#
param(
    [Parameter(Position=0,Mandatory=$true)]
    [ValidateSet('init','generate','release')]
    [string]$Command
)

$ErrorActionPreference = "Stop"

$CFG = "piphub.yml"
$CHECK = [char]0x2714
$CROSS = [char]0x274C

function Abort {
    param([string]$Message)
    Write-Host "[$CROSS] $Message" -ForegroundColor Red
    exit 1
}

function Info {
    param([string]$Message)
    Write-Host "[•] $Message" -ForegroundColor Cyan
}
function Ok {
    param([string]$Message)
    Write-Host "[$CHECK] $Message" -ForegroundColor Green
}

# Subcommand: init - create template piphub.yml
if ($Command -eq 'init') {
    Info "Creating template configuration (piphub.yml)"

    # Get current directory name for default package name
    $defaultName = (Get-Item .).Name

    # Try to get git remote URL for default repository URL
    $defaultUrl = ""
    try {
        $gitRemote = git remote get-url origin 2>$null
        if ($gitRemote -and $gitRemote -match "github\.com[:/]([^/]+/[^/]+)") {
            $defaultUrl = "https://github.com/$($matches[1] -replace '\.git$', '')"
        }
    } catch {
        # Ignore git errors
    }

    # Create template piphub.yml
    $templateContent = @"
# PipHub Configuration - Contains all setup() function arguments for setup.py
# This file is used to automatically generate setup.py and manage releases

# Required setup() arguments
name: "$defaultName"
version: "0.1.0"
author: "Your Name"
author_email: "your.email@example.com"
description: "A short description of your Python package"
url: "$defaultUrl"

# Optional setup() arguments
license: "MIT"
long_description_content_type: "text/markdown"
python_requires: ">=3.6"

# Package discovery (uncomment and modify as needed)
# py_modules: ["single_module"]  # For single-file packages
# packages will be auto-discovered with find_packages()

# Dependencies (use YAML list format)
# Examples:
#   install_requires: ["requests>=2.25.0", "pyyaml>=5.4.0"]
#   install_requires: []  # for no dependencies
install_requires: []  # Add your package dependencies here

# Keywords for PyPI (comma-separated string or YAML list)
keywords: "python, package, automation, tools"

# Classifiers for PyPI (modify as appropriate for your package)
classifiers: [
    "Development Status :: 3 - Alpha",
    "Intended Audience :: Developers",
    "License :: OSI Approved :: MIT License",
    "Operating System :: OS Independent",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.8",
    "Programming Language :: Python :: 3.9",
    "Programming Language :: Python :: 3.10",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",
    "Topic :: Software Development :: Libraries :: Python Modules",
    "Topic :: Utilities"
]

# Project URLs (update with your repository URLs)
project_urls: {
    "Bug Reports": "$defaultUrl/issues",
    "Source": "$defaultUrl",
    "Documentation": "$defaultUrl#readme"
}

# Release-specific settings (not part of setup() function)
tag_prefix: "v"
target_branch: "main"
release_notes_file: "README.md"
draft: false
prerelease: false
"@

    Set-Content -Path $CFG -Value $templateContent
    Ok "Created template $CFG"
    Info "Next steps: edit $CFG and run: piphub generate"
    exit 0
}

# Guard: require config for non-init commands
if ($Command -ne 'init' -and -not (Test-Path $CFG)) { Abort "Config $CFG not found. Run: piphub init" }

# Simple YAML reader for flat key: value pairs
function Get-Yaml {
    param([string]$Key)

    $content = Get-Content $CFG
    foreach ($line in $content) {
        # Skip comments
        if ($line -match '^\s*#') { continue }

        # Match key: value pattern
        if ($line -match "^\s*$Key\s*:\s*(.*)$") {
            $value = $matches[1].Trim()
            # Remove quotes if present
            $value = $value -replace '^["\x27]?(.+?)["\x27]?$', '$1'
            return $value
        }
    }
    return $null
}

# Read setup.py configuration from YAML
$NAME = Get-Yaml "name"
$VERSION_SETTING = Get-Yaml "version"
$AUTHOR = Get-Yaml "author"
$AUTHOR_EMAIL = Get-Yaml "author_email"
$DESCRIPTION = Get-Yaml "description"
$URL = Get-Yaml "url"

# Release-specific settings
$TAG_PREFIX = Get-Yaml "tag_prefix"
$TARGET_BRANCH = Get-Yaml "target_branch"
$RELEASE_NOTES_FILE = Get-Yaml "release_notes_file"

# Defaults
if (-not $TAG_PREFIX) { $TAG_PREFIX = "v" }
if (-not $TARGET_BRANCH) { $TARGET_BRANCH = "main" }
if (-not $NAME) { $NAME = (Get-Item .).Name }

# Extract repo from URL if not explicitly set
$REPO = $null
if ($URL) {
    if ($URL -match 'github\.com/([^/]+/[^/]+)') {
        $REPO = $matches[1]
    }
}

if (-not $REPO) {
    Abort "Unable to determine repository from url in $CFG. Please set url to your GitHub repository."
}
if (-not $NAME) {
    Abort "name not set in $CFG."
}

# Determine version
function Get-VersionFromSetup {
    if (-not (Test-Path "setup.py")) { return $null }

    $content = Get-Content "setup.py"
    foreach ($line in $content) {
        if ($line -match '^\s*version\s*=\s*"([^"]+)"') {
            return $matches[1]
        }
    }
    return $null
}

$VERSION = ""
if (-not $VERSION_SETTING -or $VERSION_SETTING -eq "auto") {
    if (-not (Test-Path "setup.py")) {
        Abort "setup.py not found to auto-detect version"
    }
    $VERSION = Get-VersionFromSetup
    if (-not $VERSION) {
        Abort "Unable to determine version from setup.py"
    }
} else {
    $VERSION = $VERSION_SETTING
}

$TAG = "$TAG_PREFIX$VERSION"

# Generate setup.py from YAML configuration
Info "Generating setup.py from $CFG"
function Generate-SetupPy {
    $setupContent = @'
from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
'@

    # Parse YAML and handle complex structures
    $content = Get-Content $CFG
    $inList = $false
    $inDict = $false
    $currentKey = ""
    $listItems = @()
    $dictItems = @()

    foreach ($line in $content) {
        # Skip comments and empty lines
        if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }

        # Skip release-specific keys that aren't setup() args
        if ($line -match '^\s*(tag_prefix|target_branch|release_notes_file|draft|prerelease)\s*:') { continue }

        # Handle list continuation (both quoted and unquoted items)
        if ($line -match '^\s*-\s*"([^"]*)"[\s,]*$' -and $inList) {
            $listItems += $matches[1]
            continue
        }
        if ($line -match '^\s*"([^"]*)"[\s,]*$' -and $inList) {
            $listItems += $matches[1]
            continue
        }

        # Handle dict continuation
        if ($line -match '^\s*"([^"]+)":\s*"([^"]+)"[\s,]*$' -and $inDict) {
            $dictItems += "`"$($matches[1])`": `"$($matches[2])`""
            continue
        }

        # End of list
        if ($line -match '^\s*\]\s*$' -and $inList) {
            if ($listItems.Count -eq 0) {
                $setupContent += "    $currentKey=[],`n"
            } else {
                $listStr = ($listItems | ForEach-Object { "`"$_`"" }) -join ', '
                $setupContent += "    $currentKey=[$listStr],`n"
            }
            $inList = $false
            $currentKey = ""
            $listItems = @()
            continue
        }

        # End of dict
        if ($line -match '^\s*\}\s*$' -and $inDict) {
            if ($dictItems.Count -eq 0) {
                $setupContent += "    $currentKey={},`n"
            } else {
                $dictStr = $dictItems -join ', '
                $setupContent += "    $currentKey={$dictStr},`n"
            }
            $inDict = $false
            $currentKey = ""
            $dictItems = @()
            continue
        }

        # Parse key: value
        if ($line -match '^\s*([^:]+):\s*(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            # Handle list start
            if ($value -match '^\[\s*$') {
                $inList = $true
                $currentKey = $key
                $listItems = @()
                continue
            }

            # Handle dict start
            if ($value -match '^\{\s*$') {
                $inDict = $true
                $currentKey = $key
                $dictItems = @()
                continue
            }

            # Remove trailing comments first (before quote removal)
            $value = $value -replace '\s*#.*$', ''

            # Remove any remaining whitespace
            $value = $value.Trim()

            # Remove outer quotes if present (but preserve inner quotes for lists)
            if ($value -notmatch '^\[.*\]$') {
                $value = $value -replace '^["\x27]?(.+?)["\x27]?$', '$1'
            }

            # Handle special formatting for different types
            switch ($key) {
                { $_ -in @("install_requires", "py_modules") } {
                    # Handle empty list or list with values
                    if ($value -eq "[]") {
                        $setupContent += "    $key=[],`n"
                    } elseif ($value -match '^\[.*\]$') {
                        $setupContent += "    $key=$value,`n"
                    } else {
                        $setupContent += "    $key=[`"$value`"],`n"
                    }
                }
                "keywords" {
                    # Handle comma-separated string as list
                    if ($value -match '^\[.*\]$') {
                        $setupContent += "    $key=$value,`n"
                    } else {
                        # Convert comma-separated string to list
                        $keywords = $value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                        $keywordList = ($keywords | ForEach-Object { "`"$_`"" }) -join ', '
                        $setupContent += "    $key=[$keywordList],`n"
                    }
                }
                { $_ -in @("python_requires", "version", "name", "author", "author_email", "description", "url", "license", "long_description_content_type") } {
                    $setupContent += "    $key=`"$value`",`n"
                }
                default {
                    # Default handling - check if it's a list format
                    if ($value -match '^\[.*\]$') {
                        $setupContent += "    $key=$value,`n"
                    } else {
                        # Default string handling
                        $setupContent += "    $key=`"$value`",`n"
                    }
                }
            }
        }
    }

    # Add standard fields
    $setupContent += "    long_description=long_description,`n"
    $setupContent += "    packages=find_packages(),`n"
    $setupContent += ")`n"

    Set-Content -Path "setup.py" -Value $setupContent
}

if ($Command -eq 'generate') {
    Info "Generating setup.py from $CFG"
    Generate-SetupPy
    Ok "Generated setup.py"
    exit 0
}

if ($Command -ne 'release') { exit 0 }

Info "Repo: $REPO"
Info "Package: $NAME"
Info "Version: $VERSION"
Info "Tag: $TAG"
Info "Target branch: $TARGET_BRANCH"

# Ensure gh is available and authenticated
try {
    $null = Get-Command gh -ErrorAction Stop
} catch {
    Abort "gh (GitHub CLI) not found in PATH. Install from: https://cli.github.com/"
}

try {
    gh auth status 2>$null | Out-Null
} catch {
    Info "gh not authenticated. Launching gh auth login..."
    gh auth login
    if ($LASTEXITCODE -ne 0) {
        Abort "gh auth login failed"
    }
}

# Make sure git trusts this working directory and we are on the correct branch and up to date
$SAFE_DIR = (Get-Location).Path
Info "Marking git safe.directory: $SAFE_DIR"
try {
    git config --global --add safe.directory "$SAFE_DIR" 2>$null
} catch {
    # Ignore errors for safe.directory
}

Info "Checking out $TARGET_BRANCH and pulling latest"
git checkout $TARGET_BRANCH
if ($LASTEXITCODE -ne 0) {
    Abort "Failed to checkout $TARGET_BRANCH"
}

git pull --ff-only
if ($LASTEXITCODE -ne 0) {
    Abort "Failed to pull latest changes"
}

# Warn and abort if there are any untracked files
$UNTRACKED = git ls-files --others --exclude-standard
if ($UNTRACKED) {
    Write-Host "[WARN] Untracked files detected (not committed to git):" -ForegroundColor Yellow
    $UNTRACKED | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    Write-Host "[WARN] These files will not be part of the release." -ForegroundColor Yellow
    Abort "Untracked files present. Commit, stash, clean, or .gitignore them before releasing."
}

# Ensure there are no tracked changes (staged or unstaged)
git diff --quiet
$diffExitCode = $LASTEXITCODE
git diff --cached --quiet
$cachedDiffExitCode = $LASTEXITCODE

if ($diffExitCode -ne 0 -or $cachedDiffExitCode -ne 0) {
    git status
    Abort "Working tree has tracked changes. Commit or stash changes before releasing."
}

# Create annotated tag if missing, then push branch and tags
$existingTag = git tag -l $TAG
if ($existingTag -contains $TAG) {
    Info "Tag $TAG already exists"
} else {
    Info "Creating tag $TAG"
    git tag -a $TAG -m "Release $TAG"
    if ($LASTEXITCODE -ne 0) {
        Abort "Failed to create tag $TAG"
    }
}

Info "Pushing $TARGET_BRANCH and tags to origin"
git push origin $TARGET_BRANCH --tags
if ($LASTEXITCODE -ne 0) {
    Abort "Failed to push to origin"
}
Ok "Pushed branch and tags to origin"

# Build Python package (sdist + wheel)
Info "Installing/Updating build tooling"
python -m pip install --upgrade build --break-system-packages 2>$null | Out-Null

Info "Building package artifacts"
if (Test-Path "dist") {
    Remove-Item -Recurse -Force "dist"
}
python -m build
if ($LASTEXITCODE -ne 0) {
    Abort "Failed to build package"
}
Ok "Built package artifacts (sdist + wheel)"

# Determine the release notes file (fallback to README.md)
$BODY_FILE = $RELEASE_NOTES_FILE
if (-not $BODY_FILE -or -not (Test-Path $BODY_FILE)) {
    $BODY_FILE = "README.md"
}

# Create release if missing, otherwise upload/replace assets
try {
    gh release view $TAG --repo $REPO 2>$null | Out-Null
    Info "Release $TAG exists. Uploading assets (clobber)..."
    $distFiles = Get-ChildItem "dist\*" | ForEach-Object { $_.FullName }
    gh release upload $TAG $distFiles --clobber --repo $REPO
} catch {
    Info "Creating release $TAG"
    $distFiles = Get-ChildItem "dist\*" | ForEach-Object { $_.FullName }
    $createArgs = @("release", "create", $TAG) + $distFiles + @("--repo", $REPO, "--title", "$NAME $VERSION", "--notes-file", $BODY_FILE)
    & gh @createArgs
    if ($LASTEXITCODE -ne 0) {
        Abort "Failed to create release"
    }
}

Ok "Release $TAG created/updated successfully."

# Update requirements.txt with the pip install command for this release
Info "Updating requirements.txt with GitHub release install command"
$GITHUB_URL = "https://github.com/$REPO.git@$TAG#egg=$NAME"

$requirementsContent = @"
# Example of installing the released package directly from the GitHub tag
# Replace $TAG with the tag created from piphub.yaml (prefix + version)
# Either install directly:
#   pip install git+$GITHUB_URL
# Or via this requirements file:
git+$GITHUB_URL
"@

Set-Content -Path "requirements.txt" -Value $requirementsContent

Info "requirements.txt updated with: git+$GITHUB_URL"
