#!/usr/bin/env bash
set -euo pipefail

# Keep PR and release builds on the same reviewed SDK revision.
readonly FLUTTER_VERSION="3.47.8"
readonly FLUTTER_REVISION="737ba8f885dc774b53b442759999a312c9461e4e"
readonly FLUTTER_DIR="$RUNNER_TEMP/flutter"

git clone --depth 1 --branch "$FLUTTER_VERSION" \
  https://github.com/flutter/flutter.git "$FLUTTER_DIR"
test "$(git -C "$FLUTTER_DIR" rev-parse HEAD)" = "$FLUTTER_REVISION"
echo "$FLUTTER_DIR/bin" >> "$GITHUB_PATH"
"$FLUTTER_DIR/bin/flutter" --version
