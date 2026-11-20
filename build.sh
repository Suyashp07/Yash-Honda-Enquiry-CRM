#!/bin/bash
set -e

# Cache/Install Flutter SDK on Vercel build container
if [ ! -d "$HOME/flutter" ]; then
  echo "Cloning Flutter stable SDK..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 $HOME/flutter
fi

export PATH="$HOME/flutter/bin:$PATH"

# Navigate into frontend folder if running from repository root
if [ -d "frontend" ]; then
  cd frontend
fi

echo "Configuring Flutter..."
flutter config --no-analytics

echo "Building Flutter Web application..."
if [ -n "$BACKEND_URL" ]; then
  flutter build web --release --dart-define=BACKEND_URL="$BACKEND_URL"
else
  flutter build web --release
fi
