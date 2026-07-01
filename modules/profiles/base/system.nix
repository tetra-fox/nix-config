{
  lib,
  modules,
  pkgs,
  username,
  ...
}: {
  imports = [
    modules.platform.fstrim.system
    modules.platform.nix.system
    modules.platform.nixpkgs.system
    modules.services.sshd.system
    modules.cli.zsh.system
    modules.platform.systemd-boot.system
  ];

  users.users.${username} = {
    isNormalUser = true;
    uid = lib.mkDefault 1000;
    extraGroups = ["wheel"];
  };

  time.timeZone = lib.mkDefault "UTC";

  i18n = {
    defaultLocale = lib.mkDefault "en_US.UTF-8";
    extraLocaleSettings = lib.mkDefault {
      LC_TIME = "en_GB.UTF-8";
      LC_MEASUREMENT = "en_GB.UTF-8";
    };
  };

  console.keyMap = lib.mkDefault "us";

  # source-scoped firewall.extraInputRules are silently ignored under the iptables backend
  networking.nftables.enable = lib.mkDefault true;

  services = {
    earlyoom.enable = true;
    dbus.implementation = "broker";
  };

  # NixOS enables oomd by default; disable it so earlyoom is the only oom killer
  systemd.oomd.enable = lib.mkForce false;

  boot.tmp.cleanOnBoot = true;

  environment.systemPackages = with pkgs; [
    htop
    lsof
    mtr
    bind # dig/nslookup for dns debugging
    kitty.terminfo # so ssh-from-kitty renders right
  ];
}
