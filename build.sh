#!/bin/bash
set -e

FLUTTER_VERSION="3.24.5"
FLUTTER_DIR="$HOME/flutter-$FLUTTER_VERSION"

# Cache/Install Flutter SDK on Vercel build container
if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Cloning Flutter SDK ($FLUTTER_VERSION)..."
  git clone https://github.com/flutter/flutter.git -b $FLUTTER_VERSION --depth 1 "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

# Navigate into frontend folder if running from repository root
if [ -d "frontend" ]; then
  cd frontend
fi

echo "Configuring Flutter..."
flutter config --no-analytics

echo "Resolving dependencies..."
flutter pub get

echo "Building Flutter Web application..."
if [ -n "$BACKEND_URL" ]; then
  flutter build web --release --no-wasm-dry-run --no-tree-shake-icons --dart-define=BACKEND_URL="$BACKEND_URL"
else
  flutter build web --release --no-wasm-dry-run --no-tree-shake-icons
fi
