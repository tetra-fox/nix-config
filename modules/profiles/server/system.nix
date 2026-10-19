{
  lib,
  modules,
  username,
  ...
}: {
  imports = [
    modules.profiles.base.system

    modules.platform.proxmox-vm.system
    modules.platform.disko.proxmox-vm

    # agent half only, lab.monitoring.server.enable makes the mon box also scrape
    modules.services.monitoring.system
    modules.services.logging.system

    # defaults to secrets/<hostname>.yaml, null on hosts without one
    modules.platform.sops.system
  ];

  lab.logging.enable = true;

  home-manager.users.${username}.imports = [modules.profiles.server.home];

  # every server disk shares one thin pool with little headroom, so gc and fstrim nightly
  # to hand freed blocks back the same day. see SCHEDULE.md
  programs.nh.clean = {
    dates = "*-*-* 12:00:00";
    extraArgs = "--keep-since 2d";
  };

  environment.variables.BROWSER = "echo";

  # safe only because servers are ssh-key only with no physical access
  security.sudo.wheelNeedsPassword = lib.mkDefault false;

  networking = {
    useDHCP = lib.mkDefault true;
    firewall.allowPing = lib.mkDefault true;
  };

  services = {
    qemuGuest.enable = lib.mkDefault true;
    udisks2.enable = lib.mkDefault false;
    # journals ship to loki, the local copy only has to cover an outage
    journald.settings.Journal = {
      SystemMaxUse = lib.mkDefault "200M";
      RuntimeMaxUse = lib.mkDefault "64M";
      MaxRetentionSec = lib.mkDefault "2week";
    };
    fstrim.interval = "*-*-* 12:30:00";
  };

  zramSwap.enable = lib.mkDefault true;

  i18n.supportedLocales = lib.mkDefault [
    "en_US.UTF-8/UTF-8"
    "en_GB.UTF-8/UTF-8"
    "C.UTF-8/UTF-8"
  ];

  documentation = {
    nixos.enable = lib.mkDefault false;
    doc.enable = lib.mkDefault false;
    info.enable = lib.mkDefault false;
    man.cache.enable = lib.mkDefault false;
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = lib.mkDefault 10;
    "vm.vfs_cache_pressure" = lib.mkDefault 50;
    "net.ipv4.tcp_congestion_control" = lib.mkDefault "bbr";
    "net.core.default_qdisc" = lib.mkDefault "fq";
    "net.ipv4.tcp_fastopen" = lib.mkDefault 3;
  };

  fonts = {
    packages = lib.mkDefault [];
    fontDir.enable = lib.mkDefault false;
    fontconfig.enable = lib.mkDefault false;
  };

  xdg = {
    sounds.enable = lib.mkDefault false;
    mime.enable = lib.mkDefault false;
    menus.enable = lib.mkDefault false;
    icons.enable = lib.mkDefault false;
    autostart.enable = lib.mkDefault false;
  };

  hardware.nvidia.powerManagement.enable = false;

  systemd = {
    # emergency mode waits on a console nobody watches, let the watchdog reboot instead
    enableEmergencyMode = false;

    settings.Manager = {
      RuntimeWatchdogSec = lib.mkDefault "20s";
      RebootWatchdogSec = lib.mkDefault "30s";
    };

    sleep.settings.Sleep = {
      AllowSuspend = false;
      AllowHibernation = false;
    };

    # one stuck container can fill /var/lib/systemd/coredump fast
    coredump.settings.Coredump.Storage = lib.mkDefault "none";
  };
}
