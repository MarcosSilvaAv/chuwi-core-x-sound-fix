#!/usr/bin/env bash
# =============================================================================
#  CHUWI CoreBook X - left speaker fix (Realtek ALC269VC, SSID 0x1e507036)
#
#  The BIOS leaves pin 0x1b marked as "not connected", so Linux only drives
#  pin 0x14. This enables 0x1b as an internal speaker (the same fix the
#  kernel already uses for the CoreBook X Pro: ALC269VB_FIXUP_CHUWI_COREBOOK_XPRO).
#
#  Usage:  ./corebook-x-audio-fix.sh            (interactive menu)
#          ./corebook-x-audio-fix.sh install | uninstall | test
#
#  Everything (commands + output) is appended to corebook-x-audio-fix.log
#  next to this script.
# =============================================================================
set -uo pipefail

# ----------------------------------------------------------------- settings --
PIN="0x1b"
CFG="0x90170150"
CODEC_VENDOR="0x10ec0269"
CODEC_SSID="0x1e507036"
HW="/sys/class/sound/hwC0D0"

FW_NAME="chuwi-corebook-x-audio.fw"
FW_FILE="/usr/lib/firmware/$FW_NAME"
MODPROBE_FILE="/etc/modprobe.d/chuwi-corebook-x-audio.conf"
DRACUT_FILE="/etc/dracut.conf.d/chuwi-corebook-x-audio.conf"
MANAGED_FILES=("$FW_FILE" "$MODPROBE_FILE" "$DRACUT_FILE")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/corebook-x-audio-fix.log"
BACKUP_DIR="$SCRIPT_DIR/backup"

# ------------------------------------------------------------------ logging --
# Send all stdout/stderr to the console AND the log file.
exec > >(tee -a "$LOG_FILE") 2>&1

log()  { echo "[$(date '+%F %T')] $*" >&2; }
ok()   { log "OK   $*"; }
warn() { log "WARN $*"; }
die()  { log "FAIL $*"; exit 1; }

# Run a command, logging it first and its exit code afterwards.
run() {
    log "\$ $*"
    "$@"
    local rc=$?
    [ "$rc" -ne 0 ] && log "!! exit code $rc: $*"
    return "$rc"
}

# Write CONTENT to FILE as root (logged).
sudo_write() {
    local file="$1" content="$2"
    log "\$ sudo tee $file <<EOF"
    printf '%s\n' "$content" | sed 's/^/      /' >&2
    log "EOF"
    printf '%s\n' "$content" | sudo tee "$file" >/dev/null
}

ask_yes() {  # ask_yes "question"  -> returns 0 on y/Y
    local ans
    read -r -p "$1 [y/N]: " ans
    echo "$ans" >> "$LOG_FILE"
    [[ "$ans" =~ ^[Yy]$ ]]
}

# ------------------------------------------------------------------ helpers --
check_user() {
    [ "$EUID" -ne 0 ] || die "Run this script as your normal user (not with sudo). It will ask for sudo when needed."
}

check_hardware() {
    local vendor ssid
    vendor="$(cat "$HW/vendor_id" 2>/dev/null)"
    ssid="$(cat "$HW/subsystem_id" 2>/dev/null)"
    log "Codec vendor=$vendor subsystem=$ssid (expected $CODEC_VENDOR / $CODEC_SSID)"
    if [ "$vendor" != "$CODEC_VENDOR" ] || [ "$ssid" != "$CODEC_SSID" ]; then
        die "This does not look like a CHUWI CoreBook X (ALC269VC). Aborting."
    fi
    ok "Hardware matches."
}

is_installed() { [ -f "$FW_FILE" ] && [ -f "$MODPROBE_FILE" ]; }

show_status() {
    echo
    echo "  Kernel        : $(uname -r)"
    echo "  Codec         : $(cat "$HW/chip_name" 2>/dev/null) ($(cat "$HW/subsystem_id" 2>/dev/null))"
    if is_installed; then
        echo "  Fix installed : YES"
    else
        echo "  Fix installed : no"
    fi
    if grep -qi "^$PIN $CFG" "$HW/driver_pin_configs" "$HW/user_pin_configs" 2>/dev/null; then
        echo "  Fix active now: YES (pin $PIN = $CFG)"
    else
        echo "  Fix active now: no"
    fi
    echo "  Log file      : $LOG_FILE"
    echo
}

stop_audio() {
    log "Stopping PipeWire and alsa-state (the codec must not be in use)..."
    run systemctl --user stop pipewire.socket pipewire-pulse.socket pipewire-pulse wireplumber pipewire
    run sudo systemctl stop alsa-state.service
    sleep 1
}

