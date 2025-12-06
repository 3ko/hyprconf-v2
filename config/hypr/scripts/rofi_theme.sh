#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Environment: ROFI_THEME_DIR, ROFI_MENU_DIR, ROFI_ASSET_DIR, MENU_THEME_NAME (from theme.conf)
# Dependencies: rofi, hyprctl, jq, notify-send

source "$HOME/.config/hypr/scripts/theme.sh"
ensure_config_loaded || exit 1
require_commands rofi hyprctl jq notify-send || exit 1

ROFI_THEME_SELECTOR="$ROFI_THEME_DIR/rofi-wall-2.rasi"
ROFI_STYLE_DIR="$ROFI_MENU_DIR"
ROFI_ASSETS_DIR="${ROFI_ASSET_DIR:-$ROFI_BASE_DIR/assets}"

mkdir -p "$ROFI_ASSETS_DIR"

if [[ ! -f "$ROFI_THEME_SELECTOR" ]]; then
    log_error "Missing rofi selector theme: $ROFI_THEME_SELECTOR"
    exit 1
fi

style_files=("$ROFI_ASSETS_DIR"/*.png)
if ((${#style_files[@]} == 0)); then
    log_error "No rofi theme assets found in $ROFI_ASSETS_DIR"
    exit 1
fi

# Scale controls
rofi_scale=${rofiScale:-10}
[[ "$rofi_scale" =~ ^[0-9]+$ ]] || rofi_scale=10
hypr_border=${hypr_border:-2}
[[ "$hypr_border" =~ ^[0-9]+$ ]] || hypr_border=2

read -r mon_x_res mon_scale < <(hyprctl -j monitors | jq -r '.[] | select(.focused==true) | "\(.width) \(.scale)"')
if [[ -z "${mon_x_res:-}" || -z "${mon_scale:-}" ]]; then
    log_error "Unable to read monitor info from hyprctl"
    exit 1
fi

mon_scale=${mon_scale/./}
mon_x_res=$(( mon_x_res * 100 / mon_scale ))

elem_border=$(( hypr_border * 5 ))
icon_border=$(( elem_border - 5 ))

elm_width=$(( (20 + 12 + 16) * rofi_scale ))
max_avail=$(( mon_x_res - (4 * rofi_scale) ))
col_count=$(( max_avail / elm_width ))
(( col_count < 1 )) && col_count=1
(( col_count > 5 )) && col_count=5

r_scale="configuration {font: \"JetBrainsMono Nerd Font ${rofi_scale}\";}"
r_override="window{width:100%;} listview{columns:${col_count};} element{orientation:vertical;border-radius:${elem_border}px;} element-icon{border-radius:${icon_border}px;size:20em;} element-text{enabled:false;}"

menu_entries() {
    local style_path style_name
    for style_path in "${style_files[@]}"; do
        style_name=$(basename "$style_path")
        printf "%s\x00icon\x1f%s\n" "$style_name" "$style_path"
    done
}

selected_style=$(menu_entries | rofi -dmenu -markup-rows -theme-str "$r_override" -theme-str "$r_scale" -config "$ROFI_THEME_SELECTOR" -p "Select Rofi theme")

if [[ -z "${selected_style:-}" ]]; then
    exit 0
fi

selected_style_base="${selected_style%%.*}"
selected_style_number="${selected_style_base#style-}"
selected_theme="style-${selected_style_number}"
selected_theme_file="$ROFI_STYLE_DIR/${selected_theme}.rasi"

if [[ ! -f "$selected_theme_file" ]]; then
    log_error "Missing rofi theme file: $selected_theme_file"
    exit 1
fi

update_config_value "MENU_THEME_NAME" "$selected_theme"
notify-send -t 2000 -i "$ROFI_ASSETS_DIR/${selected_style_base}.png" "Theme applied" "$selected_theme"
