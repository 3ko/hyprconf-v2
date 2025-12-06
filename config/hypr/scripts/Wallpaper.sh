#!/usr/bin/env bash
set -euo pipefail

# Environment: WALLPAPER_DIR, WALLPAPER_CACHE_FILE, WALLPAPER_LINK_TARGET (from theme.conf)
# Dependencies: swww, notify-send

source "$HOME/.config/hypr/scripts/theme.sh"
ensure_config_loaded || exit 1
require_commands swww notify-send || exit 1

THEME_NAME=$(current_theme_name)
CACHE_DIR="${CURRENT_THEME_CACHE%/*}"
WALLPAPER_THEME_DIR="$WALLPAPER_DIR/${THEME_NAME}"

[[ -d "$WALLPAPER_THEME_DIR" ]] || {
    log_error "Missing wallpaper directory: $WALLPAPER_THEME_DIR"
    exit 1
}

mapfile -t PICS < <(find "$WALLPAPER_THEME_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" \))
if ((${#PICS[@]} == 0)); then
    log_error "No wallpapers found for theme ${THEME_NAME}"
    exit 1
fi

wallpaper=${PICS[$RANDOM % ${#PICS[@]}]}

FPS=60
TYPE="random"
DURATION=1
BEZIER=".43,1.19,1,.4"
SWWW_PARAMS=("--transition-fps" "$FPS" "--transition-type" "$TYPE" "--transition-duration" "$DURATION" "--transition-bezier" "$BEZIER")

notify-send -i "$wallpaper" "Changing wallpaper" -t 1500
swww-daemon &>/dev/null || true
swww img "$wallpaper" "${SWWW_PARAMS[@]}"

ln -sf "$wallpaper" "$WALLPAPER_LINK_TARGET"
baseName="$(basename "$wallpaper")"
wallName=${baseName%.*}
echo "$wallName" >"$WALLPAPER_CACHE_FILE"

sleep 0.5
"$HYPR_SCRIPTS_DIR/wallcache.sh"
