# CHUWI CoreBook X – Left Speaker Fix for Linux

Fixes the well-known problem on the **CHUWI CoreBook X (Intel i5-12450H, 14" 2K)** where, on Linux, only the **right speaker** sounds good and the left one is silent or weak.

Tested on **Fedora 44** (kernel 7.2.10, PipeWire 1.6.9). It should work on any distro that uses `dracut` and `systemd`.

## The problem

The laptop uses a **Realtek ALC269VC** codec (`0x10ec0269`, subsystem ID `0x1e507036`).
The BIOS marks pin `0x1b` as *"not connected"* (`0x411111f0`), so the Linux driver only sends audio to pin `0x14`, and one speaker is left without a proper signal.

The kernel already has a fix for the sister model, the **CoreBook X Pro** (`ALC269VB_FIXUP_CHUWI_COREBOOK_XPRO`). That fix sets pin `0x1b` as an internal speaker, but it isn't applied to the CoreBook X because the subsystem ID is different.

## The fix

This script tells the `snd-hda-intel` driver to treat pin `0x1b` as an internal speaker (`0x90170150`). It does this with a small HDA patch file, so:

- you don't need to rebuild the kernel or the driver
- it keeps working after kernel updates
- you can undo it completely

## Requirements

- CHUWI CoreBook X with a Realtek ALC269VC codec (the script checks this and stops if it isn't found)
- `bash`, `sudo`, `systemd`, `dracut`
- `alsa-utils` (for `amixer` and `speaker-test`)

Check your codec:

```bash
cat /sys/class/sound/hwC0D0/chip_name /sys/class/sound/hwC0D0/subsystem_id
# ALC269VC
# 0x1e507036
```

## Usage

```bash
git clone https://github.com/MarcosSilvaAv/chuwi-core-x-sound-fix.git
cd chuwi-core-x-sound-fix
./corebook-x-audio-fix.sh
```

> [!IMPORTANT]
> Run the script as your **normal user**, not with `sudo`. It asks for your password when it needs it.

| Option | Description |
|---|---|
| `1` – Install | Installs the fix permanently, then offers to reboot |
| `2` – Uninstall | Removes the fix (rolls back to the default), then offers to reboot |
| `3` – Test | Turns the fix on **temporarily** without a reboot, and plays a left/right test sound. Rebooting undoes it |

You can also skip the menu:

```bash
./corebook-x-audio-fix.sh test
./corebook-x-audio-fix.sh install
./corebook-x-audio-fix.sh uninstall
```

We recommend running **Test** first.

## What gets installed

| File | Purpose |
|---|---|
| `/usr/lib/firmware/chuwi-corebook-x-audio.fw` | HDA patch that overrides the pin setting |
| `/etc/modprobe.d/chuwi-corebook-x-audio.conf` | Loads the patch: `options snd-hda-intel patch=chuwi-corebook-x-audio.fw` |
| `/etc/dracut.conf.d/chuwi-corebook-x-audio.conf` | Adds the patch to the initramfs |

If any of these files already exist, they're copied to `./backup/<timestamp>/` before install. After the files are written, the initramfs is rebuilt with `dracut -f`.

## Logs

Every command, its output and your menu choices are added, with timestamps, to `corebook-x-audio-fix.log` in the repo folder.

## Verify after reboot

```bash
cat /sys/class/sound/hwC0D0/driver_pin_configs
# should contain: 0x1b 0x90170150
speaker-test -c 2 -t wav -l 1
```

## Troubleshooting

- **Test says "Device or resource busy"**: something still has the sound card open. The script prints which processes are using `/dev/snd/*`. Close them and try again.
- **A new "Bass Speaker" (or similar) volume control appears**: open `alsamixer` and make sure it's unmuted and turned up.
- **No improvement at all**: check whether the left speaker also sounds bad on Windows. If it does, the problem is probably the hardware.

## Upstream

The proper long-term fix is a one-line kernel quirk in `sound/hda/codecs/realtek/alc269.c`:

```c
SND_PCI_QUIRK(0x1e50, 0x7036, "CHUWI CoreBook X", ALC269VB_FIXUP_CHUWI_COREBOOK_XPRO),
```

Once this is in the mainline kernel, you won't need this script.

## License

[MIT](LICENSE)
