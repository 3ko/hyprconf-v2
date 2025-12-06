#!/usr/bin/env bash
set -euo pipefail

# Environment: POWERMENU_THEME_NAME, ROFI_POWER_DIR, ROFI_BASE_DIR (from theme.conf)
# Dependencies: rofi, systemctl, hyprctl, hyprlock/swaylock, awk

source "$HOME/.config/hypr/scripts/theme.sh"
ensure_config_loaded || exit 1
require_commands rofi awk hostname || exit 1

POWERMENU_THEME_FILE="$ROFI_POWER_DIR/${POWERMENU_THEME_NAME}.rasi"
ROFI_CONFIRM_THEME="$ROFI_BASE_DIR/rofi-confirm.rasi"

if [[ ! -f "$POWERMENU_THEME_FILE" ]]; then
    log_error "Missing power menu theme: $POWERMENU_THEME_FILE"
    exit 1
fi

uptime_string="$(awk '{printf "%d hour, %d minutes\n", $1/3600, ($1%3600)/60}' /proc/uptime)"

shutdown=''
reboot=''
lock=''
suspend=''
logout=''
yes=''
no=''

rofi_cmd() {
    rofi -dmenu \
        -p "Goodbye ${USER}" \
        -mesg "Uptime: $uptime_string" \
        -theme "$POWERMENU_THEME_FILE"
}

confirm_cmd() {
    rofi -dmenu \
        -p 'Confirmation' \
        -mesg 'Are you Sure?' \
        -theme "$ROFI_CONFIRM_THEME"
}

confirm_exit() {
    echo -e "$yes\n$no" | confirm_cmd
}

run_rofi() {
    echo -e "$lock\n$suspend\n$logout\n$reboot\n$shutdown" | rofi_cmd
}

run_cmd() {
    local selected
    selected="$(confirm_exit)"
    [[ "$selected" != "$yes" ]] && exit 0

    case "$1" in
        --shutdown)
            "$HOME/.config/hypr/scripts/uptime.sh"
            "$HOME/.config/hypr/scripts/notification.sh" logout
            require_commands systemctl || exit 1
            systemctl poweroff --now
            ;;
        --reboot)
            "$HOME/.config/hypr/scripts/uptime.sh"
            "$HOME/.config/hypr/scripts/notification.sh" logout
            require_commands systemctl || exit 1
            systemctl reboot --now
            ;;
        --lock)
            if command -v hyprlock >/dev/null 2>&1; then
                hyprlock
            elif command -v swaylock >/dev/null 2>&1; then
                swaylock
            else
                log_error "No lock command found (hyprlock or swaylock)"
            fi
            ;;
        --logout)
            "$HOME/.config/hypr/scripts/uptime.sh"
            "$HOME/.config/hypr/scripts/notification.sh" logout
            require_commands hyprctl || exit 1
            hyprctl dispatch exit 0
            ;;
        --suspend)
            "$HOME/.config/hypr/scripts/uptime.sh"
            "$HOME/.config/hypr/scripts/notification.sh" logout
            require_commands systemctl || exit 1
            systemctl suspend
            ;;
    esac
}

chosen="$(run_rofi)"
case ${chosen} in
    $shutdown)
        run_cmd --shutdown
        ;;
    $reboot)
        run_cmd --reboot
        ;;
    $lock)
        run_cmd --lock
        ;;
    $suspend)
        run_cmd --suspend
        ;;
    $logout)
        run_cmd --logout
        ;;
esac
