#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "════════════════════════════════════════════════════════════"
echo "  🚀 im_charts: Deploying to pub.dev"
echo "════════════════════════════════════════════════════════════"

cd "$ROOT_DIR"

echo "🔍 [1/4] Running static analysis..."
flutter analyze

echo "🧪 [2/4] Running automated test suite..."
flutter test

echo "📦 [3/4] Performing dry-run validation..."
dart pub publish --dry-run

echo "🚀 [4/4] Publishing to pub.dev..."
dart pub publish
