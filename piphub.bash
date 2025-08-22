#!/usr/bin/env bash
# piphub.bash - Create a GitHub release and upload Python package assets (WSL-native)
#
# Requirements (inside WSL):
# - git configured with access to your repo remote (origin)
# - gh (GitHub CLI) installed and authenticated: gh auth login
# - Python build tooling: python3 -m pip install --upgrade build
# - A piphub.yml file at the repo root with setup() function arguments
#
# Usage:
#   ./piphub.bash <init|generate|release|help>
#   ./piphub.bash                   # Shows help
#
set -euo pipefail

CFG="piphub.yml"
CHECK="✔"; CROSS="❌"; GREEN="\033[32m"; RED="\033[31m"; CYAN="\033[36m"; RESET="\033[0m"
abort() { echo -e "${RED}[${CROSS}] $*${RESET}" >&2; exit 1; }
info()  { echo -e "${CYAN}[•] $*${RESET}"; }
ok()    { echo -e "${GREEN}[${CHECK}] $*${RESET}"; }
error() { echo -e "${RED}[${CROSS}] $*${RESET}"; }

validate_piphub_yml() {
  local config_path="$1"
  local errors=()

  # Check if file exists
  if [[ ! -f "$config_path" ]]; then
    errors+=("Configuration file '$config_path' not found")
    printf '%s\n' "${errors[@]}"
    return 1
  fi

  # Required fields
  local required_fields=("name" "version" "author" "description" "url")

  # Check required fields
  for field in "${required_fields[@]}"; do
    local value
    value=$(get_yaml "$field" 2>/dev/null || true)
    if [[ -z "$value" ]]; then
      errors+=("Required field '$field' is missing or empty")
    fi
  done

  # Validate version format
  local version
  version=$(get_yaml "version" 2>/dev/null || true)
  if [[ -n "$version" && ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    errors+=("Field 'version' should follow semantic versioning (e.g., '1.0.0'), got '$version'")
  fi

  # Validate URL format
  local url
  url=$(get_yaml "url" 2>/dev/null || true)
  if [[ -n "$url" && ! "$url" =~ ^https?:// ]]; then
    errors+=("Field 'url' should be a valid HTTP/HTTPS URL, got '$url'")
  fi

  # Print errors if any
  if [[ ${#errors[@]} -gt 0 ]]; then
    printf '%s\n' "${errors[@]}"
    return 1
  fi

  return 0
}

validate_setup_py() {
  local setup_path="$1"
  local errors=()

  # Check if file exists
  if [[ ! -f "$setup_path" ]]; then
    errors+=("setup.py file not found at '$setup_path'")
    printf '%s\n' "${errors[@]}"
    return 1
  fi

  # Validate Python syntax
  if ! python3 -m py_compile "$setup_path" 2>/dev/null; then
    local compile_error
    compile_error=$(python3 -m py_compile "$setup_path" 2>&1 || true)
    errors+=("Python syntax error in setup.py: $compile_error")
  fi

  # Try to validate setup.py by running it with --help-commands (safe dry run)
  if ! python3 "$setup_path" --help-commands >/dev/null 2>&1; then
    local validation_error
    validation_error=$(python3 "$setup_path" --help-commands 2>&1 || true)
    # Filter out setuptools deprecation warnings (they're just warnings, not errors)
    if echo "$validation_error" | grep -v "SetuptoolsDeprecationWarning" | grep -q "error:"; then
      errors+=("setup.py validation failed: $validation_error")
    fi
  fi

  # Print errors if any
  if [[ ${#errors[@]} -gt 0 ]]; then
    printf '%s\n' "${errors[@]}"
    return 1
  fi

  return 0
}

# Parse command line arguments
CMD="${1:-}"

# Show help if no command or help requested
if [[ -z "$CMD" || "$CMD" == "help" || "$CMD" == "--help" ]]; then
  cat << 'EOF'
PipHub - Python Package Release Automation Tool

USAGE:
    ./piphub.bash <COMMAND>

COMMANDS:
    init        Create a template piphub.yml configuration file
    generate    Generate setup.py from piphub.yml (without releasing)
    release     Build and create GitHub release with auto-commit
    help        Show this help message

EXAMPLES:
    ./piphub.bash init              # Create template piphub.yml
    ./piphub.bash generate          # Generate setup.py only
    ./piphub.bash release           # Full release workflow

RELEASE WORKFLOW:
    1. Auto-commit and push any pending changes
    2. Generate setup.py from piphub.yml
    3. Create git tag (e.g., v1.0.0)
    4. Build Python package (wheel + source)
    5. Create GitHub release with assets
    6. Update and auto-commit requirements.txt

REQUIREMENTS:
    - git (configured with GitHub access)
    - gh (GitHub CLI, authenticated)
    - python3 (with build module)
    - piphub.yml configuration file (created with 'init')

For more information, see: https://github.com/ltanedo/piphub
EOF
  exit 0
fi

if [[ "$CMD" == "init" ]]; then
  info "Creating template configuration (piphub.yml)"

  # Get current directory name for default package name
  DEFAULT_NAME="$(basename "$(pwd)")"

  # Try to get git remote URL for default repository URL
  DEFAULT_URL=""
  if command -v git >/dev/null 2>&1; then
    GIT_REMOTE="$(git remote get-url origin 2>/dev/null || true)"
    if [[ -n "$GIT_REMOTE" && "$GIT_REMOTE" =~ github\.com[:/]([^/]+/[^/]+) ]]; then
      REPO_PATH="${BASH_REMATCH[1]}"
      REPO_PATH="${REPO_PATH%.git}"
      DEFAULT_URL="https://github.com/$REPO_PATH"
    fi
  fi

  # Create template piphub.yml
  cat > "$CFG" << EOF
# PipHub Configuration - Contains all setup() function arguments for setup.py
# This file is used to automatically generate setup.py and manage releases

# Required setup() arguments
name: "$DEFAULT_NAME"
version: "0.1.0"
author: "Your Name"
author_email: "your.email@example.com"
description: "A short description of your Python package"
url: "$DEFAULT_URL"

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
    "Bug Reports": "$DEFAULT_URL/issues",
    "Source": "$DEFAULT_URL",
    "Documentation": "$DEFAULT_URL#readme"
}

# Release-specific settings (not part of setup() function)
tag_prefix: "v"
target_branch: "master"
release_notes_file: "README.md"
draft: false
prerelease: false
auto_commit_requirements: true
EOF

  ok "Created template $CFG"
  info "Next steps: edit $CFG and run: piphub generate"
  exit 0
fi

# Guard: require config for non-init commands
if [[ "$CMD" != "init" && ! -f "$CFG" ]]; then abort "Config $CFG not found. Run: piphub init"; fi

# Simple YAML reader for flat key: value pairs
get_yaml() {
  local key="$1"
  awk -v k="$key" '
    $0 !~ /^[ \t]*#/ && $0 ~ "^[ \t]*" k "[ \t]*:" {
      sub("^[ \t]*" k "[ \t]*:[ \t]*", "")
      gsub(/^[ \t]+|[ \t]+$/, "")
      print
      exit
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
AUTO_COMMIT_REQUIREMENTS="$(get_yaml auto_commit_requirements || true)"

# Defaults
TAG_PREFIX=${TAG_PREFIX:-v}
TARGET_BRANCH=${TARGET_BRANCH:-master}
NAME=${NAME:-$(basename "$(pwd)")}
DRAFT_FLAG=${DRAFT_FLAG:-false}
PRERELEASE_FLAG=${PRERELEASE_FLAG:-false}
AUTO_COMMIT_REQUIREMENTS=${AUTO_COMMIT_REQUIREMENTS:-true}

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
if [[ "$CMD" == "generate" ]]; then
  info "Generating setup.py from $CFG"
fi
generate_setup_py() {
  cat > setup.py << 'EOF'
from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
EOF

  # Parse YAML and handle complex structures
  local in_list=false
  local in_dict=false
  local current_key=""
  local list_items=()
  local dict_items=()

  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue

    # Skip release-specific keys that aren't setup() args
    [[ "$line" =~ ^[[:space:]]*(tag_prefix|target_branch|release_notes_file|draft|prerelease|auto_commit_requirements)[[:space:]]*: ]] && continue

    # Handle list continuation (both quoted and unquoted items)
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*\"(.*)\"[[:space:]]*,?[[:space:]]*$ ]] && [[ "$in_list" == true ]]; then
      list_items+=("${BASH_REMATCH[1]}")
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]*\"(.*)\"[[:space:]]*,?[[:space:]]*$ ]] && [[ "$in_list" == true ]]; then
      list_items+=("${BASH_REMATCH[1]}")
      continue
    fi

    # Handle dict continuation
    if [[ "$line" =~ ^[[:space:]]*\"([^\"]+)\":[[:space:]]*\"([^\"]+)\"[[:space:]]*,?[[:space:]]*$ ]] && [[ "$in_dict" == true ]]; then
      dict_items+=("\"${BASH_REMATCH[1]}\": \"${BASH_REMATCH[2]}\"")
      continue
    fi

    # End of list
    if [[ "$line" =~ ^[[:space:]]*\][[:space:]]*$ ]] && [[ "$in_list" == true ]]; then
      # Output the complete list
      if [[ ${#list_items[@]} -eq 0 ]]; then
        echo "    $current_key=[]," >> setup.py
      else
        local list_str=""
        for item in "${list_items[@]}"; do
          if [[ -n "$list_str" ]]; then
            list_str="$list_str, \"$item\""
          else
            list_str="\"$item\""
          fi
        done
        echo "    $current_key=[$list_str]," >> setup.py
      fi
      in_list=false
      current_key=""
      list_items=()
      continue
    fi

    # End of dict
    if [[ "$line" =~ ^[[:space:]]*\}[[:space:]]*$ ]] && [[ "$in_dict" == true ]]; then
      # Output the complete dict
      if [[ ${#dict_items[@]} -eq 0 ]]; then
        echo "    $current_key={}," >> setup.py
      else
        local dict_str=$(IFS=', '; echo "${dict_items[*]}")
        echo "    $current_key={$dict_str}," >> setup.py
      fi
      in_dict=false
      current_key=""
      dict_items=()
      continue
    fi

    # Parse key: value
    if [[ "$line" =~ ^[[:space:]]*([^:]+):[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')  # Trim whitespace properly
      value="${BASH_REMATCH[2]}"

      # Handle list start
      if [[ "$value" =~ ^\[[[:space:]]*$ ]]; then
        in_list=true
        current_key="$key"
        list_items=()
        continue
      fi

      # Handle dict start
      if [[ "$value" =~ ^\{[[:space:]]*$ ]]; then
        in_dict=true
        current_key="$key"
        dict_items=()
        continue
      fi

      # Remove trailing comments first (before quote removal)
      value="${value%% #*}"
      value="${value%%#*}"

      # Remove any remaining whitespace
      value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

      # Remove outer quotes if present (but preserve inner quotes for lists)
      if [[ ! "$value" =~ ^\[.*\]$ ]]; then
        value=$(echo "$value" | sed -e 's/^\s*["\x27]\?//' -e 's/["\x27]\?\s*$//')
      fi

      # Handle special formatting for different types
      case "$key" in
        "install_requires"|"py_modules")
          # Handle empty list or list with values
          if [[ "$value" == "[]" ]]; then
            echo "    $key=[]," >> setup.py
          elif [[ "$value" =~ ^\[.*\]$ ]]; then
            echo "    $key=$value," >> setup.py
          else
            echo "    $key=[\"$value\"]," >> setup.py
          fi
          ;;
        "keywords")
          # Handle comma-separated string as list
          if [[ "$value" =~ ^\[.*\]$ ]]; then
            echo "    $key=$value," >> setup.py
          else
            # Convert comma-separated string to list
            IFS=',' read -ra KEYWORDS <<< "$value"
            local keyword_list=""
            for keyword in "${KEYWORDS[@]}"; do
              keyword=$(echo "$keyword" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
              if [[ -n "$keyword_list" ]]; then
                keyword_list="$keyword_list, \"$keyword\""
              else
                keyword_list="\"$keyword\""
              fi
            done
            echo "    $key=[$keyword_list]," >> setup.py
          fi
          ;;
        "python_requires"|"version"|"name"|"author"|"author_email"|"description"|"url"|"license"|"long_description_content_type")
          echo "    $key=\"$value\"," >> setup.py
          ;;
        *)
          # Default string handling - check if it's a list format
          if [[ "$value" =~ ^\[.*\]$ ]]; then
            echo "    $key=$value," >> setup.py
          else
            echo "    $key=\"$value\"," >> setup.py
          fi
          ;;
      esac
    fi
  done < "$CFG"

  # Add standard fields
  echo "    long_description=long_description," >> setup.py
  echo "    packages=find_packages()," >> setup.py
  echo ")" >> setup.py
}

if [[ "$CMD" == "generate" ]]; then
  info "Validating $CFG configuration"

  # Validate piphub.yml
  if ! validation_errors=$(validate_piphub_yml "$CFG"); then
    error "Validation failed for $CFG"
    while IFS= read -r err; do
      error "$err"
    done <<< "$validation_errors"
    exit 1
  fi

  ok "Configuration validation passed"
  info "Generating setup.py from $CFG"
  generate_setup_py
  ok "Generated setup.py"
  exit 0
fi

info "Validating $CFG configuration"

# Validate piphub.yml
if ! validation_errors=$(validate_piphub_yml "$CFG"); then
  error "Validation failed for $CFG"
  while IFS= read -r err; do
    error "$err"
  done <<< "$validation_errors"
  exit 1
fi

ok "Configuration validation passed"

info "Repo: $REPO"
info "Package: $NAME"
info "Version: $VERSION"
info "Tag: $TAG"
info "Target branch: $TARGET_BRANCH"

# Check for required dependencies
command -v git >/dev/null 2>&1 || abort "git not found in PATH. Install with: sudo apt-get install git"
command -v python3 >/dev/null 2>&1 || abort "python3 not found in PATH. Install with: sudo apt-get install python3"

# Check for setuptools (required for building packages)
if ! python3 -c "import setuptools" >/dev/null 2>&1; then
  info "setuptools not found. Installing setuptools..."
  python3 -m pip install setuptools --break-system-packages || abort "Failed to install setuptools. Try: pip install setuptools --break-system-packages"
fi

# Check for gh (GitHub CLI)
if ! command -v gh >/dev/null 2>&1; then
  abort "gh (GitHub CLI) not found in PATH. Install with: sudo apt-get install gh (or see GitHub docs)."
fi

# Ensure gh is authenticated
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

# Only perform release flow when 'release' subcommand
if [[ "$CMD" != "release" ]]; then exit 0; fi

# Automatically commit and push changes before release
info "Auto-commit enabled: staging all changes"

# Check if there are any changes to commit
if git diff --quiet && git diff --cached --quiet; then
  info "No changes to commit"
else
  info "Staging all changes"
  git add .

  info "Committing changes with message: 'Prepare $VERSION release'"
  git commit -m "Prepare $VERSION release"

  info "Pushing changes to origin/$TARGET_BRANCH"
  git push origin "$TARGET_BRANCH"

  ok "Changes committed and pushed successfully"
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

# Check if pip is available
if ! python3 -m pip --version >/dev/null 2>&1; then
  abort "python3-pip not found. Install with: sudo apt-get install python3-pip"
fi

python3 -m pip install --upgrade build >/dev/null --break-system-packages

# Generate and validate setup.py
info "Generating setup.py from $CFG"
generate_setup_py
ok "Generated setup.py"

info "Validating setup.py"
if ! setup_errors=$(validate_setup_py "setup.py"); then
  error "Validation failed for setup.py"
  while IFS= read -r err; do
    error "$err"
  done <<< "$setup_errors"
  exit 1
fi
ok "setup.py validation passed"

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

# Auto-commit requirements.txt if enabled
if [[ "${AUTO_COMMIT_REQUIREMENTS,,}" == "true" ]]; then
  info "Auto-committing requirements.txt changes..."
  if git add requirements.txt; then
    if git commit -m "Update requirements.txt for release $TAG"; then
      if git push origin "$TARGET_BRANCH"; then
        info "Successfully committed and pushed requirements.txt"
      else
        echo "[WARN] Failed to push requirements.txt commit" >&2
      fi
    else
      echo "[WARN] Failed to commit requirements.txt (may be no changes)" >&2
    fi
  else
    echo "[WARN] Failed to git add requirements.txt" >&2
  fi
else
  info "Auto-commit disabled. Remember to commit requirements.txt manually if needed."
fi


