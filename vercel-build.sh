#!/bin/bash

# 1. Clone Flutter SDK (stable channel)
echo "Cloning Flutter SDK stable channel..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1

# 2. Add Flutter binary to the path
export PATH="$PATH:`pwd`/flutter/bin"

# 3. Verify Flutter installation
flutter doctor

# 3b. Resolve dependencies
echo "Resolving dependencies..."
flutter pub get

# 4. Build Flutter Web app for release
echo "Building Flutter Web app..."
flutter build web --release
