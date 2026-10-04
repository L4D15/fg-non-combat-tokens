#!/bin/sh
# Lua tests against stubbed Fantasy Grounds APIs (requires luajit).
set -e
cd "$(dirname "$0")/.."
for f in ext/scripts/*.lua; do luajit -e "assert(loadfile('$f'))"; done
echo "Syntax OK"
for t in tests/test_*.lua; do luajit "$t" ext/scripts/noncombat_tokens.lua; done
