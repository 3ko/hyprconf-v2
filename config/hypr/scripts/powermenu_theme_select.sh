#!/usr/bin/env bash
set -euo pipefail

# Environment: ROFI_THEME_DIR, POWERMENU_THEME_NAME (from theme.conf)
# Dependencies: rofi, notify-send

source "$HOME/.config/hypr/scripts/theme.sh"
ensure_config_loaded || exit 1
require_commands rofi notify-send || exit 1

power_theme_config="$ROFI_THEME_DIR/rofi-powertheme.rasi"

if [[ ! -f "$power_theme_config" ]]; then
    log_error "Missing power theme config: $power_theme_config"
    exit 1
fi

prompt() {
    printf "fullscreen\n"
    printf "small\n"
}

selected_style=$(prompt | rofi -i -dmenu -config "$power_theme_config")

if [[ -n "${selected_style:-}" ]]; then
    update_config_value "POWERMENU_THEME_NAME" "${selected_style%.rasi}"
    notify-send -t 3000 "Power menu" "Theme applied: ${selected_style}"
fi
