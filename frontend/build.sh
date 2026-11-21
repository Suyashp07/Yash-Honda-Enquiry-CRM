#!/bin/bash
set -e

# If production web bundle already exists, deploy instantly!
if [ -f "frontend/build/web/main.dart.js" ] || [ -f "build/web/main.dart.js" ]; then
  echo "Found pre-built Flutter web bundle! Preparing static files for deployment..."
  mkdir -p build/web frontend/build/web 2>/dev/null || true
  if [ -d "frontend/build/web" ]; then
    cp -rf frontend/build/web/* build/web/ 2>/dev/null || true
  elif [ -d "build/web" ]; then
    cp -rf build/web/* frontend/build/web/ 2>/dev/null || true
  fi
  echo "Flutter web static assets successfully ready for Vercel edge deployment!"
  exit 0
fi

# Fallback: Compile using Flutter stable SDK with memory-safe flags
git config --global --add safe.directory '*' 2>/dev/null || true
FLUTTER_DIR="$HOME/flutter-stable"

if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Cloning Flutter stable SDK..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

echo "Configuring Flutter..."
flutter config --no-analytics
flutter precache --web

if [ -d "frontend" ]; then
  cd frontend
fi

echo "Resolving dependencies..."
flutter pub get

echo "Building Flutter Web application..."
if [ -n "$BACKEND_URL" ]; then
  flutter build web --release --no-tree-shake-icons --no-wasm-dry-run --dart-define=BACKEND_URL="$BACKEND_URL"
else
  flutter build web --release --no-tree-shake-icons --no-wasm-dry-run
fi

if [ -d "build/web" ]; then
  mkdir -p ../frontend/build/web 2>/dev/null || true
  cp -rf build/web/* ../frontend/build/web/ 2>/dev/null || true
fi

echo "Flutter web build completed successfully!"
