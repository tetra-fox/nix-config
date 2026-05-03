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
    # most servers will be VMs
    qemuGuest.enable = lib.mkDefault true;
    # no removable media auto-mount on a headless VM.
    udisks2.enable = lib.mkDefault false;
    # cap log growth
    journald.extraConfig = lib.mkDefault ''
      SystemMaxUse=500M
      RuntimeMaxUse=64M
      MaxRetentionSec=2week
    '';
  };

  # compressed in-RAM swap; trades a little CPU for measurably more effective
  # memory. especially helpful on small VMs (mesa-svc-01).
  zramSwap.enable = lib.mkDefault true;

  # only generate the locales we actually use; full archive is ~100MB+.
  i18n.supportedLocales = lib.mkDefault [
    "en_US.UTF-8/UTF-8"
    "en_GB.UTF-8/UTF-8"
    "C.UTF-8/UTF-8"
  ];

  # keep manpages (useful over ssh) but drop the NixOS manual, package HTML
  # docs, and info pages - none of which get read on a headless box.
  documentation = {
    nixos.enable = lib.mkDefault false;
    doc.enable = lib.mkDefault false;
    info.enable = lib.mkDefault false;
    man.cache.enable = lib.mkDefault false;
  };

  boot.kernel.sysctl = {
    # servers should evict page cache last; default 60 is desktop-tuned.
    "vm.swappiness" = lib.mkDefault 10;
    # keep dentry/inode cache hotter on file-heavy boxes.
    "vm.vfs_cache_pressure" = lib.mkDefault 50;
    # bbr + fq: better throughput on any externally-reachable server.
    "net.ipv4.tcp_congestion_control" = lib.mkDefault "bbr";
    "net.core.default_qdisc" = lib.mkDefault "fq";
    # tcp fast open client+server; small latency win on repeat connections.
    "net.ipv4.tcp_fastopen" = lib.mkDefault 3;
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

    # a stuck container can fill /var/lib/systemd/coredump fast; drop them.
    coredump.extraConfig = lib.mkDefault "Storage=none";
  };
}
