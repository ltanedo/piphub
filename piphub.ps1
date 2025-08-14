# piphub.ps1 - Create a GitHub release and upload Python package assets (PowerShell)
#
# Requirements:
# - git configured with access to your repo remote (origin)
# - gh (GitHub CLI) installed and authenticated: gh auth login
# - Python build tooling: python -m pip install --upgrade build
# - A piphub.yaml file at the repo root with setup() function arguments
#
# Usage:
#   .\piphub.ps1
#
param()

$ErrorActionPreference = "Stop"

$CFG = "piphub.yaml"

function Abort {
    param([string]$Message)
    Write-Error "Error: $Message"
    exit 1
}

function Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

if (-not (Test-Path $CFG)) {
    Abort "Config $CFG not found."
}

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
$DRAFT_FLAG = Get-Yaml "draft"
$PRERELEASE_FLAG = Get-Yaml "prerelease"

# Defaults
if (-not $TAG_PREFIX) { $TAG_PREFIX = "v" }
if (-not $TARGET_BRANCH) { $TARGET_BRANCH = "main" }
if (-not $NAME) { $NAME = (Get-Item .).Name }
if (-not $DRAFT_FLAG) { $DRAFT_FLAG = "false" }
if (-not $PRERELEASE_FLAG) { $PRERELEASE_FLAG = "false" }

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

    # Read YAML and convert to setup() arguments
    $content = Get-Content $CFG
    foreach ($line in $content) {
        # Skip comments and empty lines
        if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }

        # Skip release-specific keys that aren't setup() args
        if ($line -match '^\s*(tag_prefix|target_branch|release_notes_file|draft|prerelease)\s*:') { continue }

        # Parse key: value
        if ($line -match '^\s*([^:]+):\s*(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            # Remove quotes if present
            $value = $value -replace '^["\x27]?(.+?)["\x27]?$', '$1'

            # Handle special formatting for different types
            switch ($key) {
                { $_ -in @("classifiers", "install_requires", "keywords") } {
                    # Handle lists - convert YAML list to Python list
                    if ($value -match '^\[.*\]$') {
                        $setupContent += "    $key=$value,`n"
                    } else {
                        # Single line list, convert to Python format
                        $setupContent += "    $key=[`"$value`"],`n"
                    }
                }
                { $_ -in @("python_requires", "version", "name", "author", "author_email", "description", "url", "license") } {
                    $setupContent += "    $key=`"$value`",`n"
                }
                "long_description_content_type" {
                    $setupContent += "    long_description_content_type=`"$value`",`n"
                }
                default {
                    # Default string handling
                    $setupContent += "    $key=`"$value`",`n"
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

Generate-SetupPy

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

# Determine the release notes file (fallback to README.md)
$BODY_FILE = $RELEASE_NOTES_FILE
if (-not $BODY_FILE -or -not (Test-Path $BODY_FILE)) {
    $BODY_FILE = "README.md"
}

# Draft/prerelease flags for gh
$GH_FLAGS = @()
if ($DRAFT_FLAG.ToLower() -eq "true") {
    $GH_FLAGS += "--draft"
}
if ($PRERELEASE_FLAG.ToLower() -eq "true") {
    $GH_FLAGS += "--prerelease"
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
    $createArgs = @("release", "create", $TAG) + $distFiles + @("--repo", $REPO, "--title", "$NAME $VERSION", "--notes-file", $BODY_FILE) + $GH_FLAGS
    & gh @createArgs
    if ($LASTEXITCODE -ne 0) {
        Abort "Failed to create release"
    }
}

Info "Release $TAG created/updated successfully."

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
