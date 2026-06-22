#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/.build/noise-self-tests"
OUT="$OUT_DIR/NoiseSelfTests"

mkdir -p "$OUT_DIR"
cd "$ROOT_DIR"

swiftc \
  Sources/Noise/Models/NoiseModels.swift \
  Sources/Noise/Support/NoiseFormatters.swift \
  Sources/Noise/Services/NoiseSoundLibrary.swift \
  Sources/Noise/Services/NoiseAudioPlayer.swift \
  Sources/Noise/Services/NoiseNotificationService.swift \
  Sources/Noise/Services/NoiseExportService.swift \
  Sources/Noise/Stores/NoiseStore.swift \
  Tests/NoiseSelfTests/NoiseCoreTestRunner.swift \
  -framework AppKit \
  -framework AVFoundation \
  -framework Combine \
  -framework UserNotifications \
  -o "$OUT"

"$OUT"
