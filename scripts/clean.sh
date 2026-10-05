#!/usr/bin/env bash
# ==============================================================================
# Cleanup script for build artifacts
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Cleaning build and binary artifacts in ${PROJECT_ROOT}..."
rm -rf "${PROJECT_ROOT}/build"
rm -rf "${PROJECT_ROOT}/bin"

echo "Clean completed."
