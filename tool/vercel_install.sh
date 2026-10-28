#!/usr/bin/env bash
# Vercel's build machines don't include Flutter: download it (or reuse the
# copy from the build cache), then fetch the app's packages.
set -euo pipefail

FLUTTER_CHANNEL=stable

if [ -d flutter/.git ]; then
  git -C flutter fetch --depth 1 origin "$FLUTTER_CHANNEL"
  git -C flutter reset --hard FETCH_HEAD
else
  rm -rf flutter
  git clone https://github.com/flutter/flutter.git --branch "$FLUTTER_CHANNEL" --depth 1 flutter
fi

flutter/bin/flutter --version
flutter/bin/flutter config --no-analytics --enable-web
flutter/bin/flutter pub get
