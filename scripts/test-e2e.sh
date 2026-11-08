#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "🔨 Ensuring Zest.app is built and packaged..."
./package-app.sh > /dev/null

echo "🧪 Running End-to-End (E2E) Test Suite..."
swift "$DIR/scripts/run_e2e_tests.swift"
