#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${QG_SKILL_REPO_URL:-https://github.com/qybaihe/qg-skill.git}"
TARBALL_URL="${QG_SKILL_TARBALL_URL:-https://github.com/qybaihe/qg-skill/archive/refs/heads/main.tar.gz}"
PACKAGE_NAME="${QG_SKILL_PACKAGE:-qg-skill}"
SKILL_NAME="${QG_SKILL_NAME:-qgcar-skill}"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
SKILL_DIR="$CODEX_HOME_DIR/skills/$SKILL_NAME"

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need_command node
need_command npm

node -e 'const major = Number(process.versions.node.split(".")[0]); if (major < 18) { console.error("Node.js 18+ is required."); process.exit(1); }'

install_from_source() {
  echo "Installing qg CLI from the GitHub checkout..."
  (
    cd "$repo_dir"
    npm install
    npm run build
    npm pack --pack-destination "$tmp_dir" >/dev/null
    tarball="$(find "$tmp_dir" -maxdepth 1 -type f -name "qg-skill-*.tgz" | head -n 1)"
    if [ -z "$tarball" ]; then
      echo "Failed to create qg-skill npm tarball." >&2
      exit 1
    fi
    npm install -g "$tarball"
  )
}

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

repo_dir="$tmp_dir/repo"
if command -v git >/dev/null 2>&1; then
  git clone --depth 1 "$REPO_URL" "$repo_dir"
else
  need_command curl
  need_command tar
  mkdir -p "$repo_dir"
  curl -fsSL "$TARBALL_URL" | tar -xz -C "$tmp_dir"
  extracted_dir="$(find "$tmp_dir" -maxdepth 1 -type d -name "qg-skill-*" | head -n 1)"
  if [ -z "$extracted_dir" ]; then
    echo "Failed to extract qg-skill tarball." >&2
    exit 1
  fi
  repo_dir="$extracted_dir"
fi

echo "Installing qg CLI..."
if npm view "$PACKAGE_NAME" version --registry=https://registry.npmjs.org >/dev/null 2>&1; then
  if npm install -g "$PACKAGE_NAME"; then
    echo "Installed qg CLI from npm package: $PACKAGE_NAME"
  else
    echo "npm package install failed; falling back to source install."
    install_from_source
  fi
else
  echo "npm package is not available yet; falling back to source install."
  install_from_source
fi

echo "Installing Codex skill to $SKILL_DIR..."
mkdir -p "$CODEX_HOME_DIR/skills"
rm -rf "$SKILL_DIR"
mkdir -p "$SKILL_DIR"

if command -v rsync >/dev/null 2>&1; then
  rsync -a --exclude ".git" --exclude "node_modules" "$repo_dir/" "$SKILL_DIR/"
else
  cp -R "$repo_dir/." "$SKILL_DIR/"
  rm -rf "$SKILL_DIR/.git" "$SKILL_DIR/node_modules"
fi

echo ""
echo "Installed qg CLI:"
qg --version
echo ""
echo "Installed skill: $SKILL_DIR"
echo "Try: qg list --today --available"
