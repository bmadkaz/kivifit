#!/bin/bash
# ==========================================================
# KiviFit — Setup & Push to GitHub
# Run this script ONCE after cloning/creating the project
# ==========================================================

set -e

echo "🏋️  KiviFit — GitHub Setup"
echo "=========================="

# 1. Initialize git
git init
git add .
git commit -m "feat: Initial KiviFit iOS app with MediaPipe pose detection

- MediaPipe PoseLandmarker Heavy (GPU/Metal)
- Frame skip + landmark smoothing
- Real-time skeleton overlay (green bones, red joints)
- Exercise form error detection (6 exercises)
- Russian TTS voice coach via Bluetooth/AirPods
- Codemagic CI/CD → unsigned IPA → Sideloadly
- SwiftUI + AVFoundation architecture"

echo ""
echo "📋 Next steps:"
echo ""
echo "1. Create a GitHub repository named 'kivifit' at:"
echo "   https://github.com/new"
echo ""
echo "2. Then run:"
echo "   git remote add origin https://github.com/YOUR_USERNAME/kivifit.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""
echo "3. Connect to Codemagic:"
echo "   https://codemagic.io → Add application → select kivifit"
echo ""
echo "4. Download MediaPipe models before first local build:"
echo "   ./download_models.sh"
