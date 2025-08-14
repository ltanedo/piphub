#!/usr/bin/env bash
# piphub.bash - Create a GitHub release and upload Python package assets (WSL-native)
#
# Requirements (inside WSL):
# - git configured with access to your repo remote (origin)
# - gh (GitHub CLI) installed and authenticated: gh auth login
# - Python build tooling: python3 -m pip install --upgrade build
# - A piphub.yml file at the repo root with setup() function arguments
#
# Usage from Windows (ensures all work is done in WSL):
#   wsl bash -lc './piphub.bash'
#
set -euo pipefail

CFG="piphub.yml"

abort() { echo "Error: $*" >&2; exit 1; }
info()  { echo "[INFO] $*"; }

[ -f "$CFG" ] || abort "Config $CFG not found."

# Simple YAML reader for flat key: value pairs
get_yaml() {
  local key="$1"
  awk -v k="$key" '
    BEGIN { FS=":" }
    $0 !~ /^[ \t]*#/ && $1 ~ "^[ \t]*" k "[ \t]*$" {
      $1=""; sub(/^:[ \t]*/, ""); gsub(/^[ \t]+|[ \t]+$/, ""); print; exit
    }
  ' "$CFG" | sed -e 's/^\s*["\x27]\?//' -e 's/["\x27]\?\s*$//'
}

# Read setup.py configuration from YAML
NAME="$(get_yaml name || true)"
VERSION_SETTING="$(get_yaml version || true)"
AUTHOR="$(get_yaml author || true)"
AUTHOR_EMAIL="$(get_yaml author_email || true)"
DESCRIPTION="$(get_yaml description || true)"
URL="$(get_yaml url || true)"

# Release-specific settings
TAG_PREFIX="$(get_yaml tag_prefix || true)"
TARGET_BRANCH="$(get_yaml target_branch || true)"
RELEASE_NOTES_FILE="$(get_yaml release_notes_file || true)"
DRAFT_FLAG="$(get_yaml draft || true)"
PRERELEASE_FLAG="$(get_yaml prerelease || true)"

# Defaults
TAG_PREFIX=${TAG_PREFIX:-v}
TARGET_BRANCH=${TARGET_BRANCH:-main}
NAME=${NAME:-$(basename "$(pwd)")}
DRAFT_FLAG=${DRAFT_FLAG:-false}
PRERELEASE_FLAG=${PRERELEASE_FLAG:-false}

# Extract repo from URL if not explicitly set
if [[ -n "$URL" ]]; then
  REPO=$(echo "$URL" | sed -n 's|.*github\.com/\([^/]*/[^/]*\).*|\1|p')
fi

[ -n "$REPO" ] || abort "Unable to determine repository from url in $CFG. Please set url to your GitHub repository."
[ -n "$NAME" ] || abort "name not set in $CFG."

# Determine version
version_from_setup() {
  sed -n 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*"\([^"]\+\)".*/\1/p' setup.py | head -n1
}

VERSION=""
if [[ -z "${VERSION_SETTING:-}" || "${VERSION_SETTING}" == "auto" ]]; then
  [ -f setup.py ] || abort "setup.py not found to auto-detect version"
  VERSION="$(version_from_setup)"
  [ -n "$VERSION" ] || abort "Unable to determine version from setup.py"
else
  VERSION="$VERSION_SETTING"
fi

TAG="${TAG_PREFIX}${VERSION}"

# Generate setup.py from YAML configuration
info "Generating setup.py from $CFG"
generate_setup_py() {
  cat > setup.py << 'EOF'
from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
EOF

  # Add all YAML keys as setup() arguments
  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue

    # Skip release-specific keys that aren't setup() args
    [[ "$line" =~ ^[[:space:]]*(tag_prefix|target_branch|release_notes_file|draft|prerelease)[[:space:]]*: ]] && continue

    # Parse key: value
    if [[ "$line" =~ ^[[:space:]]*([^:]+):[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]// /}"
      value="${BASH_REMATCH[2]}"

      # Remove quotes if present
      value=$(echo "$value" | sed -e 's/^\s*["\x27]\?//' -e 's/["\x27]\?\s*$//')

      # Handle special formatting for different types
      case "$key" in
        "classifiers"|"install_requires"|"keywords")
          # Handle lists - convert YAML list to Python list
          if [[ "$value" =~ ^\[.*\]$ ]]; then
            echo "    $key=$value," >> setup.py
          else
            # Single line list, convert to Python format
            echo "    $key=[\"$value\"]," >> setup.py
          fi
          ;;
        "python_requires"|"version"|"name"|"author"|"author_email"|"description"|"url"|"license")
          echo "    $key=\"$value\"," >> setup.py
          ;;
        "long_description_content_type")
          echo "    long_description_content_type=\"$value\"," >> setup.py
          ;;
        *)
          # Default string handling
          echo "    $key=\"$value\"," >> setup.py
          ;;
      esac
    fi
  done < "$CFG"

  # Add standard fields
  echo "    long_description=long_description," >> setup.py
  echo "    packages=find_packages()," >> setup.py
  echo ")" >> setup.py
}

