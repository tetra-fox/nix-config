{
  lib,
  modules,
  pkgs,
  username,
  ...
}: {
  imports = [
    modules.profiles.base.system

    modules.services.monitoring.system

    modules.toolsets.disk.system
    modules.toolsets.hardware.system
    modules.toolsets.net.system
    modules.toolsets.observe.system

    modules.desktop.ableton-live.system
    modules.desktop.avahi.system
    modules.hardware.bluetooth.system
    modules.hardware.smartctl.system
    modules.services.podman.system
    modules.desktop.obs-studio.system
    modules.desktop.onepassword.system
    modules.hardware.pipewire.system
    modules.hardware.pipewire-rnnoise.system
    modules.desktop.udiskie.system
    modules.cli.nix-index.system
    modules.cli.yazi.system
  ];

  # loopback grafana at http://localhost:3000 as a resource monitor
  lab.monitoring.local.enable = lib.mkDefault true;

  users.users.${username} = {
    isNormalUser = true;
    # video: backlight brightness nodes. dialout: usb serial for flashing microcontrollers,
    # uaccess doesn't tag tty devices
    extraGroups = ["networkmanager" "wheel" "video" "dialout"];
  };

  time.timeZone = "America/Los_Angeles";

  networking.networkmanager = {
    enable = true;
    # per-link dns, so a vpn's resolver only answers for the vpn
    dns = "systemd-resolved";
    # nixpkgs ships connectivity checking off, so applets report false "limited connectivity"
    settings.connectivity = {
      uri = "http://fedoraproject.org/static/hotspot.txt";
      response = "OK";
      interval = 300;
    };
  };

  services = {
    printing.enable = true;
    fwupd.enable = true;
  };

  programs = {
    dconf.enable = true;
    # prebuilt FHS binaries (vscode extensions, steam tools) want /lib64/ld-linux
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
