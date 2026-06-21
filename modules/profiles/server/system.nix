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

  lab.avahi.publish = true;

  environment = {
    systemPackages = with pkgs; [tmux];
    variables.BROWSER = "echo";
  };

  # safe only because servers are ssh-key only with no physical access
  security.sudo.wheelNeedsPassword = lib.mkDefault false;

  networking = {
    useDHCP = lib.mkDefault true;
    firewall.allowPing = lib.mkDefault true;
  };

  services = {
    qemuGuest.enable = lib.mkDefault true;
    udisks2.enable = lib.mkDefault false;
    journald.extraConfig = lib.mkDefault ''
      SystemMaxUse=500M
      RuntimeMaxUse=64M
      MaxRetentionSec=2week
    '';
    vscode-server = {
      enable = lib.mkDefault true;
      # vscodium uses jeanp413/open-remote-ssh
      installPath = lib.mkDefault [
        "$HOME/.vscode-server"
        "$HOME/.vscodium-server"
      ];
    };
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

  # pointless on a box that never sleeps; only takes effect when modules.nvidia.system is imported
  hardware.nvidia.powerManagement.enable = false;

  systemd = {
    # emergency mode hangs waiting for console input we'll never see; let the watchdog reboot instead
    enableEmergencyMode = false;

    # kick every 10s, reboot if no kick for 20s, reboot if shutdown stalls for 30s
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
