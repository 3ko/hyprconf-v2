#!/usr/bin/env bash
set -euo pipefail

# Environment: MENU_THEME_NAME, ROFI_MENU_DIR (from theme.conf)
# Dependencies: rofi

source "$HOME/.config/hypr/scripts/theme.sh"
ensure_config_loaded || exit 1
require_commands rofi || exit 1

MENU_THEME_FILE="$ROFI_MENU_DIR/${MENU_THEME_NAME}.rasi"

if [[ ! -f "$MENU_THEME_FILE" ]]; then
    log_error "Missing menu theme: $MENU_THEME_FILE"
    exit 1
fi

rofi \
    -show drun \
    -theme "$MENU_THEME_FILE"