start_audio() {
    log "Starting audio services again..."
    run sudo systemctl start alsa-state.service
    run systemctl --user start pipewire.socket pipewire-pulse.socket pipewire wireplumber pipewire-pulse
}

offer_reboot() {
    if ask_yes "A reboot is required to apply the change. Reboot now?"; then
        run sudo systemctl reboot
    else
        log "Remember to reboot later."
    fi
}

# ------------------------------------------------------------------ actions --
do_test() {
    log "===== TEST (live, not persistent - a reboot reverts it) ====="
    check_hardware
    run sudo -v || die "sudo authentication failed."

    stop_audio
    log "Applying pin override: $PIN -> $CFG"
    sudo_write "$HW/user_pin_configs" "$PIN $CFG"
    if ! echo 1 | run sudo tee "$HW/reconfig" >/dev/null; then
        warn "Codec still busy. Processes holding /dev/snd:"
        run sudo fuser -v /dev/snd/*
        start_audio
        die "Test could not be applied."
    fi
    start_audio
    sleep 3

    log "Active pin overrides:"
    run cat "$HW/user_pin_configs"
    log "Mixer controls:"
    amixer -c0 scontents | grep -E "^Simple|Playback" | grep -v -E "IEC958|Mic" >&2
    log "Playing 'Front Left' / 'Front Right' voice test twice..."
    run speaker-test -c 2 -t wav -l 2
    ok "Test finished. If both speakers sounded good, choose 'Install'."
}

do_install() {
    log "===== INSTALL ====="
    check_hardware
    run sudo -v || die "sudo authentication failed."

    # Back up any pre-existing files with the same names.
    local stamp f
    stamp="$(date '+%Y%m%d-%H%M%S')"
    for f in "${MANAGED_FILES[@]}"; do
        if [ -e "$f" ]; then
            run mkdir -p "$BACKUP_DIR/$stamp"
            run sudo cp -a "$f" "$BACKUP_DIR/$stamp/" && run sudo chown "$USER": "$BACKUP_DIR/$stamp/$(basename "$f")"
            log "Backed up $f -> $BACKUP_DIR/$stamp/"
        fi
    done

    sudo_write "$FW_FILE" "[codec]
$CODEC_VENDOR $CODEC_SSID 0

[pincfg]
$PIN $CFG" || die "Could not write $FW_FILE"

    sudo_write "$MODPROBE_FILE" "# CHUWI CoreBook X left speaker fix (corebook-x-audio-fix.sh)
options snd-hda-intel patch=$FW_NAME" || die "Could not write $MODPROBE_FILE"

    sudo_write "$DRACUT_FILE" "# CHUWI CoreBook X left speaker fix (corebook-x-audio-fix.sh)
install_items+=\" $FW_FILE \"" || die "Could not write $DRACUT_FILE"

    run sudo restorecon -v "${MANAGED_FILES[@]}" || warn "restorecon failed (SELinux labels)."

    log "Rebuilding initramfs (this can take a minute)..."
    run sudo dracut -f || die "dracut failed. Run the uninstall option to roll back."

    ok "Fix installed."
    offer_reboot
}

do_uninstall() {
    log "===== UNINSTALL ====="
    run sudo -v || die "sudo authentication failed."

    if ! is_installed && [ ! -e "$DRACUT_FILE" ]; then
        warn "The fix does not appear to be installed. Nothing to remove."
        return 0
    fi

    local f
    for f in "${MANAGED_FILES[@]}"; do
        if [ -e "$f" ]; then
            run sudo rm -f "$f"
        fi
    done

    log "Rebuilding initramfs (this can take a minute)..."
    run sudo dracut -f || die "dracut failed."

    ok "Fix removed. Audio will return to the default configuration after reboot."
    offer_reboot
}

# --------------------------------------------------------------------- main --
main() {
    log "################ corebook-x-audio-fix.sh started (user=$USER) ################"
    check_user

    local choice="${1:-}"
    if [ -z "$choice" ]; then
        echo "=============================================="
        echo "  CHUWI CoreBook X - left speaker fix"
        echo "=============================================="
        show_status
        echo "  1) Install fix"
        echo "  2) Uninstall fix (roll back)"
        echo "  3) Test fix before installing (temporary)"
        echo "  0) Exit"
        echo
        read -r -p "Choose an option [0-3]: " choice
        echo "Selected: $choice" >> "$LOG_FILE"
    fi

    case "$choice" in
        1|install)   do_install ;;
        2|uninstall) do_uninstall ;;
        3|test)      do_test ;;
        0|exit|"")   log "Exit." ;;
        *)           die "Invalid option: $choice" ;;
    esac
    log "################ finished ################"
}

main "$@"
