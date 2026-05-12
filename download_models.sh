#!/bin/bash
# Download MediaPipe pose models
# These are excluded from git due to size (29MB heavy, 4.5MB lite)

set -e

echo "📥 Downloading MediaPipe Pose Landmarker models..."
mkdir -p KiviFit/Resources

echo "  → pose_landmarker_heavy.task (~29 MB)..."
curl -L --progress-bar \
  "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_heavy/float16/latest/pose_landmarker_heavy.task" \
  -o KiviFit/Resources/pose_landmarker_heavy.task

echo "  → pose_landmarker_lite.task (~4.5 MB)..."
curl -L --progress-bar \
  "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/latest/pose_landmarker_lite.task" \
  -o KiviFit/Resources/pose_landmarker_lite.task

echo ""
echo "✅ Models ready:"
ls -lh KiviFit/Resources/
echo ""
echo "Now run: pod install && open KiviFit.xcworkspace"
