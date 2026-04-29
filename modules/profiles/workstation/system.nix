# workstation system base
{
  modules,
  pkgs,
  username,
  ...
}: {
  imports = [
    modules.profiles.base.system

    modules.bluetooth.system
    modules.docker.system
    modules.obs-studio.system
    modules.onepassword.system
    modules.pipewire.system
    modules.pipewire-rnnoise.system
    modules.wireshark.system
    modules.yazi.system
  ];

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = ["networkmanager" "wheel"];
  };

  time.timeZone = "America/Los_Angeles";

  networking.networkmanager.enable = true;

  services = {
    printing.enable = true;
    dbus.implementation = "broker";
  };

  programs = {
    dconf.enable = true;
    command-not-found.enable = true;
    # FHS-expecting binaries (vscode extensions, some electron apps,
    # precompiled steam tools) need glibc visible at /lib64/ld-linux.
    nix-ld = {
      enable = true;
      libraries = [pkgs.glibc];
    };
  };

  environment.systemPackages = with pkgs; [
    rclone
    usbutils # lsusb
    (writeShellScriptBin "rebuild" (builtins.readFile ./rebuild.sh))
  ];
}
