#!/bin/bash
set -e

# Always compile Flutter Web from source so deployments reflect the latest Dart changes
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
  flutter build web --release --no-tree-shake-icons --dart-define=BACKEND_URL="$BACKEND_URL"
else
  flutter build web --release --no-tree-shake-icons
fi

if [ -d "build/web" ]; then
  mkdir -p ../frontend/build/web 2>/dev/null || true
  cp -rf build/web/* ../frontend/build/web/ 2>/dev/null || true
fi

echo "Flutter web build completed successfully!"
