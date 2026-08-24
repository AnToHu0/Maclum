#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h:h}"
WORKFLOW="$PROJECT_ROOT/.github/workflows/release.yml"

grep -q 'tags: \["v\*"\]' "$WORKFLOW"
grep -q './scripts/build-app.sh' "$WORKFLOW"
grep -q './scripts/verify-app-bundle.sh' "$WORKFLOW"
grep -q './scripts/package-release.sh' "$WORKFLOW"
grep -q '.build/release/Maclum-macos-apple-silicon.zip' "$WORKFLOW"
grep -q '.build/release/Maclum-macos-apple-silicon.zip.sha256' "$WORKFLOW"
grep -q 'gh release create' "$WORKFLOW"

echo "PASS  release workflow"
