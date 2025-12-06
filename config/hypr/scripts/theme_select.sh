#!/usr/bin/env bash
set -euo pipefail

# Environment: THEME_ASSETS_DIR, ROFI_THEME_DIR (from theme.conf)
# Dependencies: rofi, notify-send

source "$HOME/.config/hypr/scripts/theme.sh"
ensure_config_loaded || exit 1
require_commands rofi notify-send || exit 1

THEME_SELECTOR_CONFIG="$ROFI_THEME_DIR/rofi-theme-select.rasi"
if [[ ! -f "$THEME_SELECTOR_CONFIG" ]]; then
    log_error "Missing theme selector config: $THEME_SELECTOR_CONFIG"
    exit 1
fi

mapfile -t THEME_ASSETS < <(list_theme_assets)
if ((${#THEME_ASSETS[@]} == 0)); then
    log_error "No theme assets found in $THEME_ASSETS_DIR"
    exit 1
fi

menu_entries() {
    local asset
    for asset in "${THEME_ASSETS[@]}"; do
        local name
        name=$(asset_to_theme_name "$asset")
        if [[ "$asset" != *.gif ]]; then
            printf "%s\x00icon\x1f%s\n" "$name" "$asset"
        else
            printf "%s\n" "$name"
        fi
    done
}

selected_theme=$(menu_entries | rofi -show -dmenu -config "$THEME_SELECTOR_CONFIG")

if [[ -z "${selected_theme:-}" ]]; then
    exit 0
fi

if ! apply_theme "$selected_theme"; then
    log_error "Failed to apply theme: ${selected_theme}"
    exit 1
fi
