#!/bin/bash

# Dayflow Security-Fixed Build Script
# This script builds the security-hardened version of Dayflow

set -e  # Exit on any error

echo "🔒 Building Security-Fixed Dayflow..."
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: Full Xcode is required (not just Command Line Tools)"
    echo "   Please install Xcode from the Mac App Store"
    echo "   Then run: sudo xcode-select --switch /Applications/Xcode.app"
    exit 1
fi

# Ensure we're in the right directory
cd "$(dirname "$0")"

# Clean previous build
echo "🧹 Cleaning previous build..."
xcodebuild -project Dayflow/Dayflow.xcodeproj \
           -scheme Dayflow \
           -configuration Release \
           clean \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO

echo ""
echo "🔨 Building Release version..."
xcodebuild -project Dayflow/Dayflow.xcodeproj \
           -scheme Dayflow \
           -configuration Release \
           -derivedDataPath ./build \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "📦 The app is located at:"
    echo "   ./build/Build/Products/Release/Dayflow.app"
    echo ""
    echo "To install to Applications folder:"
    echo "   cp -r ./build/Build/Products/Release/Dayflow.app /Applications/"
    echo ""
    echo "Or run directly:"
    echo "   open ./build/Build/Products/Release/Dayflow.app"
    echo ""
    echo "⚠️  Note: First launch may show a Gatekeeper warning."
    echo "   Right-click the app and select 'Open' to bypass."
else
    echo ""
    echo "❌ Build failed!"
    echo "Please open Xcode and check for compilation errors:"
    echo "   open Dayflow/Dayflow.xcodeproj"
    exit 1
fi
