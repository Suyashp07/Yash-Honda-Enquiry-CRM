#!/bin/bash
set -e

# Cache/Install Flutter SDK on Vercel build container (pinned to stable 3.24.5)
if [ ! -d "$HOME/flutter" ]; then
  echo "Cloning Flutter SDK (3.24.5)..."
  git clone https://github.com/flutter/flutter.git -b 3.24.5 --depth 1 $HOME/flutter
fi

export PATH="$HOME/flutter/bin:$PATH"

# Navigate into frontend folder if running from repository root
if [ -d "frontend" ]; then
  cd frontend
fi

echo "Configuring Flutter..."
flutter config --no-analytics

echo "Getting dependencies..."
flutter pub get

echo "Building Flutter Web application..."
if [ -n "$BACKEND_URL" ]; then
  flutter build web --release --no-wasm-dry-run --no-tree-shake-icons --dart-define=BACKEND_URL="$BACKEND_URL"
else
  flutter build web --release --no-wasm-dry-run --no-tree-shake-icons
fi
