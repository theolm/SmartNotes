#!/usr/bin/env bash
set -euo pipefail

# Keep PR and release builds on the same reviewed SDK revision.
readonly FLUTTER_VERSION="3.47.6"
readonly FLUTTER_REVISION="5fc346839b5d0eef006ed8404392afb4dfae428d"
readonly FLUTTER_DIR="$RUNNER_TEMP/flutter"

git clone --depth 1 --branch "$FLUTTER_VERSION" \
  https://github.com/flutter/flutter.git "$FLUTTER_DIR"
test "$(git -C "$FLUTTER_DIR" rev-parse HEAD)" = "$FLUTTER_REVISION"
echo "$FLUTTER_DIR/bin" >> "$GITHUB_PATH"
"$FLUTTER_DIR/bin/flutter" --version
