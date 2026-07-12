{
  modules,
  pkgs,
  username,
  ...
}: {
  imports = [
    modules.profiles.base.system

    modules.toolsets.archive.system
    modules.toolsets.disk.system
    modules.toolsets.general.system
    modules.toolsets.net.system

    modules.desktop.avahi.system
    modules.hardware.bluetooth.system
    modules.services.podman.system
    modules.desktop.obs-studio.system
    modules.desktop.onepassword.system
    modules.hardware.pipewire.system
    modules.hardware.pipewire-rnnoise.system
    modules.desktop.udiskie.system
    modules.desktop.walker.system
    modules.cli.yazi.system
  ];

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
    usbutils # lsusb
    (writeShellScriptBin "rebuild" (builtins.readFile ./rebuild.sh))

    git
  ];
}
