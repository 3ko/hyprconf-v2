#!/usr/bin/env bash
set -euo pipefail

# Environment: WALLPAPER_DIR, WALLPAPER_CACHE_FILE, WALLPAPER_LINK_TARGET, ROFI_THEME_DIR (from theme.conf)
# Dependencies: rofi, swww, notify-send

source "$HOME/.config/hypr/scripts/theme.sh"
ensure_config_loaded || exit 1
require_commands rofi swww notify-send || exit 1

THEME_NAME=$(current_theme_name)
CACHE_DIR="${CURRENT_THEME_CACHE%/*}"
WALLPAPER_CACHE="$WALLPAPER_CACHE_FILE"
WALLPAPER_THEME_DIR="$WALLPAPER_DIR/${THEME_NAME}"

[[ -d "$WALLPAPER_THEME_DIR" ]] || {
    log_error "Missing wallpaper directory: $WALLPAPER_THEME_DIR"
    exit 1
}

[[ ! -f "$WALLPAPER_CACHE" ]] && touch "$WALLPAPER_CACHE"

TRANSITION_FPS=60
TRANSITION_TYPE="random"
TRANSITION_DURATION=1
TRANSITION_BEZIER=".43,1.19,1,.4"
SWWW_PARAMS=("--transition-fps" "$TRANSITION_FPS" "--transition-type" "$TRANSITION_TYPE" "--transition-duration" "$TRANSITION_DURATION")

ROFI_WALL_CONFIG="$ROFI_THEME_DIR/rofi-wall.rasi"
ROFI_WALL_ALT_CONFIG="$ROFI_THEME_DIR/rofi-wall-2.rasi"

if [[ ! -f "$ROFI_WALL_CONFIG" || ! -f "$ROFI_WALL_ALT_CONFIG" ]]; then
    log_error "Missing wallpaper selector themes in $ROFI_THEME_DIR"
    exit 1
fi

mapfile -t WALLPAPERS < <(find "$WALLPAPER_THEME_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' \) | sort)
if ((${#WALLPAPERS[@]} == 0)); then
    log_error "No wallpapers found for theme ${THEME_NAME}"
    exit 1
fi

RANDOM_WALLPAPER="${WALLPAPERS[$((RANDOM % ${#WALLPAPERS[@]}))]}"
RANDOM_LABEL="${#WALLPAPERS[@]}. random"

menu() {
    local file
    for file in "${WALLPAPERS[@]}"; do
        local name
        name=$(basename "$file")
        name="${name%.*}"
        if [[ "$file" != *.gif ]]; then
            printf "%s\x00icon\x1f%s\n" "$name" "$file"
        else
            printf "%s\n" "$name"
        fi
    done
    printf "%s\n" "$RANDOM_LABEL"
}

case ${1:-thm1} in
    thm2)
        choice=$(menu | rofi -show -dmenu -config "$ROFI_WALL_ALT_CONFIG")
        ;;
    *)
        choice=$(menu | rofi -show -dmenu -config "$ROFI_WALL_CONFIG")
        ;;
esac

swww-daemon &>/dev/null || true

[[ -z "${choice:-}" ]] && exit 0

if [[ "$choice" == "$RANDOM_LABEL" ]]; then
    swww img "$RANDOM_WALLPAPER" "${SWWW_PARAMS[@]}"
    exit 0
fi

selected_path=""
for file in "${WALLPAPERS[@]}"; do
    if [[ "$(basename "$file")" == "$choice"* ]]; then
        selected_path="$file"
        break
    fi
done

if [[ -z "$selected_path" ]]; then
    log_error "Image not found."
    exit 1
fi

notify-send -i "$selected_path" "Changing wallpaper" -t 1500
swww img "$selected_path" "${SWWW_PARAMS[@]}"

ln -sf "$selected_path" "$WALLPAPER_LINK_TARGET"
wall_name="${choice%.*}"
echo "$wall_name" >"$WALLPAPER_CACHE"

sleep 0.5
"$HYPR_SCRIPTS_DIR/wallcache.sh"
"$HYPR_SCRIPTS_DIR/themes.sh" 2>/dev/null || true
