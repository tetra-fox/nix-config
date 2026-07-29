{
  lib,
  modules,
  pkgs,
  username,
  ...
}: {
  imports = [
    modules.profiles.base.system
    modules.cli.rebuild.system

    # the monitoring agent (node + systemd exporters) plus local mode below: a
    # loopback grafana as the machine's resource monitor
    modules.services.monitoring.system

    modules.toolsets.disk.system
    modules.toolsets.hardware.system
    modules.toolsets.net.system
    modules.toolsets.observe.system

    modules.desktop.avahi.system
    modules.hardware.bluetooth.system
    # smart metrics for the machine's physical drives, shown by the resource monitor
    modules.hardware.smartctl.system
    modules.services.podman.system
    modules.desktop.obs-studio.system
    modules.desktop.onepassword.system
    modules.hardware.pipewire.system
    modules.hardware.pipewire-rnnoise.system
    modules.desktop.udiskie.system
    modules.cli.yazi.system
  ];

  # the resource monitor at http://localhost:3000
  lab.monitoring.local.enable = lib.mkDefault true;

  users.users.${username} = {
    isNormalUser = true;
    # video: write access to backlight brightness nodes (brightnessctl)
    extraGroups = ["networkmanager" "wheel" "video"];
  };

  time.timeZone = "America/Los_Angeles";

  networking.networkmanager.enable = true;

  services = {
    printing.enable = true;
    fwupd.enable = true;
  };

  programs = {
    dconf.enable = true;
    command-not-found.enable = true;
    # FHS binaries (vscode extensions, some electron apps, precompiled steam tools) want glibc at /lib64/ld-linux
    nix-ld = {
      enable = true;
      libraries = [pkgs.glibc];
    };
  };

  environment.systemPackages = with pkgs; [
    rclone

    git
  ];
}
