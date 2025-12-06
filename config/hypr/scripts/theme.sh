#!/usr/bin/env bash
set -euo pipefail

# Shared helpers for theme, menu, and power scripts.
# Environment variables loaded from config/hypr/theme.conf:
#   DEFAULT_THEME_NAME, PREVIOUS_THEME_CACHE, CURRENT_THEME_CACHE
#   WALLPAPER_CACHE_FILE, WALLPAPER_LINK_TARGET
#   HYPR_SCRIPTS_DIR, THEME_ASSETS_DIR, THEME_CONFIG_DIR, WALLPAPER_DIR
#   ROFI_BASE_DIR, ROFI_THEME_DIR, ROFI_COLOR_DIR, ROFI_MENU_DIR, ROFI_POWER_DIR, ROFI_ASSET_DIR
#   KITTY_THEME_DIR, WAYBAR_THEME_DIR, WLOGOUT_THEME_DIR, SWAYNC_THEME_DIR
#   DUNST_CONFIG_PATH, KVANTUM_CONFIG_PATH, VSCODE_SETTINGS_PATH
#   MENU_THEME_NAME, POWERMENU_THEME_NAME
# Dependencies expected by the functions below: rofi, wlogout, swaybg/swww,
# Hyprland (hyprctl), notify-send, crudini, awk, sed, ln, pidof.

THEME_CONFIG_FILE="${THEME_CONFIG_FILE:-$HOME/.config/hypr/theme.conf}"

log_error() {
    printf '[ERROR] %s\n' "$1" >&2
}

log_info() {
    printf '[INFO] %s\n' "$1"
}

