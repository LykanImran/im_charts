#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "════════════════════════════════════════════════════════════"
echo "  🚀 im_charts: Deploying Example Web to GitHub Pages"
echo "════════════════════════════════════════════════════════════"

cd "$ROOT_DIR/example"

echo "📦 [1/3] Building Flutter Web for release (base-href: /im_charts/)..."
flutter build web --release --base-href /im_charts/

echo "📝 [2/3] Ensuring .nojekyll in build directory..."
touch build/web/.nojekyll

echo "🚀 [3/3] Pushing build/web to gh-pages branch..."
cd build/web
rm -rf .git
git init
git checkout -B gh-pages
git add -A
git commit -m "Deploy example web showcase to GitHub Pages [skip ci]"
git remote add origin https://github.com/LykanImran/im_charts.git
git push -f origin gh-pages
rm -rf .git

echo "════════════════════════════════════════════════════════════"
echo "  🎉 DEPLOYMENT COMPLETE!"
echo "  🔗 Live Showcase: https://lykanimran.github.io/im_charts/"
echo "════════════════════════════════════════════════════════════"
