#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_DIR="$HOME/Library/Application Support/CodexQuotaMenu/bin"
BIN="$INSTALL_DIR/agentbar"
LEGACY_BIN="$INSTALL_DIR/codex-quota-menu"
PLIST="$HOME/Library/LaunchAgents/com.codex.quota-menu.plist"
LOG_DIR="logs"

cd "$ROOT"
swift build -c release --disable-sandbox
mkdir -p "$INSTALL_DIR"
mkdir -p "$LOG_DIR"
if [[ -x "$LEGACY_BIN" ]]; then
  pkill -TERM -f "$LEGACY_BIN" 2>/dev/null || true
  rm -f "$LEGACY_BIN"
fi
install -m 755 .build/release/agentbar "$BIN"
RESOURCE_BUNDLE="$(find -L .build/release -maxdepth 1 -type d -name '*_AgentBar.bundle' -print -quit)"
if [[ -n "$RESOURCE_BUNDLE" ]]; then
  RESOURCE_NAME="$(basename "$RESOURCE_BUNDLE")"
  rm -rf "$INSTALL_DIR/$RESOURCE_NAME"
  ditto "$RESOURCE_BUNDLE" "$INSTALL_DIR/$RESOURCE_NAME"
fi

if [[ -f "$PLIST" ]]; then
  /usr/libexec/PlistBuddy -c "Set :ProgramArguments:0 $BIN" "$PLIST" 2>/dev/null || true
fi

CODEX_PATH="$(command -v codex || true)"
if ! pgrep -f "${BIN}" >/dev/null 2>&1; then
  if [[ -n "$CODEX_PATH" ]]; then
    CODEX_QUOTA_MENU_CODEX_PATH="$CODEX_PATH" "$BIN" >"$LOG_DIR/launcher.log" 2>&1 &
  else
    "$BIN" >"$LOG_DIR/launcher.log" 2>&1 &
  fi
fi

print "Installed: $BIN"
print "Login startup is off by default; enable it from the menu-bar item."
