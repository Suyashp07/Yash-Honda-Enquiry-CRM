#!/bin/bash
set -e

# Configure git safe directory for root/container environments
git config --global --add safe.directory '*' 2>/dev/null || true

FLUTTER_DIR="$HOME/flutter-stable"

# Cache/Install Flutter stable SDK on Vercel build container
if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Cloning Flutter stable SDK..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

echo "Configuring Flutter..."
flutter config --no-analytics
flutter precache --web

# Navigate into frontend folder if running from repository root
if [ -d "frontend" ]; then
  cd frontend
fi

echo "Resolving dependencies..."
flutter pub get

echo "Building Flutter Web application..."
if [ -n "$BACKEND_URL" ]; then
  flutter build web --release --no-tree-shake-icons --dart-define=BACKEND_URL="$BACKEND_URL"
else
  flutter build web --release --no-tree-shake-icons
fi

# Ensure output exists at both paths so Vercel can find it regardless of root setting
if [ -d "build/web" ]; then
  mkdir -p ../frontend/build/web 2>/dev/null || true
  cp -rf build/web/* ../frontend/build/web/ 2>/dev/null || true
fi

echo "Flutter web build completed successfully!"
