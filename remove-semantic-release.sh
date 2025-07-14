#!/usr/bin/env bash
set -euo pipefail

echo "\n🧹 Removing semantic-release from the repository..."

# Remove semantic-release related packages
echo "\n📦 Removing semantic-release packages from package.json..."
npm pkg delete scripts.release || true
npm pkg delete devDependencies.semantic-release || true
npm pkg delete devDependencies["@semantic-release/changelog"] || true
npm pkg delete devDependencies["@semantic-release/commit-analyzer"] || true
npm pkg delete devDependencies["@semantic-release/release-notes-generator"] || true
npm pkg delete devDependencies["@semantic-release/github"] || true
npm pkg delete devDependencies["@semantic-release/git"] || true

# Optionally remove Commitizen
read -p "\n❓ Do you want to remove Commitizen as well? (y/n): " remove_cz
if [[ "$remove_cz" == "y" ]]; then
  echo "🧽 Removing Commitizen..."
  npm pkg delete devDependencies.commitizen || true
  npm pkg delete devDependencies["cz-conventional-changelog"] || true
  npm pkg delete config.commitizen || true
fi

# Remove release-related config files
echo "\n🗑️ Removing configuration files..."
rm -f .releaserc .releaserc.json .releaserc.yml .releaserc.yaml release.config.js .version

# Remove GitHub Actions workflow
echo "\n🗂️ Checking for GitHub release workflow..."
if [ -f ".github/workflows/release.yaml" ]; then
  read -p "❓ Delete .github/workflows/release.yaml? (y/n): " delete_wf
  if [[ "$delete_wf" == "y" ]]; then
    rm -f .github/workflows/release.yaml
    echo "✅ Deleted release.yaml"
  fi
fi

# Remove release badge from README.md
if grep -q 'actions/workflows/release.yaml/badge.svg' README.md; then
  echo "\n🔧 Cleaning up release badge in README.md..."
  sed -i.bak '/actions\/workflows\/release.yaml\/badge.svg/d' README.md
  rm -f README.md.bak
fi

echo "\n✅ Semantic Release cleanup complete."
