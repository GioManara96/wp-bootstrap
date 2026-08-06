#!/usr/bin/env bash
# Test runner — runs every tests/test_*.sh, exits 1 if any fails.
set -u
cd "$(dirname "$0")/.."
failed=0
for test_file in tests/test_*.sh; do
  echo "===== $test_file ====="
  bash "$test_file"
  if [[ $? -ne 0 ]]; then
    failed=1
  fi
done
if [[ $failed -ne 0 ]]; then
  echo "===== SOME TESTS FAILED ====="
  exit 1
fi
echo "===== ALL TESTS PASSED ====="
