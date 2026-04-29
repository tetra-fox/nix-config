# server system baseline: extends base profile, strips desktop assumptions,
# tunes systemd for long-running unattended boxes.
{
  lib,
  modules,
  pkgs,
  ...
}: {
  imports = [
    modules.profiles.base.system
    modules.avahi.system
  ];

  # server-specific CLI tools (in addition to the base toolkit).
  environment = {
    systemPackages = with pkgs; [
      tmux # long-lived ssh sessions
    ];

    # browsers don't make sense on a headless box; print URLs instead.
    variables.BROWSER = "echo";
  };

  # passwordless sudo for wheel. only safe because servers are ssh-key
  # only with no physical access. workstations should keep password sudo.
  security.sudo.wheelNeedsPassword = lib.mkDefault false;

  networking = {
    # vms typically use plain dhcp on the single virtio nic. bare-metal
    # hosts that need NetworkManager/static config can override.
    useDHCP = lib.mkDefault true;
    # servers should be pingable; helps debugging from anywhere on the LAN.
    firewall.allowPing = lib.mkDefault true;
  };

  services = {
    # most servers will be VMs (proxmox in our case): graceful shutdown,
    # freeze/thaw for snapshots, ip reporting back to host. bare-metal
    # server hosts can override with services.qemuGuest.enable = false;.
    qemuGuest.enable = lib.mkDefault true;
    # no removable media auto-mount on a headless VM.
    udisks2.enable = lib.mkDefault false;
  };

  # no fonts on a server (no GUI; console doesn't honor fontconfig anyway).
  fonts = {
    packages = lib.mkDefault [];
    fontDir.enable = lib.mkDefault false;
    fontconfig.enable = lib.mkDefault false;
  };

  # no desktop integration plumbing; cuts a chunk of activation time.
  xdg = {
    sounds.enable = lib.mkDefault false;
    mime.enable = lib.mkDefault false;
    menus.enable = lib.mkDefault false;
    icons.enable = lib.mkDefault false;
    autostart.enable = lib.mkDefault false;
  };

  systemd = {
    # remote-only access pattern: emergency mode hangs the box waiting for
    # console interaction, which we'll never see. better to retry boot and
    # let watchdog/recovery handle it.
    enableEmergencyMode = false;

    # hardware watchdog: kick every 10s, force reboot if no kick for 20s,
    # force reboot if shutdown stalls for 30s. catches kernel/init hangs.
    settings.Manager = {
      RuntimeWatchdogSec = lib.mkDefault "20s";
      RebootWatchdogSec = lib.mkDefault "30s";
    };

    # servers don't sleep.
    sleep.settings.Sleep = {
      AllowSuspend = false;
      AllowHibernation = false;
    };
  };
}
