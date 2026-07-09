# ddcci

exposes DDC/CI monitor brightness as native linux backlight devices. loads
`ddcci-backlight`, which registers each DDC/CI monitor as
`/sys/class/backlight/ddcci*`, so `brightnessctl` and compositor sliders drive
external monitors like a laptop panel. on a desktop with no internal panel this
is the only way to get a `/sys/class/backlight` device at all.

```nix
{ modules, ... }: {
  imports = [modules.hardware.ddcci.system];
  lab.ddcci.forceProbe = true; # nvidia
}
```

## options

- `lab.ddcci.forceProbe` (default `false`) - bind the driver on nvidia, which
  never tells `ddcci-backlight` which bus has a monitor. leave off on intel/amd
  where the driver auto-attaches

## checking it worked

```sh
ls /sys/class/backlight/          # expect ddcci* entries, one per monitor
brightnessctl -d ddcci* set 60%
journalctl -u ddcci-attach        # per-bus bound / skipped / failed lines
```

if nothing shows up, `ddcutil detect` shows whether the monitors answer DDC/CI at
all. no answer means bad cable, DDC/CI disabled in the monitor's OSD, or a bus
the GPU doesn't expose.

## gotchas

- on nvidia the kernel logs `Auto-probing of displays is not available on kernel
  6.8 and later`, so `forceProbe` is required; the attach is driven by the drm
  `change`/`HOTPLUG=1` uevent plus one boot run
- the attach only binds a bus whose 128-byte EDID at 0x50 validates (header +
  checksum) twice in a row. it must NOT write `ddcci 0x37` to a non-monitor DP
  bus: writing to the valve index HMD's port wedges its firmware, which then
  stalls the board POST ~40s on the next warm reboot until the headset is
  power-cycled
- a failed probe leaves `N-0037` bound; a second `new_device` write to the same
  address returns EBUSY, so each attempt deletes the stub first