require_commands() {
    local missing=()
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if ((${#missing[@]} > 0)); then
        log_error "Missing dependencies: ${missing[*]}"
        return 1
    fi

    return 0
}

ensure_config_loaded() {
    if [[ ! -f "$THEME_CONFIG_FILE" ]]; then
        log_error "Missing configuration file: $THEME_CONFIG_FILE"
        return 1
    fi
    # shellcheck source=/dev/null
    source "$THEME_CONFIG_FILE"
    mkdir -p "${CURRENT_THEME_CACHE%/*}" "$WALLPAPER_DIR" "$THEME_ASSETS_DIR" \
        "$ROFI_BASE_DIR" "$ROFI_THEME_DIR" "$ROFI_MENU_DIR" "$ROFI_POWER_DIR" "${ROFI_ASSET_DIR:-$ROFI_BASE_DIR/assets}"
}

update_config_value() {
    local key="$1" value="$2"
    [[ -z "$key" ]] && return 1

    if grep -q "^${key}=" "$THEME_CONFIG_FILE"; then
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$THEME_CONFIG_FILE"
    else
        echo "${key}=\"${value}\"" >>"$THEME_CONFIG_FILE"
    fi
}

current_theme_name() {
    if [[ -f "$CURRENT_THEME_CACHE" ]]; then
        cat "$CURRENT_THEME_CACHE"
    else
        echo "${DEFAULT_THEME_NAME:-}"
    fi
}

previous_theme_name() {
    [[ -f "$PREVIOUS_THEME_CACHE" ]] && cat "$PREVIOUS_THEME_CACHE"
}

save_theme_name() {
    local theme_name="$1"
    [[ -f "$CURRENT_THEME_CACHE" ]] && cp "$CURRENT_THEME_CACHE" "$PREVIOUS_THEME_CACHE"
    echo "$theme_name" >"$CURRENT_THEME_CACHE"
    update_config_value "DEFAULT_THEME_NAME" "$theme_name"
}

list_theme_assets() {
    find "$THEME_ASSETS_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' \) -print | sort
}

asset_to_theme_name() {
    local asset_path="$1"
    basename "$asset_path" | sed 's/\.[^.]*$//'
}

resolve_theme_asset() {
    local theme_name="$1" asset_path
    asset_path=$(find "$THEME_ASSETS_DIR" -maxdepth 1 -type f -iname "${theme_name}.*" | head -n1)
    [[ -n "$asset_path" ]] && echo "$asset_path"
}

link_if_exists() {
    local source="$1" dest="$2" label="$3"
    if [[ -f "$source" ]]; then
        ln -sf "$source" "$dest"
    else
        log_error "Missing ${label} for theme: $source"
    fi
}

apply_dunst_colors() {
    local theme_name="$1" colors_file="$KITTY_THEME_DIR/${theme_name}.conf"
    [[ ! -f "$colors_file" ]] && return
    require_commands grep awk sed || return

    local dunst_file="$DUNST_CONFIG_PATH"
    [[ ! -f "$dunst_file" ]] && return

    local frame normal_bg normal_fg
    frame=$(grep -E '^foreground' "$colors_file" | awk '{print $NF}')
    normal_bg=$(grep -E '^background' "$colors_file" | awk '{print $NF}')
    normal_fg=$(grep -E '^foreground' "$colors_file" | awk '{print $NF}')

    sed -i "s/frame_color = .*/frame_color = \"$frame\"/g" "$dunst_file"
    sed -i "/^\[urgency_low\]/,/^\[/ s/^    background = .*/    background = \"$normal_bg\"/g" "$dunst_file"
    sed -i "/^\[urgency_low\]/,/^\[/ s/^    foreground = .*/    foreground = \"$normal_fg\"/g" "$dunst_file"
    sed -i "/^\[urgency_normal\]/,/^\[/ s/^    background = .*/    background = \"${normal_bg}80\"/g" "$dunst_file"
    sed -i "/^\[urgency_normal\]/,/^\[/ s/^    foreground = .*/    foreground = \"$normal_fg\"/g" "$dunst_file"
    sed -i "/^\[urgency_critical\]/,/^\[/ s/^    foreground = .*/    foreground = \"$normal_fg\"/g" "$dunst_file"
}

apply_theme_integrations() {
    local theme_name="$1"
    link_if_exists "$THEME_CONFIG_DIR/${theme_name}.conf" "$HOME/.config/hypr/confs/decoration.conf" "Hyprland theme"
    link_if_exists "$ROFI_COLOR_DIR/${theme_name}.rasi" "$ROFI_THEME_DIR/rofi-colors.rasi" "Rofi colors"
    link_if_exists "$KITTY_THEME_DIR/${theme_name}.conf" "$HOME/.config/kitty/theme.conf" "Kitty theme"
    link_if_exists "$WAYBAR_THEME_DIR/${theme_name}.css" "$HOME/.config/waybar/style/theme.css" "Waybar theme"
    link_if_exists "$WLOGOUT_THEME_DIR/${theme_name}.css" "$HOME/.config/wlogout/colors.css" "wlogout theme"
    link_if_exists "$SWAYNC_THEME_DIR/${theme_name}.css" "$HOME/.config/swaync/colors.css" "swaync theme"

    if command -v kitty >/dev/null 2>&1 && command -v pidof >/dev/null 2>&1; then
        pidof kitty >/dev/null 2>&1 && kill -SIGUSR1 $(pidof kitty)
    fi

    apply_dunst_colors "$theme_name"
}

apply_desktop_theme() {
    local theme_name="$1" vscodeTheme kvTheme
    case "$theme_name" in
        Catppuccin)
            vscodeTheme="Catppuccin Mocha"
            kvTheme="Catppuccin"
            ;;
        Everforest)
            vscodeTheme="Everforest Dark"
            kvTheme="Everforest"
            ;;
        Gruvbox)
            vscodeTheme="Gruvbox Dark Soft"
            kvTheme="Gruvbox"
            ;;
        Neon)
            vscodeTheme="Neon Dark Theme"
            kvTheme="Nordic-Darker"
            ;;
        TokyoNight)
            vscodeTheme="Tokyo Storm Gogh"
            kvTheme="TokyoNight"
            ;;
        *)
            log_error "Unknown desktop theme mapping for ${theme_name}"
            return 1
            ;;
    esac

    if command -v crudini >/dev/null 2>&1; then
        crudini --set "$KVANTUM_CONFIG_PATH" General theme "$kvTheme"
    else
        log_error "Missing dependency: crudini"
    fi

    if [[ -f "$VSCODE_SETTINGS_PATH" ]]; then
        sed -i "s|\"workbench.colorTheme\": \".*\"|\"workbench.colorTheme\": \"$vscodeTheme\"|" "$VSCODE_SETTINGS_PATH"
    else
        log_error "VS Code settings file not found at $VSCODE_SETTINGS_PATH"
    fi
}

apply_theme() {
    local theme_name="$1"
    ensure_config_loaded || return 1
    require_commands hyprctl wlogout rofi notify-send ln || return 1

    local asset
    asset=$(resolve_theme_asset "$theme_name")
    if [[ -z "$asset" ]]; then
        log_error "Unknown theme: ${theme_name}"
        return 1
    fi

    save_theme_name "$theme_name"
    apply_theme_integrations "$theme_name"
    apply_desktop_theme "$theme_name" || return 1

    if [[ -x "$HYPR_SCRIPTS_DIR/Wallpaper.sh" ]]; then
        "$HYPR_SCRIPTS_DIR/Wallpaper.sh" &>/dev/null || true
    fi

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -i "$asset" "Theme switched" "$theme_name" -t 1500
    fi

    if [[ -x "$HYPR_SCRIPTS_DIR/Refresh.sh" ]]; then
        "$HYPR_SCRIPTS_DIR/Refresh.sh" &>/dev/null || true
    fi
}

rollback_theme() {
    ensure_config_loaded || return 1
    local previous
    previous=$(previous_theme_name || true)
    if [[ -z "${previous:-}" ]]; then
        log_error "No previous theme to rollback to"
        return 1
    fi
    apply_theme "$previous"
}

list_theme_names() {
    local asset
    while IFS= read -r asset; do
        asset_to_theme_name "$asset"
    done < <(list_theme_assets)
}