generate_setup_py

info "Repo: $REPO"
info "Package: $NAME"
info "Version: $VERSION"
info "Tag: $TAG"
info "Target branch: $TARGET_BRANCH"

# Ensure gh is available and authenticated
command -v gh >/dev/null 2>&1 || abort "gh (GitHub CLI) not found in PATH. Install with: sudo apt-get install gh (or see GitHub docs)."
if ! gh auth status >/dev/null 2>&1; then
  info "gh not authenticated. Launching gh auth login..."
  gh auth login || abort "gh auth login failed"
fi

# Make sure git trusts this working directory when mounted from Windows
# and we are on the correct branch and up to date
SAFE_DIR="$(pwd)"
info "Marking git safe.directory: $SAFE_DIR"
git config --global --add safe.directory "$SAFE_DIR" || true

info "Checking out $TARGET_BRANCH and pulling latest"
git checkout "$TARGET_BRANCH"
git pull --ff-only

# Warn and abort if there are any untracked files
UNTRACKED="$(git ls-files --others --exclude-standard || true)"
if [[ -n "$UNTRACKED" ]]; then
  echo "[WARN] Untracked files detected (not committed to git):"
  echo "$UNTRACKED" | sed 's/^/  - /'
  echo "[WARN] These files will not be part of the release."
  abort "Untracked files present. Commit, stash, clean, or .gitignore them before releasing."
fi

# Ensure there are no tracked changes (staged or unstaged)
if ! git diff --quiet || ! git diff --cached --quiet; then
  git status
  abort "Working tree has tracked changes. Commit or stash changes before releasing."
fi

# Create annotated tag if missing, then push branch and tags
if git tag -l "$TAG" | grep -q "^$TAG$"; then
  info "Tag $TAG already exists"
else
  info "Creating tag $TAG"
  git tag -a "$TAG" -m "Release $TAG"
fi

info "Pushing $TARGET_BRANCH and tags to origin"
git push origin "$TARGET_BRANCH" --tags

# Build Python package (sdist + wheel)
info "Installing/Updating build tooling"
python3 -m pip install --upgrade build >/dev/null --break-system-packages

info "Building package artifacts"
rm -rf dist
python3 -m build

# Determine the release notes file (fallback to README.md)
BODY_FILE="${RELEASE_NOTES_FILE:-}"
if [[ -z "$BODY_FILE" || ! -f "$BODY_FILE" ]]; then
  BODY_FILE="README.md"
fi

# Draft/prerelease flags for gh
GH_FLAGS=()
[[ "${DRAFT_FLAG,,}" == "true" ]] && GH_FLAGS+=("--draft")
[[ "${PRERELEASE_FLAG,,}" == "true" ]] && GH_FLAGS+=("--prerelease")

# Create release if missing, otherwise upload/replace assets
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  info "Release $TAG exists. Uploading assets (clobber)..."
  gh release upload "$TAG" dist/* --clobber --repo "$REPO"
else
  info "Creating release $TAG"
  gh release create "$TAG" dist/* \
    --repo "$REPO" \
    --title "$NAME $VERSION" \
    --notes-file "$BODY_FILE" \
    "${GH_FLAGS[@]}"
fi

info "Release $TAG created/updated successfully."

# Update requirements.txt with the pip install command for this release
info "Updating requirements.txt with GitHub release install command"
GITHUB_URL="https://github.com/${REPO}.git@${TAG}#egg=${NAME}"
cat > requirements.txt << EOF
# Example of installing the released package directly from the GitHub tag
# Replace ${TAG} with the tag created from piphub.yaml (prefix + version)
# Either install directly:
#   pip install git+${GITHUB_URL}
# Or via this requirements file:
git+${GITHUB_URL}
EOF

info "requirements.txt updated with: git+${GITHUB_URL}"


